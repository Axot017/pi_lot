defmodule PiLotWeb.HomeLive do
  use PiLotWeb, :live_view

  alias PiLot.{PiSession, Projects, Sessions}

  def mount(_params, _session, socket) do
    projects = Projects.list_projects()
    selected_project = List.first(projects)

    socket =
      socket
      |> assign(:projects_root, Projects.root_status())
      |> assign(:projects, projects)
      |> assign(:selected_project, selected_project)
      |> assign(:sessions, [])
      |> assign(:active_session_file, nil)
      |> assign(:pi_pid, nil)
      |> assign(:transcript, PiLot.PiTranscript.new())
      |> assign(:prompt, "")
      |> assign(:loading?, false)

    socket =
      if selected_project && connected?(socket),
        do: open_session(socket, selected_project, nil),
        else: socket

    {:ok, socket}
  end

  def handle_event("select_project", %{"id" => id}, socket) do
    case Projects.get_project(id) do
      nil -> {:noreply, put_flash(socket, :error, "Project not found")}
      project -> {:noreply, open_session(socket, project, nil)}
    end
  end

  def handle_event("select_session", %{"file" => file}, socket) do
    if socket.assigns.selected_project do
      {:noreply, open_session(socket, socket.assigns.selected_project, file)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("new_session", _params, socket) do
    if socket.assigns.selected_project do
      {:noreply, open_session(socket, socket.assigns.selected_project, nil)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("send_prompt", %{"chat" => %{"prompt" => prompt}}, socket) do
    prompt = String.trim(prompt)

    cond do
      prompt == "" ->
        {:noreply, socket}

      is_nil(socket.assigns.pi_pid) ->
        {:noreply, put_flash(socket, :error, "No pi session available")}

      true ->
        behavior = if socket.assigns.transcript.streaming?, do: "followUp", else: nil
        :ok = PiSession.prompt(socket.assigns.pi_pid, prompt, behavior)
        {:noreply, assign(socket, :prompt, "")}
    end
  end

  def handle_event("abort", _params, socket) do
    if socket.assigns.pi_pid, do: PiSession.abort(socket.assigns.pi_pid)
    {:noreply, socket}
  end

  def handle_event("extension_confirm", %{"id" => id, "confirmed" => confirmed}, socket) do
    if socket.assigns.pi_pid do
      PiSession.extension_response(socket.assigns.pi_pid, %{
        id: id,
        confirmed: confirmed == "true"
      })
    end

    {:noreply, update(socket, :transcript, &%{&1 | extension_request: nil})}
  end

  def handle_event("extension_select", %{"id" => id, "value" => value}, socket) do
    if socket.assigns.pi_pid,
      do: PiSession.extension_response(socket.assigns.pi_pid, %{id: id, value: value})

    {:noreply, update(socket, :transcript, &%{&1 | extension_request: nil})}
  end

  def handle_info({:snapshot, transcript}, socket),
    do: {:noreply, assign(socket, :transcript, transcript)}

  def handle_info({:event, _event, transcript}, socket),
    do: {:noreply, assign(socket, :transcript, transcript)}

  defp open_session(socket, project, session_file) do
    if connected?(socket) do
      old_topic =
        PiSession.topic(
          socket.assigns.selected_project && socket.assigns.selected_project.id,
          socket.assigns.active_session_file
        )

      Phoenix.PubSub.unsubscribe(PiLot.PubSub, old_topic)
    end

    sessions = Sessions.list_sessions(project)

    case PiSession.ensure_started(project, session_file) do
      {:ok, pid} ->
        if connected?(socket),
          do: Phoenix.PubSub.subscribe(PiLot.PubSub, PiSession.topic(project.id, session_file))

        transcript = PiSession.snapshot(pid)

        socket
        |> assign(:selected_project, project)
        |> assign(:sessions, sessions)
        |> assign(:active_session_file, session_file)
        |> assign(:pi_pid, pid)
        |> assign(:transcript, transcript)

      {:error, reason} ->
        socket
        |> assign(:selected_project, project)
        |> assign(:sessions, sessions)
        |> put_flash(:error, "Could not start pi: #{inspect(reason)}")
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="h-dvh overflow-hidden bg-[oklch(13%_0.018_286)] text-[oklch(92%_0.012_286)] selection:bg-violet-400/30 selection:text-violet-50">
        <div class="mx-auto flex h-dvh min-h-0 w-full max-w-[1800px] flex-col overflow-hidden xl:flex-row">
          <aside class="hidden shrink-0 overflow-y-auto border-r border-[oklch(28%_0.024_286)] bg-[oklch(16%_0.018_286)]/92 xl:block xl:w-[22rem]">
            <.sidebar_content
              root={@projects_root}
              projects={@projects}
              selected_project={@selected_project}
              sessions={@sessions}
              active_session_file={@active_session_file}
            />
          </aside>

          <details class="group shrink-0 border-b border-[oklch(28%_0.024_286)] bg-[oklch(16%_0.018_286)] open:fixed open:inset-0 open:z-50 open:flex open:h-dvh open:flex-col xl:hidden">
            <summary class="flex cursor-pointer list-none items-center justify-between px-4 py-3 text-sm font-medium [&::-webkit-details-marker]:hidden">
              <span class="flex items-center gap-2">
                <.icon name="hero-folder" class="size-4 text-violet-200" /> Projects and sessions
              </span>
              <.icon name="hero-chevron-down" class="size-4 transition group-open:rotate-180" />
            </summary>
            <div class="min-h-0 flex-1 overflow-y-auto border-t border-[oklch(28%_0.024_286)]">
              <.sidebar_content
                root={@projects_root}
                projects={@projects}
                selected_project={@selected_project}
                sessions={@sessions}
                active_session_file={@active_session_file}
              />
            </div>
          </details>

          <main id="main-content" class="flex min-h-0 flex-1 flex-col overflow-hidden">
            <header class="border-b border-[oklch(28%_0.024_286)] bg-[oklch(15%_0.017_286)]/86 px-4 py-4 backdrop-blur-xl sm:px-6">
              <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
                <div class="min-w-0">
                  <div class="flex flex-wrap items-center gap-2 text-xs text-[oklch(68%_0.02_286)]">
                    <span>PiLot</span><span>/</span><span>{if @selected_project, do: @selected_project.display_path, else: "No project"}</span>
                    <span
                      :if={@transcript.streaming?}
                      class="rounded-full border border-violet-300/16 bg-[oklch(19%_0.026_286)] px-2 py-0.5 font-medium text-violet-200"
                    >
                      streaming
                    </span>
                  </div>
                  <h1 class="mt-1 truncate text-xl font-semibold tracking-tight text-[oklch(96%_0.01_286)]">
                    {if @selected_project,
                      do: @selected_project.name,
                      else: "Configure PI_WEBUI_PROJECTS_DIR"}
                  </h1>
                </div>

                <div class="grid grid-cols-2 gap-2 text-xs">
                  <.status_pill label="Model" value={model_name(@transcript.state)} />
                  <.status_pill label="Messages" value={Integer.to_string(length(@transcript.items))} />
                </div>
              </div>
            </header>

            <section aria-label="Chat transcript" class="flex min-h-0 flex-1 flex-col">
              <div id="chat-scroll" class="flex-1 space-y-5 overflow-y-auto px-4 py-5 sm:px-6 lg:px-8">
                <div
                  :if={@transcript.error}
                  class="rounded-2xl border border-rose-300/20 bg-rose-300/8 p-4 text-sm text-rose-100"
                >
                  {@transcript.error}
                </div>

                <div
                  :if={@transcript.items == []}
                  class="grid min-h-80 place-items-center rounded-3xl border border-dashed border-[oklch(32%_0.026_286)] bg-[oklch(16%_0.018_286)]/60 p-8 text-center"
                >
                  <div>
                    <div class="mx-auto grid size-12 place-items-center rounded-2xl bg-violet-400/10 text-2xl">
                      π
                    </div>
                    <h2 class="mt-4 text-lg font-semibold">Ready for real pi session</h2>
                    <p class="mt-2 max-w-md text-sm text-[oklch(68%_0.018_286)]">
                      Pick project, type prompt, stream response from <code>pi --mode rpc</code>.
                    </p>
                  </div>
                </div>

                <%= for item <- @transcript.items do %>
                  <article
                    id={"msg-#{item.id}"}
                    class={["group flex gap-3", item.role == :user && "justify-end"]}
                  >
                    <div
                      :if={item.role != :user}
                      class="mt-1 grid size-8 shrink-0 place-items-center rounded-xl bg-[oklch(23%_0.024_286)] text-xs font-bold text-violet-200"
                    >
                      {avatar(item.role)}
                    </div>
                    <div class={[
                      "max-w-[75ch] rounded-2xl border px-4 py-3 shadow-[0_18px_60px_oklch(8%_0.02_286_/_0.22)]",
                      item.role == :user &&
                        "border-violet-300/22 bg-[oklch(22%_0.04_286)] text-violet-50",
                      item.role != :user && "border-[oklch(29%_0.025_286)] bg-[oklch(18%_0.018_286)]"
                    ]}>
                      <div class="flex items-center justify-between gap-3">
                        <p class="text-xs font-semibold uppercase tracking-[0.12em] text-[oklch(65%_0.035_286)]">
                          {item.label}
                        </p>
                        <p class="text-xs text-[oklch(55%_0.018_286)]">{item.time}</p>
                      </div>
                      <p class="mt-2 whitespace-pre-wrap text-sm leading-6 text-[oklch(86%_0.014_286)]">
                        {item.body}
                      </p>
                      <pre
                        :if={item.kind == :tool && item.output not in [nil, ""]}
                        class="mt-3 overflow-x-auto rounded-xl border border-[oklch(30%_0.024_286)] bg-[oklch(14%_0.018_286)] p-3 text-xs leading-5 text-[oklch(74%_0.018_286)]"
                      ><code>{item.output}</code></pre>
                    </div>
                  </article>
                <% end %>
              </div>

              <.extension_modal request={@transcript.extension_request} />

              <div class="shrink-0 border-t border-[oklch(28%_0.024_286)] bg-[oklch(15%_0.017_286)] p-4 sm:p-5">
                <.form
                  for={%{}}
                  as={:chat}
                  id="chat-form"
                  phx-submit="send_prompt"
                  class="rounded-2xl border border-[oklch(31%_0.026_286)] bg-[oklch(18%_0.018_286)] shadow-[0_18px_80px_oklch(8%_0.02_286_/_0.28)] focus-within:border-violet-300/60 focus-within:ring-2 focus-within:ring-violet-300/20"
                >
                  <label for="chat-prompt" class="sr-only">Message pi</label>
                  <textarea
                    id="chat-prompt"
                    name="chat[prompt]"
                    rows="4"
                    class="min-h-28 w-full resize-none rounded-t-2xl bg-transparent px-4 py-3 text-sm leading-6 text-[oklch(92%_0.012_286)] placeholder:text-[oklch(55%_0.018_286)] focus:outline-none"
                    placeholder="Ask pi to inspect, edit, test, or explain this project..."
                  ></textarea>
                  <div class="flex flex-col gap-3 border-t border-[oklch(28%_0.024_286)] px-3 py-3 sm:flex-row sm:items-center sm:justify-between">
                    <div class="flex flex-wrap items-center gap-2 text-xs text-[oklch(66%_0.018_286)]">
                      <span class="rounded-full bg-[oklch(23%_0.02_286)] px-2.5 py-1">
                        {if @transcript.streaming?, do: "Prompt queues follow-up", else: "Ready"}
                      </span>
                    </div>
                    <div class="flex items-center gap-2">
                      <button
                        type="button"
                        phx-click="abort"
                        disabled={!@transcript.streaming?}
                        class="rounded-xl border border-[oklch(32%_0.026_286)] px-3 py-2 text-sm font-medium text-[oklch(82%_0.015_286)] transition hover:bg-[oklch(23%_0.02_286)] disabled:cursor-not-allowed disabled:opacity-40"
                      >
                        Abort
                      </button>
                      <button
                        type="submit"
                        disabled={is_nil(@selected_project)}
                        class="rounded-xl border border-violet-300/28 bg-[oklch(20%_0.034_286)] px-4 py-2 text-sm font-semibold text-violet-50 shadow-[0_0_20px_oklch(62%_0.22_286_/_0.18)] transition hover:border-violet-200/50 hover:bg-[oklch(22%_0.044_286)] disabled:cursor-not-allowed disabled:opacity-40"
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

  attr :root, :map, required: true
  attr :projects, :list, required: true
  attr :selected_project, :any, required: true
  attr :sessions, :list, required: true
  attr :active_session_file, :any, required: true

  defp sidebar_content(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-3 border-b border-[oklch(28%_0.024_286)] px-4 py-4">
      <div class="flex items-center gap-3">
        <div class="grid size-9 place-items-center rounded-xl border border-violet-300/24 bg-[oklch(19%_0.028_286)] text-sm font-black text-violet-50">
          π
        </div>
        <div>
          <p class="text-sm font-semibold tracking-tight">PiLot</p>
          <p class="text-xs text-[oklch(69%_0.018_286)]">Local agent cockpit</p>
        </div>
      </div>
      <button
        phx-click="new_session"
        class="rounded-lg border border-violet-300/18 bg-[oklch(18%_0.022_286)] px-2.5 py-1.5 text-xs font-medium transition hover:border-violet-400/60 hover:bg-violet-400/10"
      >
        New
      </button>
    </div>
    <div class="space-y-5 px-3 py-4">
      <div class="rounded-2xl border border-[oklch(28%_0.024_286)] bg-[oklch(18%_0.018_286)]/80 p-3">
        <p class="text-xs font-medium uppercase tracking-[0.14em] text-[oklch(68%_0.035_286)]">
          Projects root
        </p>
        <p class="mt-2 truncate font-mono text-xs text-[oklch(78%_0.015_286)]">{@root.path}</p>
      </div>
      <nav aria-label="Projects and sessions" class="space-y-2">
        <%= for project <- @projects do %>
          <section class="rounded-2xl border border-[oklch(27%_0.022_286)] bg-[oklch(17%_0.016_286)]/72 p-2">
            <button
              phx-click="select_project"
              phx-value-id={project.id}
              class={[
                "flex w-full items-center justify-between rounded-xl px-2.5 py-2 text-left transition",
                @selected_project && @selected_project.id == project.id &&
                  "border border-violet-300/14 bg-[oklch(20%_0.024_286)] text-violet-50",
                (!@selected_project || @selected_project.id != project.id) &&
                  "hover:bg-[oklch(22%_0.018_286)]"
              ]}
            >
              <span class="min-w-0">
                <span class="block truncate text-sm font-semibold">{project.name}</span><span class="mt-0.5 block truncate font-mono text-[0.68rem] text-[oklch(64%_0.017_286)]">{project.display_path}</span>
              </span>
            </button>
            <div
              :if={@selected_project && @selected_project.id == project.id}
              class="mt-1 space-y-1 pl-3"
            >
              <button
                phx-click="new_session"
                class={[
                  "group flex w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-xs transition",
                  is_nil(@active_session_file) &&
                    "bg-[oklch(20%_0.028_286)] text-[oklch(96%_0.01_286)]",
                  @active_session_file &&
                    "text-[oklch(70%_0.018_286)] hover:bg-[oklch(21%_0.018_286)]"
                ]}
              >
                New session
              </button>
              <%= for session <- @sessions do %>
                <button
                  phx-click="select_session"
                  phx-value-file={session.file}
                  class={[
                    "group flex w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-xs transition",
                    @active_session_file == session.file &&
                      "bg-[oklch(20%_0.028_286)] text-[oklch(96%_0.01_286)]",
                    @active_session_file != session.file &&
                      "text-[oklch(70%_0.018_286)] hover:bg-[oklch(21%_0.018_286)]"
                  ]}
                >
                  <span class="size-1.5 shrink-0 rounded-full bg-[oklch(54%_0.02_286)]"></span>
                  <span class="min-w-0 flex-1">
                    <span class="block truncate font-medium">{session.title}</span><span class="block truncate text-[0.68rem] text-[oklch(58%_0.017_286)]">{session.meta}</span>
                  </span>
                </button>
              <% end %>
            </div>
          </section>
        <% end %>
      </nav>
    </div>
    """
  end

  attr :request, :any, required: true

  defp extension_modal(%{request: nil} = assigns) do
    ~H"""
    <div></div>
    """
  end

  defp extension_modal(assigns) do
    ~H"""
    <div class="mx-4 mb-3 rounded-2xl border border-amber-300/20 bg-amber-300/10 p-4 text-sm text-amber-100 sm:mx-5">
      <p class="font-semibold">
        Extension request: {@request["method"] || @request["uiType"] || @request["kind"]}
      </p>
      <p class="mt-1">{@request["message"] || @request["prompt"] || @request["title"]}</p>
      <div class="mt-3 flex flex-wrap gap-2">
        <button
          phx-click="extension_confirm"
          phx-value-id={@request["id"]}
          phx-value-confirmed="true"
          class="rounded-lg bg-amber-200 px-3 py-1.5 font-semibold text-amber-950"
        >
          Allow
        </button>
        <button
          phx-click="extension_confirm"
          phx-value-id={@request["id"]}
          phx-value-confirmed="false"
          class="rounded-lg border border-amber-200/30 px-3 py-1.5"
        >
          Deny
        </button>
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

  defp model_name(%{"model" => %{"name" => name}}), do: name
  defp model_name(%{"model" => %{"id" => id}}), do: id
  defp model_name(_), do: "Unknown"

  defp avatar(:user), do: "Y"
  defp avatar(:tool), do: "T"
  defp avatar(_), do: "π"
end
