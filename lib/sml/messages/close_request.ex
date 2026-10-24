defmodule Sml.Messages.CloseRequest do
  @moduledoc """
  Closes an SML session (`SML_PublicClose.Req`) (tag `0x0200`).
  """

  defstruct [:global_signature]

  @type t :: %__MODULE__{}
end
