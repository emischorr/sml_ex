defmodule Sml.DecoderTest do
  use ExUnit.Case, async: true

  import Sml.Builder, only: [encode: 1, message: 3]

  alias Sml.{Decoder, Messages, Obis, PeriodEntry, Tree}

  defp decode_body(tag, body) do
    {:ok, [%Sml.Message{body: decoded}]} = Decoder.decode_messages(message("\x01", tag, body))
    decoded
  end

  test "decodes message headers" do
    assert {:ok, [message]} = Decoder.decode_messages(message("\x42", 0x0201, [nil]))

    assert %Sml.Message{
             transaction_id: "\x42",
             group_no: 0,
             abort_on_error: 0,
             body: %Messages.CloseResponse{global_signature: nil}
           } = message
  end

  test "unknown message types are kept as raw terms" do
    assert decode_body(0x0999, [{:uint, 1, 7}]) == {:unknown, 0x0999, [7]}
  end

  test "known message types with an unexpected shape are kept as raw terms" do
    assert decode_body(0x0201, [nil, nil]) == {:unknown, 0x0201, [nil, nil]}

    broken_entry = [nil, {:octet, "srv"}, nil, nil, [[nil, nil]], nil, nil]
    assert {:unknown, 0x0701, _} = decode_body(0x0701, broken_entry)
  end

  test "GetProcParameterResponse with a parameter tree" do
    child = [
      {:octet, <<1, 0, 1, 8, 0, 255>>},
      [
        {:uint, 1, 2},
        [{:octet, <<1, 0, 1, 8, 0, 255>>}, {:uint, 1, 30}, {:int, 1, -1}, {:uint, 4, 1234}, nil]
      ],
      nil
    ]

    time = [{:octet, "time"}, [{:uint, 1, 4}, [{:uint, 1, 1}, {:uint, 4, 99}]], nil]

    root = [
      {:octet, <<129, 129, 199, 130, 3, 255>>},
      [{:uint, 1, 1}, {:octet, "EMH"}],
      [child, time]
    ]

    assert %Messages.GetProcParameterResponse{
             server_id: "srv",
             parameter_tree_path: [%Obis{c: 199}],
             parameter_tree: %Tree{
               name: %Obis{c: 199},
               value: {:value, "EMH"},
               children: [
                 %Tree{value: {:period_entry, %PeriodEntry{unit: 30, value: 1234} = entry}},
                 %Tree{name: "time", value: {:time, {:sec_index, 99}}, children: []}
               ]
             }
           } =
             decode_body(0x0501, [
               {:octet, "srv"},
               [{:octet, <<129, 129, 199, 130, 3, 255>>}],
               root
             ])

    assert PeriodEntry.scaled_value(entry) == 123.4
  end

  test "AttentionResponse" do
    assert %Messages.AttentionResponse{
             server_id: "srv",
             attention_no: "\x81\x81\xC7\xC7\xFE\x00",
             attention_details: nil
           } =
             decode_body(0xFF01, [
               {:octet, "srv"},
               {:octet, <<0x81, 0x81, 0xC7, 0xC7, 0xFE, 0x00>>},
               nil,
               nil
             ])
  end

  test "OpenRequest and GetListRequest" do
    assert %Messages.OpenRequest{username: "user", password: "pw", sml_version: 1} =
             decode_body(0x0100, [
               nil,
               {:octet, "client"},
               {:octet, "f"},
               nil,
               {:octet, "user"},
               {:octet, "pw"},
               {:uint, 1, 1}
             ])

    assert %Messages.GetListRequest{list_name: %Obis{a: 1, c: 99}} =
             decode_body(0x0700, [nil, nil, nil, nil, {:octet, <<1, 0, 99, 0, 0, 255>>}])
  end

  test "reports offsets of parse errors and invalid CRCs" do
    valid = message("\x01", 0x0201, [nil])
    truncated = binary_part(valid, 0, byte_size(valid) - 3)

    assert {:error, {:parse_error, :unexpected_end, offset}} =
             Decoder.decode_messages(valid <> truncated)

    assert offset >= byte_size(valid)

    assert Decoder.decode_messages(<<0x72, 0x01, 0x01>>) ==
             {:error, {:parse_error, {:invalid_message_size, 2}, 0}}

    wrong_crc = binary_part(valid, 0, byte_size(valid) - 3) <> <<0, 0, 0>>
    assert Decoder.decode_messages(wrong_crc) == {:error, :invalid_crc}
    assert {:ok, [_]} = Decoder.decode_messages(wrong_crc, crc: false)
  end

  test "ignores trailing zero padding" do
    assert {:ok, [_]} = Decoder.decode_messages(message("\x01", 0x0201, [nil]) <> <<0, 0>>)
  end

  test "encodes and decodes a list entry roundtrip" do
    entry =
      encode([
        {:octet, <<1, 0, 1, 8, 0, 255>>},
        {:uint, 2, 0x182},
        nil,
        {:uint, 1, 30},
        {:int, 1, -1},
        {:uint, 8, 1},
        nil
      ])

    assert {:ok, [_, 0x182, nil, 30, -1, 1, nil], ""} = Sml.Parser.parse(entry)
  end
end
