defmodule Sml.Messages.GetProfileListResponse do
  @moduledoc """
  Load profile values (`SML_GetProfileList.Res`, tag `0x0401`).

  `period_list` contains `Sml.PeriodEntry` structs.
  """

  defstruct [
    :server_id,
    :act_time,
    :reg_period,
    :parameter_tree_path,
    :val_time,
    :status,
    :period_list,
    :rawdata,
    :period_signature
  ]

  @type t :: %__MODULE__{}
end
