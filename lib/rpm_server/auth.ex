defmodule RPMServer.Auth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    token = System.get_env("RPM_API_TOKEN") || "changeme"

    case get_req_header(conn, "authorization") do
      ["Bearer " <> ^token] -> conn
      _ ->
        conn
        |> send_resp(401, "Unauthorized")
        |> halt()
    end
  end
end
