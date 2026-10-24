defmodule Sml.Messages.CloseResponse do
  @moduledoc """
  End of an SML file sent by the meter (`SML_PublicClose.Res`) (tag `0x0201`).
  """

  defstruct [:global_signature]

  @type t :: %__MODULE__{}
end
