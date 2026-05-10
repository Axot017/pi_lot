defmodule PiLot.PiTranscript do
  @moduledoc """
  Converts pi RPC events into chat items for UI.
  """

  def new, do: []

  def from_messages(messages) when is_list(messages) do
    messages
    |> Enum.flat_map(&message_to_items/1)
    |> Enum.with_index()
    |> Enum.map(fn {item, index} -> Map.put_new(item, :id, "msg-#{index}") end)
  end

  def apply_event(items, event) do
    case event["type"] do
      "message_start" ->
        append_message_start(items, event)

      "message_update" ->
        update_streaming(items, event)

      "message_end" ->
        finish_streaming(items, event)

      "tool_execution_start" ->
        append_tool(items, event, :running)

      "tool_execution_update" ->
        update_tool(items, event)

      "tool_execution_end" ->
        update_tool(items, event, :complete)

      "extension_error" ->
        append_system(items, "Extension error", event["message"] || inspect(event))

      _ ->
        items
    end
  end

  defp message_to_items(%{"role" => role} = message) do
    [
      %{
        id: unique_id(),
        role: role_atom(role),
        label: label(role),
        body: content_text(message),
        kind: :text
      }
    ]
  end

  defp message_to_items(%{"message" => %{"role" => role} = message}) do
    [
      %{
        id: unique_id(),
        role: role_atom(role),
        label: label(role),
        body: content_text(message),
        kind: :text
      }
    ]
  end

  defp message_to_items(_), do: []

  defp append_message_start(items, event) do
    role = event["role"] || get_in(event, ["message", "role"]) || "assistant"
    id = message_dom_id(event)

    item = %{
      id: id,
      role: role_atom(role),
      label: label(role),
      body: content_text(event["message"] || event),
      kind: :text,
      streaming: true
    }

    items ++ [item]
  end

  defp update_streaming(items, event) do
    id = message_dom_id(event)
    body = content_text(event["message"] || event)
    delta = get_in(event, ["assistantMessageEvent", "delta"])

    cond do
      Enum.any?(items, &(&1.id == id)) ->
        Enum.map(items, fn item ->
          if item.id == id do
            new_body = if body == "", do: item.body <> to_string(delta || ""), else: body
            %{item | body: new_body, streaming: true}
          else
            item
          end
        end)

      body != "" or is_binary(delta) ->
        items ++
          [
            %{
              id: id,
              role: :assistant,
              label: "pi",
              body: body <> to_string(delta || ""),
              kind: :text,
              streaming: true
            }
          ]

      true ->
        items
    end
  end

  defp finish_streaming(items, event) do
    id = message_dom_id(event)
    body = content_text(event["message"] || event)

    Enum.map(items, fn item ->
      if item.id == id do
        item
        |> Map.put(:streaming, false)
        |> then(fn item -> if body == "", do: item, else: %{item | body: body} end)
      else
        item
      end
    end)
  end

  defp append_tool(items, event, status) do
    id = to_string(event["toolCallId"] || event["id"] || unique_id())
    tool = event["toolName"] || event["tool"] || event["name"] || "tool"
    input = event["input"] || event["args"] || ""

    items ++
      [
        %{
          id: id,
          role: :assistant,
          label: "tool call",
          body: tool <> " " <> stringify(input),
          kind: :tool,
          status: status,
          tool_name: tool,
          output: ""
        }
      ]
  end

  defp update_tool(items, event, status \\ nil) do
    id = to_string(event["toolCallId"] || event["id"] || "")

    output =
      event["output"] || event["delta"] || result_text(event["partialResult"] || event["result"]) ||
        ""

    Enum.map(items, fn item ->
      if item.id == id do
        item
        |> Map.update(:output, stringify(output), &(&1 <> stringify(output)))
        |> then(fn item -> if status, do: Map.put(item, :status, status), else: item end)
      else
        item
      end
    end)
  end

  defp append_system(items, label, body) do
    items ++ [%{id: unique_id(), role: :system, label: label, body: to_string(body), kind: :text}]
  end

  defp content_text(message) do
    cond do
      is_binary(message["text"]) ->
        message["text"]

      is_binary(message["content"]) ->
        message["content"]

      is_list(message["content"]) ->
        Enum.map_join(message["content"], "", &content_part/1)

      is_binary(get_in(message, ["message", "content"])) ->
        get_in(message, ["message", "content"])

      true ->
        ""
    end
  end

  defp content_part(%{"type" => "thinking", "thinking" => _text}), do: ""
  defp content_part(%{"type" => "toolCall"}), do: ""
  defp content_part(%{"text" => text}) when is_binary(text), do: text
  defp content_part(%{"type" => "text", "content" => text}) when is_binary(text), do: text
  defp content_part(text) when is_binary(text), do: text
  defp content_part(_), do: ""

  defp result_text(%{"content" => content}) when is_list(content),
    do: Enum.map_join(content, "", &content_part/1)

  defp result_text(%{"content" => content}) when is_binary(content), do: content
  defp result_text(text) when is_binary(text), do: text
  defp result_text(_), do: nil

  defp message_dom_id(event) do
    message = event["message"] || event

    raw_id =
      message["id"] || message["entryId"] || message["timestamp"] || event["messageId"] ||
        event["id"]

    "message-#{raw_id || "current-assistant"}"
  end

  defp role_atom("user"), do: :user
  defp role_atom("assistant"), do: :assistant
  defp role_atom(_), do: :system

  defp label("user"), do: "You"
  defp label("assistant"), do: "pi"
  defp label(_), do: "system"

  defp stringify(value) when is_binary(value), do: value
  defp stringify(value), do: inspect(value, pretty: true, limit: 50)

  defp unique_id, do: System.unique_integer([:positive]) |> Integer.to_string()
end
