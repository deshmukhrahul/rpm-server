defmodule RPMServer.Browser do
  import Plug.Conn

  def serve(conn, ["diff", folder, snapshot]) do
    diff_path = Path.join(["repo/tags", folder, snapshot, "diff.json"])

    if File.exists?(diff_path) do
      case File.read(diff_path) do
        {:ok, content} ->
          send_resp(conn, 200, render_diff_html(folder, snapshot, content))

        _ ->
          send_resp(conn, 500, "Could not read diff file")
      end
    else
      send_resp(conn, 404, "Diff not found")
    end
  end

  def serve(conn, path) do
    base = "repo/tags"
    full_path = Path.join(base, Enum.join(path, "/"))

    cond do
      File.regular?(full_path) ->
        Plug.Conn.send_file(conn, 200, full_path)

      File.dir?(full_path) ->
        send_resp(conn, 200, render_html(path, full_path))

      true ->
        send_resp(conn, 404, "Not Found")
    end
  end

  defp render_html(segments, full_path) do
    breadcrumb =
      Enum.with_index(segments)
      |> Enum.map(fn {seg, idx} ->
        url = Enum.slice(segments, 0..idx) |> Enum.join("/") |> then(&"/repo/tags/#{&1}/")

        if idx == length(segments) - 1,
          do: "<span>#{seg}</span>",
          else: ~s(<a href="#{url}">#{seg}</a>)
      end)
      |> Enum.join(" / ")

    rows =
      File.ls!(full_path)
      |> Enum.sort()
      |> Enum.map(&html_entry(full_path, &1, segments))
      |> Enum.join("\n")

    path_display =
      case segments do
        [] -> "/repo/tags/"
        _ -> "/repo/tags" <> format_path(segments) <> "/"
      end

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Repo Browser</title>
      <link rel="stylesheet" href="/assets/style.css">
    </head>
    <body>
      <div class="theme-toggle">
        <label>Dark Mode</label>
        <label class="theme-switch">
          <input type="checkbox" id="theme-toggle" onchange="toggleDark()">
          <span class="slider"></span>
        </label>
      </div>
      <h1>Browsing: #{path_display}</h1>
      <div class="breadcrumbs">📂 <a href="/repo/tags/">tags</a> / #{breadcrumb}</div>
      <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Size</th>
            <th>Modified</th>
            <th>RPMs</th>
            <th>Diff</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td class="folder"><a href="../">../</a></td>
            <td>-</td><td>-</td><td>-</td><td>-</td>
          </tr>
          #{rows}
        </tbody>
      </table>
      <script>
        function toggleDark() {
          document.body.classList.toggle("dark");
          localStorage.setItem("dark", document.body.classList.contains("dark"));
        }
        if (localStorage.getItem("dark") === "true") {
          document.body.classList.add("dark");
          document.getElementById("theme-toggle").checked = true;
        }
      </script>
    </body>
    </html>
    """
  end

  defp html_entry(dir, name, segments) do
    path = Path.join(dir, name)
    class = if File.dir?(path), do: "folder", else: "file"
    href = if File.dir?(path), do: "#{name}/", else: name

    {size, mtime} =
      case File.stat(path) do
        {:ok, stat} ->
          mb = Float.round(stat.size / 1024, 1)
          {:ok, ndt} = NaiveDateTime.from_erl(stat.mtime)
          {"#{mb} KB", NaiveDateTime.to_string(ndt) <> " UTC"}

        _ ->
          {"-", "-"}
      end

    rpm_count =
      cond do
        not File.dir?(path) ->
          "-"

        true ->
          case File.ls(path) do
            {:ok, list} ->
              list
              |> Enum.map(&Path.join(path, &1))
              |> Enum.filter(fn f ->
                case File.stat(f) do
                  {:ok, _} -> String.ends_with?(f, ".rpm")
                  _ -> false
                end
              end)
              |> Enum.count()
              |> Integer.to_string()

            _ ->
              "-"
          end
      end

    # 🔧 Fix: Look inside the *snapshot folder* for diff.json
    full_folder = Enum.join(segments, "/")
    snapshot_path = Path.join(["repo/tags", full_folder, name])
    diff_file = Path.join(snapshot_path, "diff.json")

    diff_link =
      if File.exists?(diff_file) do
        ~s(<a href="/repo/tags/diff/#{full_folder}/#{name}">View</a>)
      else
        "-"
      end

    ~s(<tr><td class="name #{class}"><a href="#{href}">#{name}</a></td><td>#{size}</td><td>#{mtime}</td><td>#{rpm_count}</td><td class="diff">#{diff_link}</td></tr>)
  end

  defp render_diff_html(folder, snapshot, content) do
    parsed =
      case Jason.decode(content) do
        {:ok, map} -> map
        _ -> %{}
      end

    added = Map.get(parsed, "added", []) |> Enum.sort()
    removed = Map.get(parsed, "removed", []) |> Enum.sort()
    from = Map.get(parsed, "from", "(unknown)")
    to = Map.get(parsed, "to", snapshot)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Diff Viewer</title>
      <link rel="stylesheet" href="/assets/style.css">
    </head>
    <body>
      <h1>Diff: #{from} → #{to}</h1>
      <p>Folder: <code>repo/tags/#{folder}/#{to}</code></p>
      <h2>Added RPMs</h2>
      <ul>
        #{Enum.map(added, &"<li>#{&1}</li>") |> Enum.join("\n")}
      </ul>
      <h2>Removed RPMs</h2>
      <ul>
        #{Enum.map(removed, &"<li>#{&1}</li>") |> Enum.join("\n")}
      </ul>
    </body>
    </html>
    """
  end

  defp format_path([]), do: ""
  defp format_path(segs), do: "/" <> Enum.join(segs, "/")
end
