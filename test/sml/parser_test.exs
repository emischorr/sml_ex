defmodule Sml.ParserTest do
  use ExUnit.Case, async: true

  alias Sml.Parser

  doctest Parser

  describe "parse/1" do
    test "octet strings" do
      assert Parser.parse(<<0x04, "EMH", 0xAA>>) == {:ok, "EMH", <<0xAA>>}
      assert Parser.parse(<<0x01>>) == {:ok, nil, ""}
    end

    test "multi-byte TL octet string" do
      key = :binary.copy(<<0xAB>>, 48)
      # 0x83 0x02: length 0x32 = 50 = 2 TL bytes + 48 bytes payload
      assert Parser.parse(<<0x83, 0x02, key::binary>>) == {:ok, key, ""}
    end

    test "unsigned integers" do
      assert Parser.parse(<<0x62, 0xFF>>) == {:ok, 255, ""}
      assert Parser.parse(<<0x63, 0x01, 0x00>>) == {:ok, 256, ""}
      assert Parser.parse(<<0x69, 0, 0, 0, 0, 0x0A, 0x7A, 0xC1, 0xBC>>) == {:ok, 175_817_148, ""}
      # odd sizes as sent by some meters
      assert Parser.parse(<<0x64, 0x01, 0x01, 0x80>>) == {:ok, 0x010180, ""}
    end

    test "signed integers" do
      assert Parser.parse(<<0x52, 0xFF>>) == {:ok, -1, ""}
      assert Parser.parse(<<0x52, 0x7F>>) == {:ok, 127, ""}
      assert Parser.parse(<<0x53, 0xFF, 0xFE>>) == {:ok, -2, ""}
      assert Parser.parse(<<0x55, 0xFF, 0xFF, 0xF9, 0x14>>) == {:ok, -1772, ""}
      assert Parser.parse(<<0x55, 0x80, 0, 0, 0>>) == {:ok, -2_147_483_648, ""}
    end

    test "booleans" do
      assert Parser.parse(<<0x42, 0x00>>) == {:ok, false, ""}
      assert Parser.parse(<<0x42, 0x01>>) == {:ok, true, ""}
    end

    test "lists" do
      assert Parser.parse(<<0x72, 0x62, 0x01, 0x72, 0x01, 0x42, 0x00>>) ==
               {:ok, [1, [nil, false]], ""}

      assert Parser.parse(<<0x70>>) == {:ok, [], ""}
    end

    test "multi-byte TL list" do
      # 0xF1 0x01: list with 0x11 = 17 elements
      data = <<0xF1, 0x01>> <> :binary.copy(<<0x01>>, 17)
      assert Parser.parse(data) == {:ok, List.duplicate(nil, 17), ""}
    end

    test "end of message" do
      assert Parser.parse(<<0x00, 0x76>>) == {:ok, :end_of_message, <<0x76>>}
    end

    test "errors point at the failing element" do
      assert Parser.parse(<<0x63, 0x01>>) == {:error, :unexpected_end, <<0x63, 0x01>>}
      assert Parser.parse(<<>>) == {:error, :unexpected_end, ""}
      assert Parser.parse(<<0x51>>) == {:error, {:invalid_element, 0b101, 0}, <<0x51>>}

      assert Parser.parse(<<0x43, 1, 2>>) ==
               {:error, {:invalid_element, 0b100, 2}, <<0x43, 1, 2>>}

      assert Parser.parse(<<0x80>>) == {:error, :unexpected_end, <<0x80>>}

      assert Parser.parse(<<0x72, 0x62, 0x01, 0x63, 0x01>>) ==
               {:error, :unexpected_end, <<0x63, 0x01>>}
    end

    test "unknown types" do
      assert {:error, {:invalid_element, 0b001, 0}, _} = Parser.parse(<<0x11>>)
    end
  end

  test "parse_many/2 and parse_list_header/1" do
    assert Parser.parse_many(<<0x01, 0x62, 0x05, 0xFF>>, 2) == {:ok, [nil, 5], <<0xFF>>}
    assert Parser.parse_list_header(<<0x76, 0x01>>) == {:ok, 6, <<0x01>>}

    assert Parser.parse_list_header(<<0x62, 0x01>>) ==
             {:error, {:expected_list, 0b110}, <<0x62, 0x01>>}
  end
end
