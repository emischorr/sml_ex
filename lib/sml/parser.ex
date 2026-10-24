defmodule Sml.Parser do
  @moduledoc """
  Low-level parser for the SML binary encoding (type-length-value).

  Every element starts with one or more TL bytes:

      bit 7     more TL bytes follow
      bits 6-4  type: 000 octet string, 100 boolean, 101 integer,
                      110 unsigned, 111 list
      bits 3-0  length nibble

  With multiple TL bytes the length nibbles are concatenated. For lists the
  length is the number of elements; for all other types it is the number of
  bytes *including* the TL bytes.

  Elements are mapped to plain Elixir terms:

  | SML                       | Elixir                |
  | ------------------------- | --------------------- |
  | octet string              | binary                |
  | boolean                   | `true` / `false`      |
  | integer / unsigned        | integer               |
  | list                      | list                  |
  | `0x01` (optional, absent) | `nil`                 |
  | `0x00` (end of message)   | `:end_of_message`     |

  Signedness is lost in this representation; `Sml.Decoder` knows the schema
  and does not need it.
  """

  @type term_t ::
          binary() | boolean() | integer() | nil | :end_of_message | [term_t()]

  @type error :: {:error, reason :: atom() | tuple(), rest :: binary()}

  @octet_string 0b000
  @boolean 0b100
  @integer 0b101
  @unsigned 0b110
  @list 0b111

  @doc """
  Parses one element from the beginning of `data`.

  Returns the element and the remaining bytes. On failure the remaining bytes
  point at the element that could not be parsed.

      iex> Sml.Parser.parse(<<0x62, 0x1E, 0xFF>>)
      {:ok, 30, <<0xFF>>}

      iex> Sml.Parser.parse(<<0x72, 0x03, "EM", 0x52, 0xFF>>)
      {:ok, ["EM", -1], ""}
  """
  @spec parse(binary()) :: {:ok, term_t(), binary()} | error()
  def parse(<<0x00, rest::binary>>), do: {:ok, :end_of_message, rest}

  def parse(data) when is_binary(data) do
    with {:ok, type, len, tl_size, rest} <- tl(data, data) do
      value(type, len, tl_size, rest, data)
    end
  end

  @doc """
  Parses `count` consecutive elements.
  """
  @spec parse_many(binary(), non_neg_integer()) :: {:ok, [term_t()], binary()} | error()
  def parse_many(data, count), do: parse_many(data, count, [])

  defp parse_many(rest, 0, acc), do: {:ok, Enum.reverse(acc), rest}

  defp parse_many(data, count, acc) do
    with {:ok, element, rest} <- parse(data) do
      parse_many(rest, count - 1, [element | acc])
    end
  end

  @doc """
  Parses all elements in `data` until it is exhausted.

  Handy for inspecting unknown data:

      iex> Sml.Parser.parse_all(<<0x01, 0x42, 0x01, 0x00>>)
      {:ok, [nil, true, :end_of_message]}
  """
  @spec parse_all(binary()) :: {:ok, [term_t()]} | error()
  def parse_all(data), do: parse_all(data, [])

  defp parse_all(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  defp parse_all(data, acc) do
    with {:ok, element, rest} <- parse(data) do
      parse_all(rest, [element | acc])
    end
  end

  @doc """
  Parses only the TL header of a list and returns its element count.
  """
  @spec parse_list_header(binary()) :: {:ok, non_neg_integer(), binary()} | error()
  def parse_list_header(data) do
    case tl(data, data) do
      {:ok, @list, count, _tl_size, rest} -> {:ok, count, rest}
      {:ok, type, _, _, _} -> {:error, {:expected_list, type}, data}
      error -> error
    end
  end

  # TL byte(s)

  defp tl(<<0::1, type::3, len::4, rest::binary>>, _start), do: {:ok, type, len, 1, rest}
  defp tl(<<1::1, type::3, len::4, rest::binary>>, start), do: tl_more(rest, type, len, 1, start)
  defp tl(<<>>, start), do: {:error, :unexpected_end, start}

  defp tl_more(<<more::1, _::3, nibble::4, rest::binary>>, type, len, size, start) do
    len = len * 16 + nibble

    case more do
      1 -> tl_more(rest, type, len, size + 1, start)
      0 -> {:ok, type, len, size + 1, rest}
    end
  end

  defp tl_more(<<>>, _type, _len, _size, start), do: {:error, :unexpected_end, start}

  # Values

  defp value(@list, count, _tl_size, rest, _start), do: parse_many(rest, count)

  defp value(type, len, tl_size, rest, start) do
    size = len - tl_size

    cond do
      size < 0 ->
        {:error, {:invalid_length, len}, start}

      size > byte_size(rest) ->
        {:error, :unexpected_end, start}

      true ->
        payload = binary_part(rest, 0, size)

        case scalar(type, size, payload) do
          {:ok, value} -> {:ok, value, binary_part(rest, size, byte_size(rest) - size)}
          {:error, reason} -> {:error, reason, start}
        end
    end
  end

  defp scalar(@octet_string, 0, _), do: {:ok, nil}
  defp scalar(@octet_string, _, payload), do: {:ok, payload}
  defp scalar(@boolean, 1, <<byte>>), do: {:ok, byte != 0}
  defp scalar(@integer, size, payload) when size > 0, do: {:ok, signed(payload, size)}
  defp scalar(@unsigned, size, payload) when size > 0, do: {:ok, unsigned(payload, size)}
  defp scalar(type, size, _), do: {:error, {:invalid_element, type, size}}

  defp signed(payload, size) do
    value = :binary.decode_unsigned(payload)
    max = Bitwise.bsl(1, size * 8)
    if value >= div(max, 2), do: value - max, else: value
  end

  defp unsigned(payload, _size), do: :binary.decode_unsigned(payload)
end
