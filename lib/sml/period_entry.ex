defmodule Sml.PeriodEntry do
  @moduledoc """
  A value in a load profile or parameter tree (`SML_PeriodEntry`).
  """

  defstruct [:obis, :unit, :scaler, :value, :value_signature]

  @type t :: %__MODULE__{
          obis: Sml.Obis.t() | binary(),
          unit: Sml.Units.code() | nil,
          scaler: integer() | nil,
          value: integer() | binary() | boolean() | list() | nil,
          value_signature: binary() | nil
        }

  @doc """
  Returns `value * 10^scaler`, see `Sml.ListEntry.scaled_value/1`.
  """
  @spec scaled_value(t()) :: number() | binary() | boolean() | list() | nil
  def scaled_value(%__MODULE__{value: value, scaler: scaler}),
    do: Sml.ListEntry.scale(value, scaler)
end
