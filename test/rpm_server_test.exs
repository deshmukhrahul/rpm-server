defmodule RPMServerTest do
  use ExUnit.Case
  doctest RPMServer

  test "greets the world" do
    assert RPMServer.hello() == :world
  end
end
