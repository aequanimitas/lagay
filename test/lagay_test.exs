defmodule LagayTest do
  use ExUnit.Case
  doctest Lagay

  test "greets the world" do
    assert Lagay.hello() == :world
  end
end
