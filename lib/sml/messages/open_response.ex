defmodule Sml.Messages.OpenResponse do
  @moduledoc """
  Start of an SML file sent by the meter (`SML_PublicOpen.Res`) (tag `0x0101`).
  """

  defstruct [:codepage, :client_id, :req_file_id, :server_id, :ref_time, :sml_version]

  @type t :: %__MODULE__{}
end
