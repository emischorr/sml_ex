defmodule Sml.Units do
  @moduledoc """
  DLMS/COSEM unit codes (IEC 62056-62) as used in the `unit` field of SML
  list entries.

  The most common ones for electricity meters are `27` (W), `30` (Wh),
  `33` (A), `35` (V) and `44` (Hz).

      iex> Sml.Units.name(30)
      :wh

      iex> Sml.Units.symbol(27)
      "W"

      iex> Sml.Units.code(:wh)
      30
  """

  @units [
    {1, :year, "a"},
    {2, :month, "mo"},
    {3, :week, "wk"},
    {4, :day, "d"},
    {5, :hour, "h"},
    {6, :minute, "min"},
    {7, :second, "s"},
    {8, :degree, "°"},
    {9, :celsius, "°C"},
    {10, :currency, "currency"},
    {11, :m, "m"},
    {12, :m_per_s, "m/s"},
    {13, :m3, "m³"},
    {14, :m3_corrected, "m³"},
    {15, :m3_per_h, "m³/h"},
    {16, :m3_per_h_corrected, "m³/h"},
    {17, :m3_per_d, "m³/d"},
    {18, :m3_per_d_corrected, "m³/d"},
    {19, :l, "l"},
    {20, :kg, "kg"},
    {21, :n, "N"},
    {22, :nm, "Nm"},
    {23, :pa, "Pa"},
    {24, :bar, "bar"},
    {25, :j, "J"},
    {26, :j_per_h, "J/h"},
    {27, :w, "W"},
    {28, :va, "VA"},
    {29, :var, "var"},
    {30, :wh, "Wh"},
    {31, :vah, "VAh"},
    {32, :varh, "varh"},
    {33, :a, "A"},
    {34, :c, "C"},
    {35, :v, "V"},
    {36, :v_per_m, "V/m"},
    {37, :f, "F"},
    {38, :ohm, "Ω"},
    {39, :ohm_m2_per_m, "Ωm²/m"},
    {40, :wb, "Wb"},
    {41, :t, "T"},
    {42, :a_per_m, "A/m"},
    {43, :h, "H"},
    {44, :hz, "Hz"},
    {45, :per_wh, "1/(Wh)"},
    {46, :per_varh, "1/(varh)"},
    {47, :per_vah, "1/(VAh)"},
    {48, :v2h, "V²h"},
    {49, :a2h, "A²h"},
    {50, :kg_per_s, "kg/s"},
    {51, :s, "S"},
    {52, :k, "K"},
    {53, :per_v2h, "1/(V²h)"},
    {54, :per_a2h, "1/(A²h)"},
    {55, :per_m3, "1/m³"},
    {56, :percent, "%"},
    {57, :ah, "Ah"},
    {60, :wh_per_m3, "Wh/m³"},
    {61, :j_per_m3, "J/m³"},
    {62, :mol_percent, "mol%"},
    {63, :g_per_m3, "g/m³"},
    {64, :pa_s, "Pa s"},
    {254, :other, ""},
    {255, :count, ""}
  ]

  @type code :: 0..255

  @doc """
  Returns the unit name for a unit code, or `nil` if it is unknown.
  """
  @spec name(code() | nil) :: atom() | nil
  def name(code)

  for {code, name, _symbol} <- @units, do: def(name(unquote(code)), do: unquote(name))
  def name(_), do: nil

  @doc """
  Returns the unit symbol for a unit code, or `nil` if it is unknown.
  """
  @spec symbol(code() | nil) :: String.t() | nil
  def symbol(code)

  for {code, _name, symbol} <- @units, do: def(symbol(unquote(code)), do: unquote(symbol))
  def symbol(_), do: nil

  @doc """
  Returns the unit code for a unit name, or `nil` if it is unknown.
  """
  @spec code(atom()) :: code() | nil
  def code(name)

  for {code, name, _symbol} <- @units, do: def(code(unquote(name)), do: unquote(code))
  def code(_), do: nil
end
