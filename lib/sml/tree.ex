defmodule Sml.Tree do
  @moduledoc """
  A node of a parameter tree (`SML_Tree`) as returned by
  `Sml.Messages.GetProcParameterResponse`.

  `value` is one of

    * `{:value, term}` - a plain value
    * `{:period_entry, Sml.PeriodEntry.t()}`
    * `{:time, Sml.Time.t()}`
    * `{:tupel_entry, list}` / `{:list_entry, list}` - raw parsed terms
    * `nil`
  """

  defstruct [:name, :value, children: []]

  @type t :: %__MODULE__{
          name: Sml.Obis.t() | binary() | nil,
          value: {atom(), term()} | nil,
          children: [t()]
        }
end
