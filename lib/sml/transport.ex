defmodule Sml.Transport do
  @moduledoc """
  SML transport protocol version 1 (framing of SML files).

  A telegram on the wire looks like this:

      1B 1B 1B 1B  01 01 01 01   start sequence
      ...                        SML messages, padded with 00 to a multiple of 4
      1B 1B 1B 1B  1A PP CC CC   end sequence, PP = padding bytes, CCCC = CRC

  Inside the payload a literal `1B 1B 1B 1B` block is escaped by doubling it.
  The CRC (see `Sml.CRC16`) covers everything from the start
  sequence up to and including the padding count byte.

  Use `unwrap/2` to get the raw message bytes out of one telegram and
  `extract/1` to split a byte stream (e.g. read from a serial IR head) into
  complete telegrams.
  """

  alias Sml.CRC16

  @escape <<0x1B, 0x1B, 0x1B, 0x1B>>
  @start <<0x1B, 0x1B, 0x1B, 0x1B, 0x01, 0x01, 0x01, 0x01>>

  @type unwrap_error ::
          :no_start_sequence | :incomplete | :invalid_escape | :invalid_padding | :invalid_crc

  @doc """
  Returns `true` if `data` contains an SML transport start sequence.
  """
  @spec framed?(binary()) :: boolean()
  def framed?(data) when is_binary(data), do: :binary.match(data, @start) != :nomatch

  @doc """
  Extracts the payload (the SML messages) from the first telegram in `data`.

  Bytes before the start sequence are ignored. Escaped sequences are
  unescaped and padding is removed.

  ## Options

    * `:crc` - checksum algorithm to verify: `:auto` (default, X-25 or
      Kermit), `:x25`, `:kermit`, or `false` to skip the check
  """
  @spec unwrap(binary(), keyword()) :: {:ok, binary()} | {:error, unwrap_error()}
  def unwrap(data, opts \\ []) when is_binary(data) do
    with {pos, _} <- :binary.match(data, @start),
         frame = drop(data, pos),
         {:ok, payload, frame_len, pad, crc} <- unescape(drop(frame, 8), 8, []),
         :ok <- verify_crc(binary_part(frame, 0, frame_len - 2), crc, opts),
         {:ok, payload} <- strip_padding(payload, pad) do
      {:ok, payload}
    else
      :nomatch -> {:error, :no_start_sequence}
      {:error, _} = error -> error
    end
  end

  @doc """
  Splits a byte stream into complete telegrams.

  Returns the complete telegrams found (still framed, ready for
  `Sml.decode/2`) and the remaining bytes, which should be prepended to the
  next chunk read from the stream. Garbage between telegrams and frames that
  are interrupted by a new start sequence are dropped.

      {telegrams, buffer} = Sml.Transport.extract(buffer <> chunk)
  """
  @spec extract(binary()) :: {[binary()], binary()}
  def extract(buffer) when is_binary(buffer), do: extract(buffer, [])

  defp extract(buffer, acc) do
    case :binary.match(buffer, @start) do
      :nomatch ->
        {Enum.reverse(acc), keep_tail(buffer)}

      {pos, _} ->
        candidate = drop(buffer, pos)

        case find_end(drop(candidate, 8), 8) do
          {:ok, len} -> extract(drop(candidate, len), [binary_part(candidate, 0, len) | acc])
          {:skip, len} -> extract(drop(candidate, len), acc)
          :incomplete -> {Enum.reverse(acc), candidate}
        end
    end
  end

  # Keep enough bytes to recognize a start sequence split across two reads.
  defp keep_tail(buffer) when byte_size(buffer) > 7,
    do: binary_part(buffer, byte_size(buffer), -7)

  defp keep_tail(buffer), do: buffer

  # Both scanners walk the frame in 4 byte blocks; `offset` is the position of
  # `rest` within the frame.
  defp find_end(rest, offset) do
    case rest do
      <<@escape, @escape, rest::binary>> -> find_end(rest, offset + 8)
      <<@escape, 0x1A, _pad, _crc::16, _::binary>> -> {:ok, offset + 8}
      <<@escape, 1, 1, 1, 1, _::binary>> -> {:skip, offset}
      <<@escape, _::binary-size(4), _::binary>> -> {:skip, offset + 8}
      <<@escape, _::binary>> -> :incomplete
      <<_::binary-size(4), rest::binary>> -> find_end(rest, offset + 4)
      _ -> :incomplete
    end
  end

  defp unescape(rest, offset, acc) do
    case rest do
      <<@escape, @escape, rest::binary>> ->
        unescape(rest, offset + 8, [acc | @escape])

      <<@escape, 0x1A, pad, crc::binary-size(2), _::binary>> ->
        {:ok, IO.iodata_to_binary(acc), offset + 8, pad, crc}

      <<@escape, _::binary-size(4), _::binary>> ->
        {:error, :invalid_escape}

      <<@escape, _::binary>> ->
        {:error, :incomplete}

      <<block::binary-size(4), rest::binary>> ->
        unescape(rest, offset + 4, [acc | block])

      _ ->
        {:error, :incomplete}
    end
  end

  defp drop(binary, count), do: binary_part(binary, count, byte_size(binary) - count)

  defp verify_crc(data, crc, opts) do
    case Keyword.get(opts, :crc, :auto) do
      false -> :ok
      mode -> if CRC16.valid?(data, crc, mode), do: :ok, else: {:error, :invalid_crc}
    end
  end

  # The spec allows 0-3 padding bytes, but e.g. DZG meters send a full block of 4.
  defp strip_padding(payload, pad) when pad <= byte_size(payload) do
    {:ok, binary_part(payload, 0, byte_size(payload) - pad)}
  end

  defp strip_padding(_payload, _pad), do: {:error, :invalid_padding}
end
