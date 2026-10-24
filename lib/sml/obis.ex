defmodule Sml.Obis do
  @aliases [
    bezug: [{1, 0, 1, 8, 0}],
    import: [{1, 0, 1, 8, 0}],
    bezug_t1: [{1, 0, 1, 8, 1}],
    import_t1: [{1, 0, 1, 8, 1}],
    bezug_t2: [{1, 0, 1, 8, 2}],
    import_t2: [{1, 0, 1, 8, 2}],
    einspeisung: [{1, 0, 2, 8, 0}],
    export: [{1, 0, 2, 8, 0}],
    einspeisung_t1: [{1, 0, 2, 8, 1}],
    export_t1: [{1, 0, 2, 8, 1}],
    einspeisung_t2: [{1, 0, 2, 8, 2}],
    export_t2: [{1, 0, 2, 8, 2}],
    leistung: [{1, 0, 16, 7, 0}],
    power: [{1, 0, 16, 7, 0}],
    leistung_l1: [{1, 0, 36, 7, 0}],
    power_l1: [{1, 0, 36, 7, 0}],
    leistung_l2: [{1, 0, 56, 7, 0}],
    power_l2: [{1, 0, 56, 7, 0}],
    leistung_l3: [{1, 0, 76, 7, 0}],
    power_l3: [{1, 0, 76, 7, 0}],
    strom_l1: [{1, 0, 31, 7, 0}],
    current_l1: [{1, 0, 31, 7, 0}],
    strom_l2: [{1, 0, 51, 7, 0}],
    current_l2: [{1, 0, 51, 7, 0}],
    strom_l3: [{1, 0, 71, 7, 0}],
    current_l3: [{1, 0, 71, 7, 0}],
    spannung_l1: [{1, 0, 32, 7, 0}],
    voltage_l1: [{1, 0, 32, 7, 0}],
    spannung_l2: [{1, 0, 52, 7, 0}],
    voltage_l2: [{1, 0, 52, 7, 0}],
    spannung_l3: [{1, 0, 72, 7, 0}],
    voltage_l3: [{1, 0, 72, 7, 0}],
    frequenz: [{1, 0, 14, 7, 0}],
    frequency: [{1, 0, 14, 7, 0}],
    hersteller: [{129, 129, 199, 130, 3}, {1, 0, 96, 50, 1}],
    manufacturer: [{129, 129, 199, 130, 3}, {1, 0, 96, 50, 1}],
    server_id: [{1, 0, 0, 0, 9}, {1, 0, 96, 1, 0}]
  ]

  @moduledoc """
  OBIS codes (Object Identification System, IEC 62056-61).

  An OBIS code consists of six groups `A-B:C.D.E*F`, e.g. `1-0:1.8.0*255` for
  the total imported active energy. In SML it is sent as a 6 byte octet string.

  A field set to `nil` acts as a wildcard when matching, so `parse("1-0:1.8.0")`
  matches `1-0:1.8.0*255` as well as `1-0:1.8.0*0`, and `parse("1.8.0")`
  additionally ignores the A and B groups.

  ## Aliases

  `Sml.value/2`, `Sml.get/2` and `parse/1` accept these atoms (German and
  English names):

  #{Enum.map_join(@aliases, "\n", fn {name, codes} -> "  * `#{inspect(name)}` - " <> Enum.map_join(codes, " or ", fn {a, b, c, d, e} -> "`#{a}-#{b}:#{c}.#{d}.#{e}`" end) end)}
  """

  import Kernel, except: [match?: 2]

  defstruct [:a, :b, :c, :d, :e, :f]

  @type group :: 0..255 | nil
  @type t :: %__MODULE__{a: group, b: group, c: group, d: group, e: group, f: group}

  @doc """
  Creates an OBIS code from its 6 byte SML representation.

      iex> Sml.Obis.from_binary(<<1, 0, 1, 8, 0, 255>>)
      #Sml.Obis<1-0:1.8.0*255>
  """
  @spec from_binary(<<_::48>>) :: t()
  def from_binary(<<a, b, c, d, e, f>>), do: %__MODULE__{a: a, b: b, c: c, d: d, e: e, f: f}

  @doc """
  Parses an OBIS code from a string, a 6 byte binary or an alias atom.

  Returns a list of patterns for aliases that cover several codes, like
  `:server_id`.

      iex> Sml.Obis.parse("1-0:16.7.0*255")
      {:ok, %Sml.Obis{a: 1, b: 0, c: 16, d: 7, e: 0, f: 255}}

      iex> Sml.Obis.parse("1-0:1.8.0")
      {:ok, %Sml.Obis{a: 1, b: 0, c: 1, d: 8, e: 0, f: nil}}

      iex> Sml.Obis.parse("2.8.0")
      {:ok, %Sml.Obis{a: nil, b: nil, c: 2, d: 8, e: 0, f: nil}}

      iex> Sml.Obis.parse(:bezug)
      {:ok, %Sml.Obis{a: 1, b: 0, c: 1, d: 8, e: 0, f: nil}}

      iex> Sml.Obis.parse("nonsense")
      {:error, :invalid_obis}
  """
  @spec parse(String.t() | atom() | t()) :: {:ok, t() | [t()]} | {:error, term()}
  def parse(%__MODULE__{} = obis), do: {:ok, obis}

  def parse(name) when is_atom(name) do
    case Keyword.fetch(@aliases, name) do
      {:ok, [code]} -> {:ok, from_tuple(code)}
      {:ok, codes} -> {:ok, Enum.map(codes, &from_tuple/1)}
      :error -> {:error, {:unknown_alias, name}}
    end
  end

  def parse(string) when is_binary(string) do
    with [_ | _] = parts <-
           Regex.run(~r/^(?:(\d+)-(\d+):)?(\d+)\.(\d+)\.(\d+)(?:[*&.](\d+))?$/, string),
         [a, b, c, d, e, f] <- parts |> tl() |> pad(6) |> Enum.map(&group/1),
         true <- Enum.all?([a, b, c, d, e, f], &(is_nil(&1) or &1 in 0..255)) do
      {:ok, %__MODULE__{a: a, b: b, c: c, d: d, e: e, f: f}}
    else
      _ when byte_size(string) == 6 -> {:ok, from_binary(string)}
      _ -> {:error, :invalid_obis}
    end
  end

  def parse(_), do: {:error, :invalid_obis}

  @doc """
  Like `parse/1` but raises on invalid input.
  """
  @spec parse!(String.t() | atom() | t()) :: t() | [t()]
  def parse!(input) do
    case parse(input) do
      {:ok, obis} ->
        obis

      {:error, reason} ->
        raise ArgumentError, "invalid OBIS code #{inspect(input)}: #{inspect(reason)}"
    end
  end

  @doc """
  Returns all known alias atoms.
  """
  @spec aliases() :: [atom()]
  def aliases, do: Keyword.keys(@aliases)

  @doc """
  Returns `true` if `obis` matches `pattern`. `nil` fields in the pattern
  match anything.

      iex> Sml.Obis.match?(Sml.Obis.parse!("1-0:1.8.0"), Sml.Obis.parse!("1-0:1.8.0*255"))
      true

      iex> Sml.Obis.match?(Sml.Obis.parse!("1-0:1.8.0"), Sml.Obis.parse!("1-0:2.8.0*255"))
      false
  """
  @spec match?(t() | [t()], t()) :: boolean()
  def match?(patterns, obis) when is_list(patterns), do: Enum.any?(patterns, &match?(&1, obis))

  def match?(%__MODULE__{} = pattern, %__MODULE__{} = obis) do
    Enum.all?([:a, :b, :c, :d, :e, :f], fn key ->
      expected = Map.fetch!(pattern, key)
      is_nil(expected) or expected == Map.fetch!(obis, key)
    end)
  end

  def match?(_pattern, _obis), do: false

  @doc """
  Formats the OBIS code as a string, omitting wildcard groups.

      iex> Sml.Obis.to_string(Sml.Obis.from_binary(<<1, 0, 2, 8, 0, 255>>))
      "1-0:2.8.0*255"
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{a: a, b: b, c: c, d: d, e: e, f: f}) do
    prefix = if is_nil(a) or is_nil(b), do: "", else: "#{a}-#{b}:"
    suffix = if is_nil(f), do: "", else: "*#{f}"
    "#{prefix}#{c}.#{d}.#{e}#{suffix}"
  end

  defp from_tuple({a, b, c, d, e}), do: %__MODULE__{a: a, b: b, c: c, d: d, e: e}

  defp pad(list, size), do: list ++ List.duplicate("", size - length(list))

  defp group(""), do: nil
  defp group(digits), do: String.to_integer(digits)

  defimpl String.Chars do
    def to_string(obis), do: Sml.Obis.to_string(obis)
  end

  defimpl Inspect do
    def inspect(obis, _opts), do: "#Sml.Obis<#{Sml.Obis.to_string(obis)}>"
  end
end
