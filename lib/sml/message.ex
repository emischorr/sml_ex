defmodule Sml.Message do
  @moduledoc """
  An SML message (`SML_Message`).

  `body` is one of the structs in `Sml.Messages`, or
  `{:unknown, tag, terms}` for message types this library does not know.
  """

  alias Sml.Messages

  defstruct [:transaction_id, :group_no, :abort_on_error, :body, :crc]

  @type body ::
          Messages.OpenRequest.t()
          | Messages.OpenResponse.t()
          | Messages.CloseRequest.t()
          | Messages.CloseResponse.t()
          | Messages.GetListRequest.t()
          | Messages.GetListResponse.t()
          | Messages.GetProcParameterResponse.t()
          | Messages.GetProfileListResponse.t()
          | Messages.AttentionResponse.t()
          | {:unknown, non_neg_integer(), Sml.Parser.term_t()}

  @type t :: %__MODULE__{
          transaction_id: binary(),
          group_no: non_neg_integer(),
          abort_on_error: non_neg_integer(),
          body: body(),
          crc: non_neg_integer()
        }
end
