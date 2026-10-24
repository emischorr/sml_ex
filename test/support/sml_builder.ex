defmodule Sml.Builder do
  @moduledoc false
  # Test-only SML encoder for building synthetic telegrams.
  #
  # Terms: {:octet, binary}, {:uint, bytes, n}, {:int, bytes, n}, {:bool, b},
  # lists, nil (optional, 0x01) and :eom (0x00).

  import Bitwise

  def encode(nil), do: <<0x01>>
  def encode(:eom), do: <<0x00>>
  def encode({:bool, b}), do: <<0x42, if(b, do: 1, else: 0)>>
  def encode({:uint, bytes, n}), do: <<tl(0b110, bytes + 1)::binary, n::size(bytes * 8)>>
  def encode({:int, bytes, n}), do: <<tl(0b101, bytes + 1)::binary, n::signed-size(bytes * 8)>>

  def encode({:octet, bin}) do
    size = byte_size(bin)
    total = if size + 1 <= 15, do: size + 1, else: size + 2
    tl(0b000, total) <> bin
  end

  def encode(list) when is_list(list),
    do: IO.iodata_to_binary([tl(0b111, length(list)) | Enum.map(list, &encode/1)])

  defp tl(type, len) when len <= 15, do: <<0::1, type::3, len::4>>
  defp tl(type, len) when len <= 255, do: <<1::1, type::3, len >>> 4::4, 0::4, band(len, 0xF)::4>>

  @doc "Encodes a complete message with a valid X-25 CRC."
  def message(transaction_id, tag, body) do
    signed =
      IO.iodata_to_binary([
        <<0x76>>,
        encode({:octet, transaction_id}),
        encode({:uint, 1, 0}),
        encode({:uint, 1, 0}),
        encode([{:uint, 4, tag}, body])
      ])

    # The CRC goes on the wire low byte first, inside an Unsigned16.
    <<crc::16>> = <<Sml.CRC16.x25(signed)::little-16>>
    signed <> encode({:uint, 2, crc}) <> <<0x00>>
  end

  @doc "Wraps messages into a transport frame (escaping, padding, X-25 CRC)."
  def frame(payload) do
    pad = rem(4 - rem(byte_size(payload), 4), 4)
    padded = payload <> :binary.copy(<<0>>, pad)
    escaped = for <<block::binary-size(4) <- padded>>, into: <<>>, do: escape(block)
    data = <<0x1B1B1B1B::32, 0x01010101::32>> <> escaped <> <<0x1B1B1B1B::32, 0x1A, pad>>
    data <> <<Sml.CRC16.x25(data)::little-16>>
  end

  defp escape(<<0x1B1B1B1B::32>> = block), do: block <> block
  defp escape(block), do: block

  def entry(obis, unit, scaler, value) do
    [{:octet, obis}, nil, nil, unit && {:uint, 1, unit}, scaler && {:int, 1, scaler}, value, nil]
  end

  def open_response(server_id) do
    message("\x01", 0x0101, [nil, nil, {:octet, "file"}, {:octet, server_id}, nil, nil])
  end

  def get_list_response(server_id, entries) do
    message("\x02", 0x0701, [
      nil,
      {:octet, server_id},
      nil,
      [{:uint, 1, 1}, {:uint, 4, 1234}],
      entries,
      nil,
      nil
    ])
  end

  def close_response, do: message("\x03", 0x0201, [nil])

  @doc "A typical meter telegram with import, export, power and manufacturer."
  def telegram(opts \\ []) do
    server_id = Keyword.get(opts, :server_id, <<0x0A, 0x01, "EMH", 0, 0, 0, 0, 1>>)

    entries =
      Keyword.get(opts, :entries, [
        entry(<<129, 129, 199, 130, 3, 255>>, nil, nil, {:octet, "EMH"}),
        entry(<<1, 0, 1, 8, 0, 255>>, 30, -1, {:uint, 8, 123_456_789}),
        entry(<<1, 0, 2, 8, 0, 255>>, 30, -1, {:uint, 8, 5_000}),
        entry(<<1, 0, 16, 7, 0, 255>>, 27, 0, {:int, 4, -345})
      ])

    frame(open_response(server_id) <> get_list_response(server_id, entries) <> close_response())
  end
end
