defmodule Sml.ListEntryTest do
  use ExUnit.Case, async: true

  alias Sml.ListEntry

  doctest ListEntry

  test "scaled_value/1" do
    assert ListEntry.scaled_value(%ListEntry{value: 5, scaler: nil}) == 5
    assert ListEntry.scaled_value(%ListEntry{value: 5, scaler: 0}) == 5
    assert ListEntry.scaled_value(%ListEntry{value: -1772, scaler: -1}) == -177.2
    assert ListEntry.scaled_value(%ListEntry{value: 175_817_148, scaler: -5}) == 1758.17148
    assert ListEntry.scaled_value(%ListEntry{value: nil, scaler: -1}) == nil
  end

  test "unit_name/1" do
    assert ListEntry.unit_name(%ListEntry{unit: 30}) == :wh
    assert ListEntry.unit_name(%ListEntry{unit: nil}) == nil
  end
end
