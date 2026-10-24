defmodule Sml.CRC16 do
  @moduledoc """
  The 16 bit checksums used by SML for the transport frame and each message.

  The standard algorithm is CRC-16/X-25 (polynomial `0x1021` reflected,
  init `0xFFFF`, final XOR `0xFFFF`), transmitted low byte first. Some meters,
  notably the Holley DTZ541, use CRC-16/Kermit (init `0`, no final XOR)
  transmitted high byte first instead.

  `valid?/3` checks the two checksum bytes as they appear on the wire against
  either or both variants.
  """

  import Bitwise

  @type mode :: :auto | :x25 | :kermit

  @table (for i <- 0..255 do
            Enum.reduce(1..8, i, fn _, crc ->
              if band(crc, 1) == 1, do: bxor(crc >>> 1, 0x8408), else: crc >>> 1
            end)
          end)
         |> List.to_tuple()

  @doc """
  Calculates the CRC-16/X-25 checksum of `data`.

      iex> Sml.CRC16.x25("123456789")
      0x906E
  """
  @spec x25(binary()) :: 0..0xFFFF
  def x25(data) when is_binary(data), do: bxor(reflected(data, 0xFFFF), 0xFFFF)

  @doc """
  Calculates the CRC-16/Kermit checksum of `data`.

      iex> Sml.CRC16.kermit("123456789")
      0x2189
  """
  @spec kermit(binary()) :: 0..0xFFFF
  def kermit(data) when is_binary(data), do: reflected(data, 0)

  @doc """
  Checks the checksum bytes `crc` (in wire order) for `data`.

  `mode` is `:x25`, `:kermit` or `:auto` (accept either).

      iex> Sml.CRC16.valid?("123456789", <<0x6E, 0x90>>, :x25)
      true

      iex> Sml.CRC16.valid?("123456789", <<0x21, 0x89>>, :auto)
      true
  """
  @spec valid?(binary(), <<_::16>>, mode()) :: boolean()
  def valid?(data, <<crc::little-16>>, :x25), do: x25(data) == crc
  def valid?(data, <<crc::big-16>>, :kermit), do: kermit(data) == crc
  def valid?(data, crc, :auto), do: valid?(data, crc, :x25) or valid?(data, crc, :kermit)

  defp reflected(<<byte, rest::binary>>, crc) do
    reflected(rest, bxor(crc >>> 8, elem(@table, band(bxor(crc, byte), 0xFF))))
  end

  defp reflected(<<>>, crc), do: crc
end
