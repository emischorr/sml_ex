defmodule Sml.Messages.GetListRequest do
  @moduledoc """
  Requests a value list (`SML_GetList.Req`) (tag `0x0700`).
  """

  defstruct [:client_id, :server_id, :username, :password, :list_name]

  @type t :: %__MODULE__{}
end
