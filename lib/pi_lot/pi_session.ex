defmodule PiLot.PiSession do
  @moduledoc """
  GenServer wrapper for `pi --mode rpc` JSONL protocol.
  """

  use GenServer

  alias PiLot.{PiTranscript, Sessions}

  defstruct [
    :project,
    :session_file,
    :port,
    :buffer,
    :topic,
    request_id: 0,
    pending: %{},
    transcript: [],
    streaming?: false,
    state: %{},
    queue: []
  ]

  def start_link(%{project: project, session_file: session_file} = args) do
    GenServer.start_link(__MODULE__, args, name: via(project.id, session_file))
  end

  def via(project_id, session_file) do
    {:via, Registry, {PiLot.PiSessionRegistry, {project_id, session_file || :new}}}
  end

  def topic(project_id, session_file), do: "pi_session:#{project_id}:#{session_file || "new"}"

  def send_prompt(pid, prompt), do: GenServer.call(pid, {:prompt, prompt})
  def abort(pid), do: GenServer.call(pid, {:command, "abort", %{}})
  def get_snapshot(pid), do: GenServer.call(pid, :snapshot)

  @impl true
  def init(%{project: project, session_file: session_file}) do
    Process.flag(:trap_exit, true)

    state = %__MODULE__{
      project: project,
      session_file: session_file,
      buffer: "",
      topic: topic(project.id, session_file)
    }

    case open_port(project, session_file) do
      {:ok, port} ->
        state = %{state | port: port}
        {:ok, state, {:continue, :bootstrap}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:bootstrap, state) do
    {:noreply,
     state
     |> send_command("get_state", %{})
     |> send_command("get_messages", %{})}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, snapshot(state), state}
  end

  def handle_call({:prompt, prompt}, _from, state) do
    params =
      if state.streaming? do
        %{message: prompt, streamingBehavior: "followUp"}
      else
        %{message: prompt}
      end

    {:reply, :ok, send_command(state, "prompt", params)}
  end

  def handle_call({:command, command, params}, _from, state) do
    {:reply, :ok, send_command(state, command, params)}
  end

  @impl true
  def handle_info({_port, {:data, data}}, state) do
    {lines, buffer} = split_jsonl(state.buffer <> data)

    state =
      lines
      |> Enum.reduce(%{state | buffer: buffer}, fn line, acc -> handle_line(line, acc) end)

    broadcast(state)
    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, status}}, state) do
    state = put_in(state.state[:exit_status], status)
    Phoenix.PubSub.broadcast(PiLot.PubSub, state.topic, {:pi_exit, status})
    {:noreply, state}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp open_port(project, session_file) do
    pi_path = Application.get_env(:pi_lot, :pi_path) || System.get_env("PI_WEBUI_PI_PATH") || "pi"

    args = ["--mode", "rpc", "--session-dir", Sessions.session_dir()]
    args = if session_file, do: args ++ ["--session", session_file], else: args

    port =
      Port.open({:spawn_executable, System.find_executable(pi_path) || pi_path}, [
        :binary,
        :exit_status,
        :use_stdio,
        :stderr_to_stdout,
        {:args, args},
        {:cd, project.path}
      ])

    {:ok, port}
  rescue
    error -> {:error, error}
  end

  defp send_command(state, command, params) do
    id = state.request_id + 1
    payload = Map.merge(params, %{id: id, type: command})
    Port.command(state.port, Jason.encode!(payload) <> "\n")
    %{state | request_id: id}
  end

  defp split_jsonl(data) do
    parts = String.split(data, "\n")
    {complete, [buffer]} = Enum.split(parts, -1)
    lines = Enum.map(complete, &String.trim_trailing(&1, "\r")) |> Enum.reject(&(&1 == ""))
    {lines, buffer}
  end

  defp handle_line(line, state) do
    case Jason.decode(line) do
      {:ok, %{"type" => "response", "success" => false} = response} ->
        append_error(state, response["error"] || "RPC command failed")

      {:ok, %{"type" => "response", "command" => "get_state", "data" => data}} ->
        %{state | state: Map.merge(state.state, atomize_known(data))}

      {:ok, %{"type" => "response", "command" => "prompt", "success" => true}} ->
        state

      {:ok,
       %{"type" => "response", "command" => "get_messages", "data" => %{"messages" => messages}}}
      when is_list(messages) ->
        %{state | transcript: PiTranscript.from_messages(messages)}

      {:ok, %{"type" => "queue_update"} = event} ->
        queue = (event["steering"] || []) ++ (event["followUp"] || [])
        %{state | queue: queue}

      {:ok, %{"type" => type} = event} when type in ["agent_start", "turn_start"] ->
        %{state | streaming?: true, transcript: PiTranscript.apply_event(state.transcript, event)}

      {:ok, %{"type" => type} = event} when type in ["agent_end", "turn_end"] ->
        %{
          state
          | streaming?: false,
            transcript: PiTranscript.apply_event(state.transcript, event)
        }

      {:ok, event} ->
        %{state | transcript: PiTranscript.apply_event(state.transcript, event)}

      {:error, _} ->
        update_in(
          state.transcript,
          &(&1 ++
              [
                %{
                  id: "error-#{System.unique_integer([:positive])}",
                  role: :system,
                  label: "parse error",
                  body: line,
                  kind: :text
                }
              ])
        )
    end
  end

  defp atomize_known(map) when is_map(map) do
    for {key, value} <- map, into: %{} do
      {String.to_atom(key), value}
    end
  end

  defp append_error(state, message) do
    update_in(state.transcript, fn transcript ->
      transcript ++
        [
          %{
            id: "rpc-error-#{System.unique_integer([:positive])}",
            role: :system,
            label: "RPC error",
            body: to_string(message),
            kind: :text
          }
        ]
    end)
  end

  defp snapshot(state) do
    %{
      project: state.project,
      session_file: state.session_file,
      transcript: state.transcript,
      streaming?: state.streaming?,
      state: state.state,
      queue: state.queue
    }
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(PiLot.PubSub, state.topic, {:pi_snapshot, snapshot(state)})
  end
end
