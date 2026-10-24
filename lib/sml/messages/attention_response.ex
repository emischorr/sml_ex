defmodule Sml.Messages.AttentionResponse do
  @moduledoc """
  Error or status notification (`SML_Attention.Res`) (tag `0xFF01`).
  """

  defstruct [:server_id, :attention_no, :attention_msg, :attention_details]

  @type t :: %__MODULE__{}
end
