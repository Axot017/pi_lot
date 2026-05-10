defmodule PiLotWeb.HomeLive do
  use PiLotWeb, :live_view

  alias PiLot.{PiSupervisor, PiSession, PiTranscript, Projects, Sessions}

  @impl true
  def mount(_params, _session, socket) do
    projects = Projects.list_projects()
    active_project = List.first(projects)

    socket =
      socket
      |> assign(:projects, projects)
      |> assign(:active_project, active_project)
      |> assign(:sessions, sessions_for(active_project))
      |> assign(:active_session, nil)
      |> assign(:session_pid, nil)
      |> assign(:messages, [])
      |> assign(:streaming?, false)
      |> assign(:queue, [])
      |> assign(:agent_state, %{})
      |> assign(:prompt_form, to_form(%{"prompt" => ""}))
      |> maybe_start_session(active_project, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_project", %{"id" => id}, socket) do
    project = Projects.get_project(id)

    socket =
      socket
      |> assign(:active_project, project)
      |> assign(:sessions, sessions_for(project))
      |> assign(:active_session, nil)
      |> assign(:messages, [])
      |> maybe_start_session(project, nil)

    {:noreply, socket}
  end

  def handle_event("select_session", %{"id" => id}, socket) do
    session = Enum.find(socket.assigns.sessions, &(&1.id == id))

    socket =
      if session do
        history = session.file |> Sessions.read_messages() |> PiTranscript.from_messages()

        socket
        |> assign(:active_session, session)
        |> assign(:messages, history)
        |> maybe_start_session(socket.assigns.active_project, session.file)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("new_session", _params, socket) do
    socket =
      socket
      |> assign(:active_session, nil)
      |> assign(:messages, [])
      |> maybe_start_session(socket.assigns.active_project, nil)

    {:noreply, socket}
  end

  def handle_event("send_prompt", %{"prompt" => prompt}, socket) do
    prompt = String.trim(prompt)

    if prompt != "" and socket.assigns.session_pid do
      :ok = PiSession.send_prompt(socket.assigns.session_pid, prompt)
    end

    {:noreply, assign(socket, :prompt_form, to_form(%{"prompt" => ""}))}
  end

  def handle_event("abort", _params, socket) do
    if socket.assigns.session_pid, do: :ok = PiSession.abort(socket.assigns.session_pid)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:pi_snapshot, snapshot}, socket) do
    {:noreply,
     assign(socket,
       messages: snapshot.transcript,
       streaming?: snapshot.streaming?,
       queue: snapshot.queue,
       agent_state: snapshot.state
     )}
  end

  def handle_info({:pi_exit, status}, socket) do
    message = %{
      id: "exit-#{status}",
      role: :system,
      label: "pi exited",
      body: "Exit status #{status}",
      kind: :text
    }

    {:noreply, update(socket, :messages, &(&1 ++ [message]))}
  end

  defp maybe_start_session(socket, nil, _session_file), do: socket

  defp maybe_start_session(socket, project, session_file) do
    topic = PiSession.topic(project.id, session_file)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(PiLot.PubSub, topic)
    end

    case PiSupervisor.start_session(project, session_file) do
      {:ok, pid} ->
        snapshot = PiSession.get_snapshot(pid)

        messages =
          if snapshot.transcript == [], do: socket.assigns.messages, else: snapshot.transcript

        assign(socket,
          session_pid: pid,
          messages: messages,
          streaming?: snapshot.streaming?,
          queue: snapshot.queue,
          agent_state: snapshot.state
        )

      {:error, reason} ->
        assign(socket,
          session_pid: nil,
          messages: [
            %{
              id: "start-error",
              role: :system,
              label: "pi start failed",
              body: inspect(reason),
              kind: :text
            }
          ]
        )
    end
  end

  defp sessions_for(nil), do: []
  defp sessions_for(project), do: Sessions.list_sessions(project.path)

  defp session_meta(session) do
    count = session.message_count || 0
    updated = session.updated_at || session.timestamp || "unknown"
    "#{count} messages · #{updated}"
  end

  defp active_session_file(nil), do: nil
  defp active_session_file(session), do: session.file

  defp projects_root_label do
    case Projects.root() do
      {:ok, root} -> Projects.display_path(root)
      {:error, _} -> "missing projects root"
    end
  end

  defp model_label(%{name: name}) when is_binary(name), do: name
  defp model_label(%{"name" => name}) when is_binary(name), do: name
  defp model_label(%{id: id}) when is_binary(id), do: id
  defp model_label(%{"id" => id}) when is_binary(id), do: id
  defp model_label(model) when is_binary(model), do: model
  defp model_label(_model), do: "unknown"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="h-dvh overflow-hidden bg-[oklch(13%_0.018_286)] text-[oklch(92%_0.012_286)] selection:bg-violet-400/30 selection:text-violet-50">
        <div class="relative mx-auto flex h-dvh min-h-0 w-full max-w-[1800px] flex-col overflow-hidden xl:flex-row">
          <details class="group shrink-0 border-b border-[oklch(28%_0.024_286)] bg-[oklch(16%_0.018_286)] open:fixed open:inset-0 open:z-50 open:flex open:h-dvh open:flex-col open:border-b-0 xl:hidden">
            <summary class="flex cursor-pointer list-none items-center justify-between gap-3 px-4 py-3 text-sm font-medium text-[oklch(88%_0.014_286)] transition hover:bg-[oklch(20%_0.02_286)] focus:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-violet-300 [&::-webkit-details-marker]:hidden">
              <span class="flex items-center gap-2">
                <.icon name="hero-folder" class="size-4 text-violet-200" /> Projects and sessions
              </span>
              <.icon
                name="hero-chevron-down"
                class="size-4 text-[oklch(62%_0.018_286)] transition group-open:rotate-180"
              />
            </summary>
            <div class="hidden min-h-0 flex-1 overflow-y-auto border-t border-[oklch(28%_0.024_286)] group-open:block">
              <.sidebar
                projects={@projects}
                active_project={@active_project}
                sessions={@sessions}
                active_session={@active_session}
              />
            </div>
          </details>

          <aside class="hidden shrink-0 overflow-y-auto border-r border-[oklch(28%_0.024_286)] bg-[oklch(16%_0.018_286)]/92 backdrop-blur-xl xl:block xl:min-h-0 xl:w-[22rem]">
            <.sidebar
              projects={@projects}
              active_project={@active_project}
              sessions={@sessions}
              active_session={@active_session}
            />
          </aside>

          <main id="main-content" class="flex min-h-0 flex-1 flex-col overflow-hidden">
            <header class="border-b border-[oklch(28%_0.024_286)] bg-[oklch(15%_0.017_286)]/86 px-4 py-4 backdrop-blur-xl sm:px-6">
              <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
                <div class="min-w-0">
                  <div class="flex flex-wrap items-center gap-2 text-xs text-[oklch(68%_0.02_286)]">
                    <span>PiLot</span><span class="text-[oklch(45%_0.02_286)]">/</span>
                    <span>{if @active_project, do: @active_project.name, else: "No project"}</span>
                    <span
                      :if={@streaming?}
                      class="rounded-full border border-violet-300/16 bg-[oklch(19%_0.026_286)] px-2 py-0.5 font-medium text-violet-200 shadow-[0_0_16px_oklch(62%_0.22_286_/_0.12)]"
                    >
                      streaming
                    </span>
                  </div>
                  <h1 class="mt-1 truncate text-xl font-semibold tracking-tight text-[oklch(96%_0.01_286)]">
                    {if @active_session, do: @active_session.title, else: "New session"}
                  </h1>
                  <p class="mt-1 truncate font-mono text-xs text-[oklch(62%_0.018_286)]">
                    {if @active_project,
                      do: @active_project.display_path,
                      else: "Set PI_WEBUI_PROJECTS_DIR"}
                  </p>
                </div>

                <div class="grid grid-cols-2 gap-2 text-xs">
                  <.status_pill label="Model" value={model_label(@agent_state[:model])} />
                  <.status_pill label="Queue" value={to_string(length(@queue))} />
                </div>
              </div>
            </header>

            <section aria-label="Chat transcript" class="flex min-h-0 flex-1 flex-col overflow-hidden">
              <div id="chat-scroll" class="flex-1 space-y-5 overflow-y-auto px-4 py-5 sm:px-6 lg:px-8">
                <div
                  :if={@active_project == nil}
                  class="rounded-2xl border border-amber-300/20 bg-amber-300/8 p-4 text-sm text-amber-100"
                >
                  No projects found. Set <code>PI_WEBUI_PROJECTS_DIR</code>
                  to directory containing project folders.
                </div>

                <div
                  :if={@messages == [] and @active_project}
                  class="rounded-2xl border border-[oklch(28%_0.024_286)] bg-[oklch(18%_0.018_286)] p-6 text-center text-sm text-[oklch(70%_0.018_286)]"
                >
                  Session ready. Send prompt to pi.
                </div>

                <article
                  :for={message <- @messages}
                  id={message.id}
                  class={["group flex gap-3", message.role == :user && "justify-end"]}
                >
                  <div
                    :if={message.role != :user}
                    class="mt-1 grid size-8 shrink-0 place-items-center rounded-xl bg-[oklch(23%_0.024_286)] text-xs font-bold text-violet-200"
                  >
                    π
                  </div>
                  <div class={[
                    "max-w-[75ch] rounded-2xl border px-4 py-3 shadow-[0_18px_60px_oklch(8%_0.02_286_/_0.22)]",
                    message.role == :user &&
                      "border-violet-300/22 bg-[oklch(22%_0.04_286)] text-violet-50",
                    message.role == :assistant &&
                      "border-[oklch(29%_0.025_286)] bg-[oklch(18%_0.018_286)]",
                    message.role == :system && "border-amber-300/18 bg-amber-300/8"
                  ]}>
                    <div class="flex items-center justify-between gap-3">
                      <p class="text-xs font-semibold uppercase tracking-[0.12em] text-[oklch(65%_0.035_286)]">
                        {message.label}
                      </p>
                      <p :if={Map.get(message, :streaming)} class="text-xs text-violet-200">
                        streaming
                      </p>
                    </div>
                    <p class="mt-2 whitespace-pre-wrap text-sm leading-6 text-[oklch(86%_0.014_286)]">
                      {message.body}
                    </p>
                    <pre
                      :if={message.kind == :tool}
                      class="mt-3 overflow-x-auto rounded-xl border border-[oklch(30%_0.024_286)] bg-[oklch(14%_0.018_286)] p-3 text-xs leading-5 text-[oklch(74%_0.018_286)]"
                    ><code>{Map.get(message, :output, "")}</code></pre>
                  </div>
                </article>
              </div>

              <div class="shrink-0 border-t border-[oklch(28%_0.024_286)] bg-[oklch(15%_0.017_286)] p-4 sm:p-5">
                <.form
                  for={@prompt_form}
                  id="prompt-form"
                  phx-submit="send_prompt"
                  class="rounded-2xl border border-[oklch(31%_0.026_286)] bg-[oklch(18%_0.018_286)] shadow-[0_18px_80px_oklch(8%_0.02_286_/_0.28)] focus-within:border-violet-300/60 focus-within:ring-2 focus-within:ring-violet-300/20"
                >
                  <label for="prompt" class="sr-only">Message pi</label>
                  <textarea
                    id="prompt"
                    name="prompt"
                    rows="4"
                    class="min-h-28 w-full resize-none rounded-t-2xl bg-transparent px-4 py-3 text-sm leading-6 text-[oklch(92%_0.012_286)] placeholder:text-[oklch(55%_0.018_286)] focus:outline-none"
                    placeholder="Ask pi to inspect, edit, test, or explain this project..."
                  ></textarea>
                  <div class="flex flex-col gap-3 border-t border-[oklch(28%_0.024_286)] px-3 py-3 sm:flex-row sm:items-center sm:justify-between">
                    <div class="flex flex-wrap items-center gap-2 text-xs text-[oklch(66%_0.018_286)]">
                      <span class="rounded-full bg-[oklch(23%_0.02_286)] px-2.5 py-1">RPC mode</span>
                      <span
                        :if={@streaming?}
                        class="rounded-full bg-violet-400/12 px-2.5 py-1 text-violet-200"
                      >
                        agent running
                      </span>
                    </div>
                    <div class="flex items-center gap-2">
                      <button
                        type="button"
                        phx-click="abort"
                        class="rounded-xl border border-[oklch(32%_0.026_286)] px-3 py-2 text-sm font-medium text-[oklch(82%_0.015_286)] transition hover:bg-[oklch(23%_0.02_286)] focus:outline-none focus-visible:ring-2 focus-visible:ring-violet-300"
                      >
                        Abort
                      </button>
                      <button
                        type="submit"
                        disabled={@active_project == nil}
                        class="rounded-xl border border-violet-300/28 bg-[oklch(20%_0.034_286)] px-4 py-2 text-sm font-semibold text-violet-50 shadow-[0_0_20px_oklch(62%_0.22_286_/_0.18)] transition hover:border-violet-200/50 hover:bg-[oklch(22%_0.044_286)] disabled:cursor-not-allowed disabled:opacity-45 focus:outline-none focus-visible:ring-2 focus-visible:ring-violet-200"
                      >
                        Send prompt
                      </button>
                    </div>
                  </div>
                </.form>
              </div>
            </section>
          </main>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :projects, :list, required: true
  attr :active_project, :map, default: nil
  attr :sessions, :list, required: true
  attr :active_session, :map, default: nil

  defp sidebar(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-3 border-b border-[oklch(28%_0.024_286)] px-4 py-4">
      <div class="flex items-center gap-3">
        <div class="grid size-9 place-items-center rounded-xl border border-violet-300/24 bg-[oklch(19%_0.028_286)] text-sm font-black text-violet-50 shadow-[0_0_22px_oklch(62%_0.22_286_/_0.28)]">
          π
        </div>
        <div>
          <p class="text-sm font-semibold tracking-tight">PiLot</p>
          <p class="text-xs text-[oklch(69%_0.018_286)]">Local agent cockpit</p>
        </div>
      </div>
      <button
        phx-click="new_session"
        class="rounded-lg border border-violet-300/18 bg-[oklch(18%_0.022_286)] px-2.5 py-1.5 text-xs font-medium text-[oklch(84%_0.024_286)] transition hover:border-violet-400/60 hover:bg-violet-400/10 focus:outline-none focus-visible:ring-2 focus-visible:ring-violet-300"
      >
        New
      </button>
    </div>

    <div class="space-y-5 px-3 py-4">
      <div class="rounded-2xl border border-[oklch(28%_0.024_286)] bg-[oklch(18%_0.018_286)]/80 p-3">
        <p class="text-xs font-medium uppercase tracking-[0.14em] text-[oklch(68%_0.035_286)]">
          Projects root
        </p>
        <p class="mt-2 truncate font-mono text-xs text-[oklch(78%_0.015_286)]">
          {projects_root_label()}
        </p>
      </div>

      <nav aria-label="Projects" class="space-y-2">
        <button
          :for={project <- @projects}
          phx-click="select_project"
          phx-value-id={project.id}
          class={[
            "flex w-full items-center justify-between rounded-2xl border p-3 text-left transition focus:outline-none focus-visible:ring-2 focus-visible:ring-violet-300",
            @active_project && project.id == @active_project.id &&
              "border-violet-300/22 bg-[oklch(20%_0.024_286)] text-violet-50",
            (!@active_project || project.id != @active_project.id) &&
              "border-[oklch(27%_0.022_286)] bg-[oklch(17%_0.016_286)]/72 hover:bg-[oklch(22%_0.018_286)]"
          ]}
        >
          <span class="min-w-0">
            <span class="block truncate text-sm font-semibold">{project.name}</span><span class="mt-0.5 block truncate font-mono text-[0.68rem] text-[oklch(64%_0.017_286)]">{project.display_path}</span>
          </span>
        </button>
      </nav>

      <div class="space-y-2">
        <p class="px-1 text-xs font-medium uppercase tracking-[0.14em] text-[oklch(68%_0.035_286)]">
          Sessions
        </p>
        <button
          :for={session <- @sessions}
          phx-click="select_session"
          phx-value-id={session.id}
          class={[
            "group flex w-full items-center gap-2 rounded-xl px-3 py-2 text-left text-xs transition focus:outline-none focus-visible:ring-2 focus-visible:ring-violet-300",
            active_session_file(@active_session) == session.file &&
              "bg-[oklch(20%_0.028_286)] text-[oklch(96%_0.01_286)]",
            active_session_file(@active_session) != session.file &&
              "text-[oklch(70%_0.018_286)] hover:bg-[oklch(21%_0.018_286)] hover:text-[oklch(88%_0.014_286)]"
          ]}
        >
          <span class="size-1.5 shrink-0 rounded-full bg-[oklch(54%_0.02_286)]"></span>
          <span class="min-w-0 flex-1">
            <span class="block truncate font-medium">{session.title}</span><span class="block truncate text-[0.68rem] text-[oklch(58%_0.017_286)]">{session_meta(session)}</span>
          </span>
        </button>
        <p
          :if={@sessions == []}
          class="rounded-xl border border-[oklch(28%_0.024_286)] px-3 py-4 text-center text-xs text-[oklch(62%_0.018_286)]"
        >
          No sessions yet
        </p>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  defp status_pill(assigns) do
    ~H"""
    <div class="rounded-xl border border-[oklch(30%_0.024_286)] bg-[oklch(18%_0.018_286)] px-3 py-2">
      <p class="text-[0.68rem] uppercase tracking-[0.12em] text-[oklch(58%_0.018_286)]">{@label}</p>
      <p class="mt-0.5 truncate font-medium text-[oklch(88%_0.014_286)]">{@value}</p>
    </div>
    """
  end
end
