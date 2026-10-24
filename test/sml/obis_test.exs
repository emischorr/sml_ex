defmodule Sml.ObisTest do
  use ExUnit.Case, async: true

  alias Sml.Obis

  doctest Obis

  test "parse/1 accepts different notations" do
    expected = %Obis{a: 1, b: 0, c: 1, d: 8, e: 0, f: 255}

    assert Obis.parse("1-0:1.8.0*255") == {:ok, expected}
    assert Obis.parse("1-0:1.8.0&255") == {:ok, expected}
    assert Obis.parse("1-0:1.8.0.255") == {:ok, expected}
    assert Obis.parse(<<1, 0, 1, 8, 0, 255>>) == {:ok, expected}
    assert Obis.parse(expected) == {:ok, expected}
  end

  test "parse/1 prefers the string notation for printable 6 byte binaries" do
    assert Obis.parse("16.7.0") == {:ok, %Obis{c: 16, d: 7, e: 0}}
  end

  test "parse/1 rejects invalid input" do
    assert Obis.parse("1-0:1.8") == {:error, :invalid_obis}
    assert Obis.parse("1-0:256.8.0") == {:error, :invalid_obis}
    assert Obis.parse(42) == {:error, :invalid_obis}
    assert Obis.parse(:nope) == {:error, {:unknown_alias, :nope}}
    assert_raise ArgumentError, fn -> Obis.parse!("x") end
  end

  test "aliases with several codes" do
    assert {:ok, [_, _]} = Obis.parse(:server_id)
    assert {:ok, [_, _]} = Obis.parse(:hersteller)
    assert :bezug in Obis.aliases()
    assert :import in Obis.aliases()
  end

  test "match?/2" do
    current = Obis.parse!("1-0:16.7.0*255")

    assert Obis.match?(Obis.parse!(:leistung), current)
    assert Obis.match?(Obis.parse!("16.7.0"), current)
    assert Obis.match?(Obis.parse!(:server_id), Obis.parse!("1-0:96.1.0*255"))
    refute Obis.match?(Obis.parse!("1-0:16.7.0*0"), current)
    refute Obis.match?(Obis.parse!(:bezug), current)
    refute Obis.match?(Obis.parse!(:bezug), <<1, 2, 3>>)
  end

  test "string conversion and inspect" do
    obis = Obis.parse!("129-129:199.130.3*255")

    assert to_string(obis) == "129-129:199.130.3*255"
    assert inspect(obis) == "#Sml.Obis<129-129:199.130.3*255>"
    assert to_string(Obis.parse!("1.8.0")) == "1.8.0"
  end
end
