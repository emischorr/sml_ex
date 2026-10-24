defmodule Sml.Messages.OpenRequest do
  @moduledoc """
  Opens an SML session (`SML_PublicOpen.Req`) (tag `0x0100`).
  """

  defstruct [:codepage, :client_id, :req_file_id, :server_id, :username, :password, :sml_version]

  @type t :: %__MODULE__{}
end
