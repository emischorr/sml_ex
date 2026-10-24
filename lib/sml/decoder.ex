defmodule Sml.Decoder do
  @moduledoc """
  Turns the generic terms produced by `Sml.Parser` into `Sml.Message` structs.

  Message bodies are recognized by their tag. Bodies with an unknown tag or an
  unexpected shape are returned as `{:unknown, tag, terms}` instead of failing
  the whole telegram.
  """

  alias Sml.{CRC16, ListEntry, Message, Obis, Parser, PeriodEntry, Time, Tree}
  alias Sml.Messages

  @type error ::
          {:parse_error, reason :: term(), offset :: non_neg_integer()} | :invalid_crc

  @doc """
  Decodes all messages in `payload` (the unwrapped content of a telegram).

  ## Options

    * `:crc` - checksum algorithm to verify: `:auto` (default, X-25 or
      Kermit), `:x25`, `:kermit`, or `false` to skip the check
  """
  @spec decode_messages(binary(), keyword()) :: {:ok, [Message.t()]} | {:error, error()}
  def decode_messages(payload, opts \\ []) when is_binary(payload) do
    decode_messages(payload, payload, opts, [])
  end

  defp decode_messages(data, payload, opts, acc) do
    if padding?(data) do
      {:ok, Enum.reverse(acc)}
    else
      case decode_message(data, opts) do
        {:ok, message, rest} ->
          decode_messages(rest, payload, opts, [message | acc])

        {:error, :invalid_crc, _rest} ->
          {:error, :invalid_crc}

        {:error, reason, rest} ->
          {:error, {:parse_error, reason, byte_size(payload) - byte_size(rest)}}
      end
    end
  end

  # Trailing zero bytes are padding, not messages.
  defp padding?(<<0, rest::binary>>), do: padding?(rest)
  defp padding?(<<>>), do: true
  defp padding?(_), do: false

  @doc """
  Decodes a single message from the beginning of `data`.
  """
  @spec decode_message(binary(), keyword()) ::
          {:ok, Message.t(), binary()} | {:error, term(), binary()}
  def decode_message(data, opts \\ []) do
    with {:ok, 6, after_header} <- message_header(data),
         {:ok, [transaction_id, group_no, abort_on_error, body], after_body} <-
           Parser.parse_many(after_header, 4),
         {:ok, crc, after_crc} <- Parser.parse(after_body),
         {:ok, :end_of_message, rest} <- end_of_message(after_crc),
         :ok <-
           verify_crc(binary_part(data, 0, byte_size(data) - byte_size(after_body)), crc, opts) do
      message = %Message{
        transaction_id: transaction_id,
        group_no: group_no,
        abort_on_error: abort_on_error,
        body: decode_body(body),
        crc: crc
      }

      {:ok, message, rest}
    else
      {:error, :invalid_crc} -> {:error, :invalid_crc, data}
      error -> error
    end
  end

  defp message_header(data) do
    case Parser.parse_list_header(data) do
      {:ok, 6, _rest} = ok -> ok
      {:ok, count, _rest} -> {:error, {:invalid_message_size, count}, data}
      error -> error
    end
  end

  defp end_of_message(data) do
    case Parser.parse(data) do
      {:ok, :end_of_message, _rest} = ok -> ok
      {:ok, _other, _rest} -> {:error, :missing_end_of_message, data}
      error -> error
    end
  end

  defp verify_crc(data, crc, opts) do
    case Keyword.get(opts, :crc, :auto) do
      false -> :ok
      _mode when not is_integer(crc) or crc > 0xFFFF -> {:error, :invalid_crc}
      mode -> if CRC16.valid?(data, <<crc::16>>, mode), do: :ok, else: {:error, :invalid_crc}
    end
  end

  @doc """
  Decodes a parsed message body (`[tag, body]`) into its struct.
  """
  @spec decode_body(Parser.term_t()) :: Message.body()
  def decode_body([tag, body]) when is_integer(tag) do
    case body(tag, body) do
      {:ok, decoded} -> decoded
      :error -> {:unknown, tag, body}
    end
  catch
    # thrown by nested decoders (list entries, trees) on unexpected shapes
    :invalid -> {:unknown, tag, body}
  end

  def decode_body(other), do: {:unknown, nil, other}

  defp body(0x0100, [codepage, client_id, req_file_id, server_id, username, password, version]) do
    {:ok,
     %Messages.OpenRequest{
       codepage: codepage,
       client_id: client_id,
       req_file_id: req_file_id,
       server_id: server_id,
       username: username,
       password: password,
       sml_version: version
     }}
  end

  defp body(0x0101, [codepage, client_id, req_file_id, server_id, ref_time, version]) do
    {:ok,
     %Messages.OpenResponse{
       codepage: codepage,
       client_id: client_id,
       req_file_id: req_file_id,
       server_id: server_id,
       ref_time: Time.decode(ref_time),
       sml_version: version
     }}
  end

  defp body(0x0200, [signature]), do: {:ok, %Messages.CloseRequest{global_signature: signature}}
  defp body(0x0201, [signature]), do: {:ok, %Messages.CloseResponse{global_signature: signature}}

  defp body(0x0700, [client_id, server_id, username, password, list_name]) do
    {:ok,
     %Messages.GetListRequest{
       client_id: client_id,
       server_id: server_id,
       username: username,
       password: password,
       list_name: obis(list_name)
     }}
  end

  defp body(0x0701, [client_id, server_id, list_name, sensor_time, val_list, signature, gw_time]) do
    {:ok,
     %Messages.GetListResponse{
       client_id: client_id,
       server_id: server_id,
       list_name: obis(list_name),
       act_sensor_time: Time.decode(sensor_time),
       val_list: Enum.map(List.wrap(val_list), &list_entry/1),
       list_signature: signature,
       act_gateway_time: Time.decode(gw_time)
     }}
  end

  defp body(0x0401, [
         server_id,
         act_time,
         reg_period,
         tree_path,
         val_time,
         status,
         period_list,
         rawdata,
         signature
       ]) do
    {:ok,
     %Messages.GetProfileListResponse{
       server_id: server_id,
       act_time: Time.decode(act_time),
       reg_period: reg_period,
       parameter_tree_path: tree_path(tree_path),
       val_time: Time.decode(val_time),
       status: status,
       period_list: Enum.map(List.wrap(period_list), &period_entry/1),
       rawdata: rawdata,
       period_signature: signature
     }}
  end

  defp body(0x0501, [server_id, tree_path, tree]) do
    {:ok,
     %Messages.GetProcParameterResponse{
       server_id: server_id,
       parameter_tree_path: tree_path(tree_path),
       parameter_tree: tree(tree)
     }}
  end

  defp body(0xFF01, [server_id, attention_no, message, details]) do
    {:ok,
     %Messages.AttentionResponse{
       server_id: server_id,
       attention_no: attention_no,
       attention_msg: message,
       attention_details: details && tree(details)
     }}
  end

  defp body(_tag, _body), do: :error

  defp list_entry([obj_name, status, val_time, unit, scaler, value, signature]) do
    %ListEntry{
      obis: obis(obj_name),
      status: status,
      val_time: Time.decode(val_time),
      unit: unit,
      scaler: scaler,
      value: value,
      value_signature: signature
    }
  end

  defp list_entry(_), do: throw(:invalid)

  defp period_entry([obj_name, unit, scaler, value, signature]) do
    %PeriodEntry{
      obis: obis(obj_name),
      unit: unit,
      scaler: scaler,
      value: value,
      value_signature: signature
    }
  end

  defp period_entry(_), do: throw(:invalid)

  defp tree([name, value, children]) do
    %Tree{
      name: obis(name),
      value: tree_value(value),
      children: Enum.map(List.wrap(children), &tree/1)
    }
  end

  defp tree(_), do: throw(:invalid)

  defp tree_value(nil), do: nil
  defp tree_value([1, value]), do: {:value, value}
  defp tree_value([2, entry]), do: {:period_entry, period_entry(entry)}
  defp tree_value([3, tupel]), do: {:tupel_entry, tupel}
  defp tree_value([4, time]), do: {:time, Time.decode(time)}
  defp tree_value([5, entry]), do: {:list_entry, entry}
  defp tree_value(other), do: {:unknown, other}

  defp tree_path(path), do: Enum.map(List.wrap(path), &obis/1)

  defp obis(<<_::binary-size(6)>> = code), do: Obis.from_binary(code)
  defp obis(other), do: other
end
