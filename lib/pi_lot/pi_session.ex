defmodule PiLot.PiSession do
  @moduledoc """
  Owns one `pi --mode rpc` process and broadcasts RPC events.
  """

  use GenServer

  alias PiLot.{PiTranscript, Projects, Sessions}

  defstruct [
    :project,
    :session_file,
    :port,
    :buffer,
    :request_seq,
    :transcript,
    :topic,
    :started?
  ]

  def start_link(opts) do
    project = Keyword.fetch!(opts, :project)
    session_file = Keyword.get(opts, :session_file)
    GenServer.start_link(__MODULE__, opts, name: via(project.id, session_file))
  end

  def ensure_started(project, session_file \\ nil) do
    with true <- is_pid(Process.whereis(PiLot.PiRegistry)),
         true <- is_pid(Process.whereis(PiLot.PiSupervisor)) do
      case Registry.lookup(PiLot.PiRegistry, registry_key(project.id, session_file)) do
        [{pid, _}] -> {:ok, pid}
        [] -> PiLot.PiSupervisor.start_session(project: project, session_file: session_file)
      end
    else
      _ -> {:error, :pi_supervision_not_started}
    end
  end

  def prompt(pid, message, streaming_behavior \\ nil),
    do: GenServer.call(pid, {:prompt, message, streaming_behavior})

  def abort(pid), do: GenServer.call(pid, :abort)
  def snapshot(pid), do: GenServer.call(pid, :snapshot)
  def extension_response(pid, response), do: GenServer.call(pid, {:extension_response, response})

  def topic(project_id, session_file),
    do:
      "pi_session:#{project_id}:#{Base.url_encode64(to_string(session_file || "new"), padding: false)}"

  @impl true
  def init(opts) do
    project = Keyword.fetch!(opts, :project)
    session_file = Keyword.get(opts, :session_file)
    topic = topic(project.id, session_file)

    state = %__MODULE__{
      project: project,
      session_file: session_file,
      buffer: "",
      request_seq: 0,
      transcript: PiTranscript.new(),
      topic: topic,
      started?: false
    }

    {:ok, state, {:continue, :start_port}}
  end

  @impl true
  def handle_continue(:start_port, state) do
    case open_port(state.project.path, state.session_file) do
      {:ok, port} ->
        state = %{state | port: port, started?: true}

        {:noreply,
         state |> send_command(%{type: "get_state"}) |> send_command(%{type: "get_messages"})}

      {:error, reason} ->
        transcript = %{state.transcript | error: "Failed to start pi: #{inspect(reason)}"}
        broadcast(state, {:snapshot, transcript})
        {:noreply, %{state | transcript: transcript}}
    end
  end

  @impl true
  def handle_call(:snapshot, _from, state), do: {:reply, state.transcript, state}

  def handle_call({:prompt, message, streaming_behavior}, _from, state) do
    command = %{type: "prompt", message: message}

    command =
      if streaming_behavior,
        do: Map.put(command, :streamingBehavior, streaming_behavior),
        else: command

    {:reply, :ok, send_command(state, command)}
  end

  def handle_call(:abort, _from, state), do: {:reply, :ok, send_command(state, %{type: "abort"})}

  def handle_call({:extension_response, response}, _from, state) do
    {:reply, :ok, send_raw(state, Map.put(response, :type, "extension_ui_response"))}
  end

  @impl true
  def handle_info({_port, {:data, data}}, state) do
    {lines, buffer} = split_jsonl(state.buffer <> data)
    state = Enum.reduce(lines, %{state | buffer: buffer}, &handle_line/2)
    {:noreply, state}
  end

  def handle_info({_port, {:exit_status, status}}, state) do
    transcript = %{state.transcript | streaming?: false, error: "pi exited with status #{status}"}
    broadcast(state, {:snapshot, transcript})
    {:noreply, %{state | transcript: transcript}}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp open_port(cwd, session_file) do
    pi_path = System.get_env("PI_WEBUI_PI_PATH") || "pi"
    args = ["--mode", "rpc", "--session-dir", Sessions.session_root()]
    args = if session_file, do: args ++ ["--session", session_file], else: args

    port =
      Port.open({:spawn_executable, System.find_executable(pi_path) || pi_path}, [
        :binary,
        :exit_status,
        :use_stdio,
        :stderr_to_stdout,
        {:args, args},
        {:cd, Projects.canonical(cwd)}
      ])

    {:ok, port}
  rescue
    error -> {:error, error}
  end

  defp send_command(state, command) do
    {id, state} = next_id(state)
    send_raw(state, Map.put(command, :id, id))
  end

  defp send_raw(%{port: nil} = state, _command), do: state

  defp send_raw(state, command) do
    Port.command(state.port, Jason.encode!(command) <> "\n")
    state
  end

  defp next_id(state) do
    seq = state.request_seq + 1
    {"req-#{seq}", %{state | request_seq: seq}}
  end

  defp split_jsonl(buffer) do
    parts = String.split(buffer, "\n")
    {complete, [last]} = Enum.split(parts, -1)
    {Enum.map(complete, &String.trim_trailing(&1, "\r")), last}
  end

  defp handle_line("", state), do: state

  defp handle_line(line, state) do
    case Jason.decode(line) do
      {:ok,
       %{
         "type" => "response",
         "command" => "get_messages",
         "success" => true,
         "data" => %{"messages" => messages}
       }} ->
        transcript = PiTranscript.from_messages(messages)

        transcript = %{
          transcript
          | state: state.transcript.state,
            streaming?: state.transcript.streaming?
        }

        broadcast(state, {:snapshot, transcript})
        %{state | transcript: transcript}

      {:ok, %{"type" => "response", "command" => "get_state", "success" => true, "data" => data}} ->
        transcript = %{state.transcript | state: data}
        broadcast(state, {:snapshot, transcript})
        %{state | transcript: transcript}

      {:ok, event} ->
        transcript = PiTranscript.apply_event(state.transcript, event)
        broadcast(state, {:event, event, transcript})
        %{state | transcript: transcript}

      {:error, _} ->
        transcript = %{state.transcript | error: line}
        broadcast(state, {:snapshot, transcript})
        %{state | transcript: transcript}
    end
  end

  defp broadcast(state, message), do: Phoenix.PubSub.broadcast(PiLot.PubSub, state.topic, message)

  defp via(project_id, session_file),
    do: {:via, Registry, {PiLot.PiRegistry, registry_key(project_id, session_file)}}

  defp registry_key(project_id, session_file), do: {project_id, session_file || :new}
end
