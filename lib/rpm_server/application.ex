defmodule RPMServer.Application do
  use Application

  def start(_type, _args) do
    # Validate config at runtime startup
    RPMServer.Config.validate_or_exit!()

    children = [
      {Task, fn -> RPMServer.start() end}
    ]

    opts = [strategy: :one_for_one, name: RPMServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
