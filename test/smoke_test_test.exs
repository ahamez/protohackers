defmodule SmokeTestTest do
  use ExUnit.Case
  doctest SmokeTest

  test "greets the world" do
    assert SmokeTest.hello() == :world
  end
end
