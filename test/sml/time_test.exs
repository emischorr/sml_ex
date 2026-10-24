defmodule Sml.TimeTest do
  use ExUnit.Case, async: true

  doctest Sml.Time

  test "local timestamps and fallbacks" do
    assert Sml.Time.decode([3, [1_700_000_000, 60, 0]]) ==
             {:local_timestamp, ~U[2023-11-14 22:13:20Z], 60, 0}

    assert Sml.Time.decode(nil) == nil
    assert Sml.Time.decode(42) == {:sec_index, 42}
    assert Sml.Time.decode([9, 1]) == {:unknown, [9, 1]}
  end
end
