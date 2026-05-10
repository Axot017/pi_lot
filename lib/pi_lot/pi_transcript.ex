defmodule PiLot.PiTranscript do
  @moduledoc """
  Small UI transcript reducer for pi RPC messages/events.
  """

  def new do
    %{
      items: [],
      streaming?: false,
      tools: %{},
      error: nil,
      state: %{},
      queue: nil,
      extension_request: nil
    }
  end

  def from_messages(messages) when is_list(messages) do
    Enum.reduce(messages, new(), fn message, transcript ->
      append_message(transcript, message)
    end)
  end

  def apply_event(transcript, %{"type" => "agent_start"}),
    do: %{transcript | streaming?: true, error: nil}

  def apply_event(transcript, %{"type" => "agent_end", "messages" => messages})
      when is_list(messages),
      do: %{from_messages(messages) | streaming?: false, state: transcript.state}

  def apply_event(transcript, %{"type" => "agent_end"}), do: %{transcript | streaming?: false}

  def apply_event(transcript, %{"type" => "queue_update"} = event),
    do: %{transcript | queue: event}

  def apply_event(transcript, %{"type" => "extension_ui_request"} = event),
    do: %{transcript | extension_request: event}

  def apply_event(transcript, %{"type" => "message_update", "message" => message}) do
    upsert_message(transcript, message)
  end

  def apply_event(transcript, %{"type" => type, "message" => message})
      when type in ["message_start", "message_end"] do
    upsert_message(transcript, message)
  end

  def apply_event(transcript, %{"type" => "turn_end", "message" => message}) do
    upsert_message(transcript, message)
  end

  def apply_event(transcript, %{"type" => "tool_execution_start", "toolCallId" => id} = event) do
    item = %{
      id: "tool-#{id}",
      role: :tool,
      label: event["toolName"] || "tool",
      time: time_now(),
      body: args_text(event["args"]),
      status: :running,
      kind: :tool,
      output: ""
    }

    put_item(%{transcript | tools: Map.put(transcript.tools, id, item.id)}, item)
  end

  def apply_event(transcript, %{"type" => "tool_execution_update", "toolCallId" => id} = event) do
    update_tool(transcript, id, %{output: result_text(event["partialResult"]), status: :running})
  end

  def apply_event(transcript, %{"type" => "tool_execution_end", "toolCallId" => id} = event) do
    status = if event["isError"], do: :error, else: :complete
    update_tool(transcript, id, %{output: result_text(event["result"]), status: status})
  end

  def apply_event(transcript, %{"type" => "response", "success" => false} = event) do
    %{transcript | error: event["error"] || "RPC command failed"}
  end

  def apply_event(transcript, _event), do: transcript

  def append_message(transcript, message), do: put_item(transcript, message_item(message))

  def upsert_message(transcript, message) do
    put_item(transcript, message_item(message))
  end

  defp put_item(transcript, item) do
    items = Enum.reject(transcript.items, &(&1.id == item.id)) ++ [item]
    %{transcript | items: items}
  end

  defp update_tool(transcript, tool_call_id, updates) do
    case Map.get(transcript.tools, tool_call_id) do
      nil ->
        transcript

      item_id ->
        items =
          Enum.map(transcript.items, fn item ->
            if item.id == item_id, do: Map.merge(item, updates), else: item
          end)

        %{transcript | items: items}
    end
  end

  defp message_item(message) do
    role = role(message["role"] || message[:role])

    %{
      id: message_id(message),
      role: role,
      label: label(role),
      time: message_time(message),
      body: message_text(message),
      kind: :text,
      output: nil,
      status: :complete
    }
  end

  defp message_id(message) do
    message["id"] || message[:id] || :erlang.phash2(message) |> Integer.to_string()
  end

  defp role("user"), do: :user
  defp role("assistant"), do: :assistant
  defp role("system"), do: :system
  defp role(_), do: :assistant

  defp label(:user), do: "You"
  defp label(:assistant), do: "pi"
  defp label(:system), do: "system"

  defp message_time(message) do
    (message["timestamp"] || message[:timestamp] || time_now())
    |> to_string()
    |> String.replace("T", " ")
    |> String.slice(11, 5)
  end

  defp message_text(message) do
    content = message["content"] || message[:content] || message["text"] || message[:text] || ""

    cond do
      is_binary(content) ->
        content

      is_list(content) ->
        content |> Enum.map(&content_text/1) |> Enum.reject(&(&1 == "")) |> Enum.join("\n")

      true ->
        inspect(content)
    end
  end

  defp content_text(%{"text" => text}) when is_binary(text), do: text
  defp content_text(%{"content" => text}) when is_binary(text), do: text
  defp content_text(%{"type" => type, "name" => name}), do: "#{type}: #{name}"

  defp content_text(other) when is_map(other),
    do: other |> Map.take(["type", "name", "input"]) |> inspect()

  defp content_text(_), do: ""

  defp args_text(args) when is_map(args), do: Jason.encode!(args)
  defp args_text(args), do: inspect(args)

  defp result_text(%{"content" => content}) when is_list(content),
    do: content |> Enum.map(&content_text/1) |> Enum.join("\n")

  defp result_text(%{"content" => text}) when is_binary(text), do: text
  defp result_text(nil), do: ""
  defp result_text(other), do: inspect(other)

  defp time_now, do: Calendar.strftime(DateTime.utc_now(), "%H:%M")
end
