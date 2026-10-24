defmodule Sml.ListEntry do
  @moduledoc """
  One entry of the value list in a `Sml.Messages.GetListResponse`
  (`SML_ListEntry`), e.g. the meter reading for `1-0:1.8.0*255`.

  `value` is the raw value as sent by the meter. Use `scaled_value/1` to get
  the value with the scaler applied, and `Sml.Units` to interpret `unit`.
  """

  defstruct [:obis, :status, :val_time, :unit, :scaler, :value, :value_signature]

  @type t :: %__MODULE__{
          obis: Sml.Obis.t() | binary(),
          status: non_neg_integer() | nil,
          val_time: Sml.Time.t(),
          unit: Sml.Units.code() | nil,
          scaler: integer() | nil,
          value: integer() | binary() | boolean() | list() | nil,
          value_signature: binary() | nil
        }

  @doc """
  Returns `value * 10^scaler`.

  The result is an integer if the scaler is missing or not negative, and a
  float otherwise. Non-numeric values are returned unchanged.

      iex> Sml.ListEntry.scaled_value(%Sml.ListEntry{value: 123_456, scaler: -1})
      12345.6

      iex> Sml.ListEntry.scaled_value(%Sml.ListEntry{value: 42, scaler: 2})
      4200

      iex> Sml.ListEntry.scaled_value(%Sml.ListEntry{value: "EMH", scaler: nil})
      "EMH"
  """
  @spec scaled_value(t()) :: number() | binary() | boolean() | list() | nil
  def scaled_value(%__MODULE__{value: value, scaler: scaler}), do: scale(value, scaler)

  @doc false
  def scale(value, scaler) when is_integer(value) and is_integer(scaler) and scaler < 0,
    do: value / Integer.pow(10, -scaler)

  def scale(value, scaler) when is_integer(value) and is_integer(scaler),
    do: value * Integer.pow(10, scaler)

  def scale(value, _scaler), do: value

  @doc """
  Returns the unit name (e.g. `:wh`) of the entry, see `Sml.Units.name/1`.
  """
  @spec unit_name(t()) :: atom() | nil
  def unit_name(%__MODULE__{unit: unit}), do: Sml.Units.name(unit)
end
