defmodule PiLot.Sessions do
  @moduledoc """
  Lists and summarizes pi JSONL session files.
  """

  alias PiLot.Projects

  defstruct [
    :id,
    :file,
    :title,
    :timestamp,
    :latest_timestamp,
    :message_count,
    :cwd,
    :meta
  ]

  def session_root do
    System.get_env("PI_WEBUI_SESSION_DIR") || Path.expand("~/.pi/agent/sessions")
  end

  def list_sessions(%Projects{} = project) do
    session_root()
    |> Path.join("**/*.jsonl")
    |> Path.wildcard()
    |> Task.async_stream(&parse_file/1, timeout: :infinity)
    |> Enum.flat_map(fn
      {:ok, {:ok, session}} -> [session]
      _ -> []
    end)
    |> Enum.filter(&same_cwd?(&1.cwd, project.path))
    |> Enum.sort_by(&(&1.latest_timestamp || &1.timestamp || ""), :desc)
  end

  def parse_file(file) do
    file
    |> File.stream!([], :line)
    |> Enum.reduce(%{file: file, message_count: 0}, &parse_line/2)
    |> build_session()
  rescue
    _ -> {:error, :invalid}
  end

  defp parse_line(line, acc) do
    line = String.trim_trailing(line, "\n") |> String.trim_trailing("\r")

    case Jason.decode(line) do
      {:ok, record} -> absorb_record(record, acc)
      _ -> acc
    end
  end

  defp absorb_record(%{"type" => "session"} = record, acc) do
    acc
    |> Map.put(:id, record["id"])
    |> Map.put(:cwd, record["cwd"])
    |> Map.put(:timestamp, record["timestamp"])
    |> Map.put(:latest_timestamp, record["timestamp"])
  end

  defp absorb_record(%{"type" => "session_info"} = record, acc) do
    acc
    |> maybe_put_title(record["name"] || record["sessionName"])
    |> touch(record)
  end

  defp absorb_record(%{"role" => role} = record, acc) when role in ["user", "assistant"] do
    acc = %{acc | message_count: Map.get(acc, :message_count, 0) + 1}
    text = message_text(record)

    acc
    |> maybe_put_first_user_title(role, text)
    |> touch(record)
  end

  defp absorb_record(record, acc), do: touch(acc, record)

  defp build_session(%{id: id, cwd: cwd, file: file} = acc)
       when is_binary(id) and is_binary(cwd) do
    timestamp = Map.get(acc, :timestamp)
    latest = Map.get(acc, :latest_timestamp) || timestamp
    count = Map.get(acc, :message_count, 0)

    {:ok,
     %__MODULE__{
       id: id,
       file: file,
       title: title(acc, file),
       timestamp: timestamp,
       latest_timestamp: latest,
       message_count: count,
       cwd: cwd,
       meta: meta(latest, count)
     }}
  end

  defp build_session(_), do: {:error, :missing_header}

  defp maybe_put_title(acc, title) when is_binary(title) and title != "",
    do: Map.put(acc, :title, title)

  defp maybe_put_title(acc, _), do: acc

  defp maybe_put_first_user_title(acc, "user", text) when is_binary(text) and text != "" do
    Map.put_new(acc, :first_user_title, String.slice(String.trim(text), 0, 80))
  end

  defp maybe_put_first_user_title(acc, _, _), do: acc

  defp touch(acc, record) do
    timestamp = record["timestamp"] || record["createdAt"] || record["updatedAt"]

    if is_binary(timestamp) do
      Map.put(acc, :latest_timestamp, timestamp)
    else
      acc
    end
  end

  defp message_text(record) do
    cond do
      is_binary(record["text"]) ->
        record["text"]

      is_binary(record["content"]) ->
        record["content"]

      is_list(record["content"]) ->
        record["content"] |> Enum.map(&content_text/1) |> Enum.join(" ")

      true ->
        ""
    end
  end

  defp content_text(%{"text" => text}) when is_binary(text), do: text
  defp content_text(%{"content" => text}) when is_binary(text), do: text
  defp content_text(_), do: ""

  defp title(acc, file),
    do: acc[:title] || acc[:first_user_title] || Path.basename(file, ".jsonl")

  defp meta(timestamp, count) do
    time =
      if timestamp,
        do: timestamp |> String.replace("T", " ") |> String.slice(0, 16),
        else: "Unknown"

    "#{time} · #{count} messages"
  end

  defp same_cwd?(cwd, project_path),
    do: Projects.canonical(cwd || "") == Projects.canonical(project_path)
end
