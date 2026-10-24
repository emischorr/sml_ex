defmodule Sml.File do
  @moduledoc """
  A decoded SML file: the messages contained in one telegram.

  A typical telegram from a meter contains an `Sml.Messages.OpenResponse`, a
  `Sml.Messages.GetListResponse` with the current readings and an
  `Sml.Messages.CloseResponse`.
  """

  defstruct messages: []

  @type t :: %__MODULE__{messages: [Sml.Message.t()]}

  @doc """
  Returns the bodies of all messages.
  """
  @spec bodies(t()) :: [Sml.Message.body()]
  def bodies(%__MODULE__{messages: messages}), do: Enum.map(messages, & &1.body)
end
