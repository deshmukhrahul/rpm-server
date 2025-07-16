defmodule RPMServer do
  use Plug.Router
  require Logger

  alias RPMServer.API
  alias RPMServer.Browser
  alias RPMServer.Auth

  plug(Plug.Static,
    at: "/assets",
    from: :rpm_server,
    gzip: false,
    only: ~w(style.css)
  )

  plug(:match)
  plug(:dispatch)

  # Public APIs
  get("/api/tags/:folder", do: API.list_tags(conn, folder))
  get("/api/tags/:folder/:tag/packages", do: API.list_packages(conn, folder, tag))

  # Protected endpoint with token auth
  post "/api/create-tag" do
    conn = Auth.call(conn, [])
    API.create_tag(conn)
  end

  # File browser
  match("/repo/tags/*path", do: Browser.serve(conn, path))

  # Fallback
  match(_, do: send_resp(conn, 404, "Not found"))

  def start do
    Plug.Cowboy.http(__MODULE__, [], port: 8080)
    Logger.info("🚀 Elixir RPM server running at http://localhost:8080")
  end
end
