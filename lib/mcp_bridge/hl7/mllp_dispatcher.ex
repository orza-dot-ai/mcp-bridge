defmodule MCPBridge.HL7.MLLPDispatcher do
  @moduledoc """
  MCP Bridge dispatcher handles incoming HL7 messages and routes them to the appropriate
  handlers within the application. It implements the MLLP.Dispatcher behaviour to integrate
  with the MLLP protocol.
  """
  require Logger
  @behaviour MLLP.Dispatcher

  @spec dispatch(:mllp_hl7 | :mllp_unknown, binary(), MLLP.FramingContext.t()) ::
          {:ok, MLLP.FramingContext.t()}
  def dispatch(:mllp_unknown, _, state) do
    Logger.warning("Received unknown message type")
    msg = MLLP.Envelope.wrap_message("Unknown message type received")
    {:ok, %{state | reply_buffer: msg}}
  end

  def dispatch(:mllp_hl7, message, state) when is_binary(message) do
    Logger.info("McpBridge.Dispatcher received HL7 message: #{inspect(message)}")

    # Here you would normally process the message or route it to the appropriate handler
    # For now, we'll just acknowledge receipt similar to the EchoDispatcher

    {:ok, %{state | reply_buffer: generate_reply(message)}}
  end

  defp generate_reply(message) do
    {parsed_message, type} = parse_hl7(message)

    MCPBridge.Rpa.send_message(parsed_message)
    parsed_message
    |> MLLP.Ack.get_ack_for_message(type, "Message received by MCP Bridge")
    |> to_string()
    |> MLLP.Envelope.wrap_message()
  end

  defp parse_hl7(message) do
    case HL7.Message.new(message) do
      %HL7.InvalidMessage{} = msg ->
        Logger.error("Received invalid HL7 message")
        {msg, :application_reject}

      %HL7.Message{} = msg ->
        Logger.info("Successfully parsed HL7 message")
        {msg, :application_accept}
    end
  end
end
