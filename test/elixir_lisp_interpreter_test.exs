defmodule ElixirLispInterpreterTest do
  use ExUnit.Case
  doctest ElixirLispInterpreter

  test "greets the world" do
    assert ElixirLispInterpreter.hello() == :world
  end
end
