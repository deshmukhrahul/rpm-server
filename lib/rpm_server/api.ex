defmodule RPMServer.API do
  alias RPMServer.Helpers
  require Logger

  @tags_base "repo/tags"

  def list_tags(conn, folder) do
    path = Path.join(@tags_base, folder)

    tags =
      case File.ls(path) do
        {:ok, list} -> Enum.filter(list, &File.dir?(Path.join(path, &1)))
        _ -> []
      end

    Helpers.json(conn, 200, %{tags: tags})
  end

  def list_packages(conn, folder, tag) do
    path = Path.join([@tags_base, folder, tag])

    pkgs =
      case File.ls(path) do
        {:ok, list} -> Enum.filter(list, &String.ends_with?(&1, ".rpm"))
        _ -> []
      end

    Helpers.json(conn, 200, %{packages: pkgs})
  end

  def create_tag(conn) do
    conn = Plug.Conn.fetch_query_params(conn)

    case conn.query_params do
      %{"folder" => folder, "type" => type} when type in ["monthly", "half-monthly"] ->
        today = Date.utc_today() |> Date.to_string()

        paths =
          try do
            RPMServer.Config.get_paths!(folder)
          rescue
            e in RuntimeError ->
              return_error(conn, 500, e.message)
          end

        if is_nil(paths) or paths == [] do
          return_error(conn, 500, "No valid paths found for repo '#{folder}'")
        else
          live_dir = Path.join([@tags_base, folder, type])
          backup_base = Path.join([@tags_base, folder, "#{type}_#{today}"])
          backup_dir = next_available_backup(backup_base)

          {prev_tag_name, prev_rpms} =
            if File.exists?(live_dir) do
              File.rename!(live_dir, backup_dir)
              {Path.basename(backup_dir), list_rpm_names(backup_dir)}
            else
              {"(none)", []}
            end

          File.mkdir_p!(live_dir)

          rpm_files =
            paths
            |> Enum.flat_map(fn dir ->
              case File.ls(dir) do
                {:ok, list} ->
                  Enum.filter(list, &String.ends_with?(&1, ".rpm"))
                  |> Enum.map(&{Path.join(dir, &1), &1})

                _ -> []
              end
            end)

          for {src, name} <- rpm_files do
            dst = Path.join(live_dir, name)
            rel = Path.relative_to(src, live_dir)
            File.rm_rf(dst)
            File.ln_s!(rel, dst)
          end

          {_, code} = System.cmd("createrepo_c", ["."], cd: live_dir)
          Logger.info("createrepo_c exited with #{code}")

          diff_info =
            if File.exists?(backup_dir) do
              diff_path = Path.join(backup_dir, "diff.json")

              new_rpms = Enum.map(rpm_files, fn {_, name} -> name end)
              removed = prev_rpms -- new_rpms
              added = new_rpms -- prev_rpms

              if added != [] or removed != [] do
                diff = %{
                  "from" => prev_tag_name,
                  "to" => Path.basename(live_dir),
                  "added" => Enum.sort(added),
                  "removed" => Enum.sort(removed),
                  "count" => length(added) + length(removed),
                  "timestamp" => DateTime.utc_now() |> DateTime.to_string()
                }

                File.write!(diff_path, Jason.encode_to_iodata!(diff, pretty: true))
                diff
              else
                nil
              end
            else
              nil
            end

          Helpers.json(conn, 200, %{
            folder: folder,
            tag: type,
            date: today,
            file_count: length(rpm_files),
            diff_count: diff_info && diff_info["count"] || 0,
            backup_created: File.exists?(backup_dir)
          })
        end

      _ ->
        Helpers.json(conn, 400, %{error: "Invalid folder or tag type"})
    end
  end

  defp return_error(conn, code, message) do
    Helpers.json(conn, code, %{error: message})
    nil
  end

  defp next_available_backup(base, count \\ 0) do
    candidate =
      case count do
        0 -> base
        _ -> "#{base}_#{count}"
      end

    if File.exists?(candidate) do
      next_available_backup(base, count + 1)
    else
      candidate
    end
  end

  defp list_rpm_names(path) do
    case File.ls(path) do
      {:ok, list} ->
        Enum.filter(list, &String.ends_with?(&1, ".rpm"))

      _ -> []
    end
  end
end
