defmodule Sml.Messages.GetProcParameterResponse do
  @moduledoc """
  Parameter values (`SML_GetProcParameter.Res`, tag `0x0501`).

  `parameter_tree` is an `Sml.Tree`.
  """

  defstruct [:server_id, :parameter_tree_path, :parameter_tree]

  @type t :: %__MODULE__{}
end
