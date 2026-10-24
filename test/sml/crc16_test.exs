defmodule Sml.CRC16Test do
  use ExUnit.Case, async: true

  alias Sml.CRC16

  doctest CRC16

  # Messages captured from real meters; the checksum is in the last 3 bytes
  # before the end-of-message marker.
  @messages [
    "7605032b18116200620072630201710163fa3600",
    "7605171756bd6200620072630201710163170f00",
    "760700070615fce7620062007263010176010107000702e053ce0b0901454d4800004895f701016333aa00"
  ]

  test "validates X-25 checksums of real messages" do
    for hex <- @messages do
      message = Base.decode16!(hex, case: :lower)
      signed = binary_part(message, 0, byte_size(message) - 4)
      crc = binary_part(message, byte_size(message) - 3, 2)

      assert CRC16.valid?(signed, crc, :x25)
      assert CRC16.valid?(signed, crc, :auto)
      refute CRC16.valid?(signed, crc, :kermit)
    end
  end

  test "rejects wrong checksums" do
    refute CRC16.valid?("123456789", <<0, 0>>, :auto)
  end
end
