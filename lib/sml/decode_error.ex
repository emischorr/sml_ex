defmodule Sml.DecodeError do
  @moduledoc """
  Raised by `Sml.decode!/2` when a telegram cannot be decoded.
  """

  defexception [:reason]

  @impl true
  def message(%__MODULE__{reason: reason}),
    do: "could not decode SML telegram: #{inspect(reason)}"
end
