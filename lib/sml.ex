defmodule Sml do
  @moduledoc """
  Decoder for SML (Smart Message Language) telegrams.

  SML (BSI TR-03109-1) is the protocol German electricity meters ("moderne
  Messeinrichtung", eHZ) use on their optical interface. A meter typically
  pushes a telegram every one to four seconds that contains the current
  readings, e.g. the energy counter (`1-0:1.8.0`) and the current power
  (`1-0:16.7.0`).

  ## Reading values

      {:ok, bezug_wh, 30} = Sml.value(telegram, :bezug)
      {:ok, leistung_w, 27} = Sml.value(telegram, :leistung)

  The third element is the DLMS unit code (`30` = Wh, `27` = W), see
  `Sml.Units`. Values are scaled with the scaler sent by the meter: the result
  is an integer if the scaler is not negative and a float otherwise.

  Keys can be an alias atom (see `Sml.Obis` for the list), an OBIS string like
  `"1-0:1.8.0"` or `"1-0:1.8.0*255"`, an `Sml.Obis` struct or the raw 6 byte
  OBIS binary.

  All functions accept either the raw telegram binary or an already decoded
  `Sml.File`. When reading several values from one telegram, decode it once:

      {:ok, file} = Sml.decode(telegram)
      {:ok, bezug, _unit} = Sml.value(file, :bezug)
      {:ok, einspeisung, _unit} = Sml.value(file, :einspeisung)

  ## Inspecting telegrams

  `decode/2` returns the full structure: an `Sml.File` with a list of
  `Sml.Message`s whose bodies are the structs in `Sml.Messages`. Since
  everything is a plain struct, pattern matching works as expected:

      {:ok, %Sml.File{messages: messages}} = Sml.decode(telegram)

      for %Sml.Message{body: %Sml.Messages.GetListResponse{val_list: entries}} <- messages,
          %Sml.ListEntry{obis: obis, unit: 27} = entry <- entries do
        {to_string(obis), Sml.ListEntry.scaled_value(entry)}
      end

  ## Reading from a serial port

  Telegrams arrive in arbitrary chunks. `Sml.Transport.extract/1` splits a
  buffer into complete telegrams and returns the rest for the next read:

      {telegrams, buffer} = Sml.Transport.extract(buffer <> chunk)
  """

  alias Sml.{Decoder, ListEntry, Obis, Transport}
  alias Sml.Messages.GetListResponse

  @typedoc "A raw telegram binary or a decoded `Sml.File`."
  @type source :: binary() | Sml.File.t()

  @typedoc "An alias atom, OBIS string, `Sml.Obis` struct or 6 byte OBIS binary."
  @type key :: atom() | String.t() | Obis.t()

  @type error ::
          Transport.unwrap_error()
          | Decoder.error()
          | :not_found
          | :invalid_obis
          | {:unknown_alias, atom()}

  @doc """
  Decodes a telegram into an `Sml.File`.

  `data` may be a complete transport frame (starting with
  `1B 1B 1B 1B 01 01 01 01`, leading garbage is skipped) or the bare message
  bytes without framing.

  ## Options

    * `:crc` - checksum algorithm used to verify the transport frame and each
      message: `:auto` (default) accepts CRC-16/X-25 as well as CRC-16/Kermit
      (used by e.g. Holley DTZ541), `:x25` or `:kermit` accept only that one,
      `false` skips verification for meters that send wrong checksums.

  ## Errors

    * `:no_start_sequence`, `:incomplete`, `:invalid_escape`,
      `:invalid_padding` - broken transport framing
    * `:invalid_crc` - a checksum does not match
    * `{:parse_error, reason, offset}` - invalid SML encoding at byte `offset`
      of the message payload
  """
  @spec decode(binary(), keyword()) :: {:ok, Sml.File.t()} | {:error, error()}
  def decode(data, opts \\ []) when is_binary(data) do
    with {:ok, payload} <- payload(data, opts),
         {:ok, messages} <- Decoder.decode_messages(payload, opts) do
      {:ok, %Sml.File{messages: messages}}
    end
  end

  @doc """
  Like `decode/2` but raises `Sml.DecodeError` on failure.
  """
  @spec decode!(binary(), keyword()) :: Sml.File.t()
  def decode!(data, opts \\ []) do
    case decode(data, opts) do
      {:ok, file} -> file
      {:error, reason} -> raise Sml.DecodeError, reason: reason
    end
  end

  @doc """
  Returns all list entries (readings) of all `GetListResponse` messages.
  """
  @spec entries(source()) :: {:ok, [ListEntry.t()]} | {:error, error()}
  def entries(source) do
    with {:ok, file} <- to_file(source) do
      {:ok, list_entries(file)}
    end
  end

  @doc """
  Returns the list entry for `key`.

  If several entries match a pattern without F group (e.g. some meters send
  `1-0:1.8.0*255` along with historic values `1-0:1.8.0*96`), the one with
  `F = 255` (current value) is preferred, otherwise the first match is
  returned.
  """
  @spec get(source(), key()) :: {:ok, ListEntry.t()} | {:error, error()}
  def get(source, key) do
    with {:ok, pattern} <- Obis.parse(key),
         {:ok, file} <- to_file(source) do
      case Enum.filter(list_entries(file), &Obis.match?(pattern, &1.obis)) do
        [] -> {:error, :not_found}
        entries -> {:ok, Enum.find(entries, hd(entries), &match?(%Obis{f: 255}, &1.obis))}
      end
    end
  end

  @doc """
  Returns the scaled value and the unit code for `key`.

  Non-numeric values (like the manufacturer ID) are returned as binaries; the
  unit is `nil` if the meter does not send one.

      {:ok, 12_345.6, 30} = Sml.value(telegram, :bezug)
      {:ok, 230, 27} = Sml.value(telegram, "1-0:16.7.0")
      {:ok, "EMH", nil} = Sml.value(telegram, :hersteller)
  """
  @spec value(source(), key()) ::
          {:ok, number() | binary() | boolean() | nil, Sml.Units.code() | nil}
          | {:error, error()}
  def value(source, key) do
    with {:ok, entry} <- get(source, key) do
      {:ok, ListEntry.scaled_value(entry), entry.unit}
    end
  end

  @doc """
  Returns all readings as a map of `Sml.Obis` to `{scaled_value, unit}`.
  """
  @spec values(source()) ::
          {:ok, %{Obis.t() => {term(), Sml.Units.code() | nil}}} | {:error, error()}
  def values(source) do
    with {:ok, file} <- to_file(source) do
      values =
        for %ListEntry{obis: %Obis{} = obis} = entry <- list_entries(file),
            reduce: %{} do
          acc -> Map.put_new(acc, obis, {ListEntry.scaled_value(entry), entry.unit})
        end

      {:ok, values}
    end
  end

  defp payload(data, opts) do
    if Transport.framed?(data), do: Transport.unwrap(data, opts), else: {:ok, data}
  end

  defp to_file(%Sml.File{} = file), do: {:ok, file}
  defp to_file(data) when is_binary(data), do: decode(data)

  defp list_entries(%Sml.File{messages: messages}) do
    for %{body: %GetListResponse{val_list: entries}} <- messages, entry <- entries, do: entry
  end
end
