defmodule Sml.Messages.GetListResponse do
  @moduledoc """
  The current readings of a meter (`SML_GetList.Res`, tag `0x0701`).

  `val_list` contains one `Sml.ListEntry` per value, e.g. the meter reading
  and the current power.
  """

  defstruct [
    :client_id,
    :server_id,
    :list_name,
    :act_sensor_time,
    :list_signature,
    :act_gateway_time,
    val_list: []
  ]

  @type t :: %__MODULE__{
          client_id: binary() | nil,
          server_id: binary() | nil,
          list_name: Sml.Obis.t() | binary() | nil,
          act_sensor_time: Sml.Time.t(),
          val_list: [Sml.ListEntry.t()],
          list_signature: binary() | nil,
          act_gateway_time: Sml.Time.t()
        }
end
