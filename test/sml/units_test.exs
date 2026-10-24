defmodule Sml.UnitsTest do
  use ExUnit.Case, async: true

  doctest Sml.Units

  test "unknown codes" do
    assert Sml.Units.name(200) == nil
    assert Sml.Units.symbol(nil) == nil
    assert Sml.Units.code(:parsec) == nil
  end
end
