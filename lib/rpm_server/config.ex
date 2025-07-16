defmodule RPMServer.Config do
  @default_config_path "repo_config.yaml"

  # Always fetch REPO_CONFIG_PATH at runtime (not compile time)
  defp config_path do
    System.get_env("REPO_CONFIG_PATH") || @default_config_path
  end

  @doc """
  Load config on demand from REPO_CONFIG_PATH or fallback.
  Returns only the 'repos' list or [].
  """
  def load_config do
    case YamlElixir.read_from_file(config_path()) do
      {:ok, %{"repos" => repos}} ->
        repos

      {:error, reason} ->
        IO.warn("⚠️ Failed to read config file at #{config_path()}: #{inspect(reason)}")
        []

      _ ->
        IO.warn("⚠️ Invalid or missing config structure in #{config_path()}")
        []
    end
  end

  @doc """
  Safe version: returns paths for given repo or empty list.
  """
  def get_paths(repo_id) do
    case YamlElixir.read_from_file(config_path()) do
      {:ok, %{"base_path" => base, "repos" => repos}} ->
        paths =
          Enum.find(repos, fn %{"id" => id} -> id == repo_id end)
          |> case do
            nil -> []
            repo -> Map.get(repo, "paths", [])
          end

        Enum.map(paths, &Path.expand(&1, base))

      {:error, reason} ->
        IO.warn("⚠️ Could not load config from #{config_path()}: #{inspect(reason)}")
        []

      _ ->
        IO.warn("⚠️ Invalid config format in #{config_path()}")
        []
    end
  end

  @doc """
  Strict version: raises if config is unreadable or repo is missing.
  Use this in APIs or production code paths.
  """
  def get_paths!(repo_id) do
    case YamlElixir.read_from_file(config_path()) do
      {:ok, %{"base_path" => base, "repos" => repos}} ->
        case Enum.find(repos, fn %{"id" => id} -> id == repo_id end) do
          nil ->
            raise "❌ Repo '#{repo_id}' not found in config file at #{config_path()}"

          %{"paths" => paths} ->
            Enum.map(paths, &Path.expand(&1, base))

          _ ->
            raise "❌ Invalid repo structure in config for '#{repo_id}'"
        end

      {:error, reason} ->
        raise "❌ Failed to read config from #{config_path()}: #{inspect(reason)}"

      _ ->
        raise "❌ Invalid config format in #{config_path()}"
    end
  end

  @doc """
  Used at startup to ensure config file exists and is valid.
  """
  def validate_or_exit! do
    case load_config() do
      [] ->
        IO.puts(:stderr, """
        ❌ ERROR: Failed to load repo_config.yaml from #{config_path()}
        Please check that the file exists and is correctly formatted.
        """)

        :timer.sleep(500)
        System.halt(1)

      _ ->
        :ok
    end
  end
end
