defmodule PiLot.Sessions do
  @moduledoc """
  Reads pi JSONL session history for projects.
  """

  alias PiLot.Projects

  def session_dir do
    configured =
      Application.get_env(:pi_lot, :session_dir) || System.get_env("PI_WEBUI_SESSION_DIR")

    Path.expand(configured || "~/.pi/agent/sessions")
  end

  def list_sessions(project_path) when is_binary(project_path) do
    session_dir()
    |> Path.join("**/*.jsonl")
    |> Path.wildcard()
    |> Enum.map(&parse_session(&1, project_path))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&(&1.updated_at || &1.timestamp || ""), :desc)
  end

  def read_messages(file) when is_binary(file) do
    file
    |> File.stream!([], :line)
    |> Stream.map(&decode_line/1)
    |> Stream.reject(&is_nil/1)
    |> Stream.filter(&(&1["type"] == "message"))
    |> Enum.to_list()
  rescue
    _ -> []
  end

  def parse_session(file, project_path) do
    canonical_project = Path.expand(project_path)

    with {:ok, lines} <- read_sample(file),
         {:ok, header} <- decode_first_session(lines),
         true <- Path.expand(to_string(header["cwd"] || "")) == canonical_project do
      events = decode_events(lines)
      title = title_from(events) || first_user_message(events) || "Untitled session"
      timestamp = header["timestamp"] || timestamp_from_file(file)
      updated_at = latest_timestamp(events) || timestamp

      %{
        id: to_string(header["id"] || Path.basename(file, ".jsonl")),
        file: file,
        title: title,
        timestamp: timestamp,
        updated_at: updated_at,
        message_count: message_count(events),
        cwd: canonical_project,
        display_file: Projects.display_path(file)
      }
    else
      _ -> nil
    end
  end

  defp read_sample(file) do
    file
    |> File.stream!([], :line)
    |> Enum.take(500)
    |> then(&{:ok, &1})
  rescue
    _ -> {:error, :read_failed}
  end

  defp decode_first_session(lines) do
    lines
    |> Stream.map(&decode_line/1)
    |> Enum.find(fn
      %{"type" => "session"} -> true
      _ -> false
    end)
    |> case do
      nil -> {:error, :no_header}
      header -> {:ok, header}
    end
  end

  defp decode_events(lines) do
    lines
    |> Enum.map(&decode_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp decode_line(line) do
    line
    |> String.trim_trailing("\n")
    |> String.trim_trailing("\r")
    |> Jason.decode!()
  rescue
    _ -> nil
  end

  defp title_from(events) do
    events
    |> Enum.reverse()
    |> Enum.find_value(fn event ->
      cond do
        is_binary(event["name"]) -> event["name"]
        is_binary(event["sessionName"]) -> event["sessionName"]
        event["type"] == "session_info" and is_binary(event["title"]) -> event["title"]
        true -> nil
      end
    end)
    |> truncate(64)
  end

  defp first_user_message(events) do
    events
    |> Enum.find_value(fn event ->
      role = event["role"] || get_in(event, ["message", "role"])
      text = if role == "user", do: event_text(event)

      if human_prompt?(text), do: text
    end)
    |> truncate(64)
  end

  defp event_text(event) do
    message_content = get_in(event, ["message", "content"])

    cond do
      is_binary(event["text"]) -> event["text"]
      is_binary(event["content"]) -> event["content"]
      is_list(event["content"]) -> Enum.map_join(event["content"], " ", &part_text/1)
      is_binary(message_content) -> message_content
      is_list(message_content) -> Enum.map_join(message_content, " ", &part_text/1)
      true -> nil
    end
  end

  defp human_prompt?(text) when is_binary(text) do
    text = String.trim(text)
    text != "" and not String.starts_with?(text, ["<skill ", "<context ", "<project-context "])
  end

  defp human_prompt?(_), do: false

  defp part_text(%{"text" => text}) when is_binary(text), do: text
  defp part_text(text) when is_binary(text), do: text
  defp part_text(_), do: ""

  defp latest_timestamp(events) do
    events
    |> Enum.reverse()
    |> Enum.find_value(fn event ->
      event["timestamp"] || event["createdAt"] || event["updatedAt"]
    end)
  end

  defp message_count(events) do
    Enum.count(events, fn event ->
      event["role"] in ["user", "assistant"] or
        get_in(event, ["message", "role"]) in ["user", "assistant"]
    end)
  end

  defp timestamp_from_file(file) do
    case File.stat(file, time: :posix) do
      {:ok, stat} -> DateTime.from_unix!(stat.mtime) |> DateTime.to_iso8601()
      _ -> nil
    end
  end

  defp truncate(nil, _max), do: nil

  defp truncate(text, max) when is_binary(text) do
    text = String.trim(text)

    if String.length(text) > max do
      String.slice(text, 0, max) <> "…"
    else
      text
    end
  end
end
