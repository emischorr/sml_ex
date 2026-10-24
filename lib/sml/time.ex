defmodule Sml.Time do
  @moduledoc """
  Decoding of `SML_Time`.

  SML times are a choice of

    * `1` - `secIndex`, seconds since an arbitrary point (usually power on),
      decoded as `{:sec_index, seconds}`
    * `2` - `timestamp`, Unix time in UTC, decoded as `DateTime`
    * `3` - `localTimestamp`, Unix time plus local and daylight saving offsets
      in minutes, decoded as `{:local_timestamp, DateTime, local_offset,
      season_offset}`
  """

  @type t ::
          {:sec_index, non_neg_integer()}
          | DateTime.t()
          | {:local_timestamp, DateTime.t(), integer(), integer()}
          | nil

  @doc """
  Decodes a parsed `SML_Time` term.

      iex> Sml.Time.decode([1, 1234])
      {:sec_index, 1234}

      iex> Sml.Time.decode([2, 1_700_000_000])
      ~U[2023-11-14 22:13:20Z]
  """
  @spec decode(Sml.Parser.term_t()) :: t() | {:unknown, term()}
  def decode(nil), do: nil
  def decode([1, seconds]) when is_integer(seconds), do: {:sec_index, seconds}
  def decode([2, timestamp]) when is_integer(timestamp), do: DateTime.from_unix!(timestamp)

  def decode([3, [timestamp, local_offset, season_offset]]) when is_integer(timestamp),
    do: {:local_timestamp, DateTime.from_unix!(timestamp), local_offset, season_offset}

  # Some meters send the secIndex directly instead of wrapping it in a choice.
  def decode(seconds) when is_integer(seconds), do: {:sec_index, seconds}
  def decode(other), do: {:unknown, other}
end
