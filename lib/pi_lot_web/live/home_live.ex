defmodule PiLotWeb.HomeLive do
  use PiLotWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       projects: projects(),
       messages: messages()
     )}
  end

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
              <.sidebar_content projects={@projects} />
            </div>
          </details>

          <aside class="hidden shrink-0 overflow-y-auto border-r border-[oklch(28%_0.024_286)] bg-[oklch(16%_0.018_286)]/92 backdrop-blur-xl xl:block xl:min-h-0 xl:w-[22rem]">
            <.sidebar_content projects={@projects} />
          </aside>

          <main id="main-content" class="flex min-h-0 flex-1 flex-col overflow-hidden">
            <header class="border-b border-[oklch(28%_0.024_286)] bg-[oklch(15%_0.017_286)]/86 px-4 py-4 backdrop-blur-xl sm:px-6">
              <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
                <div class="min-w-0">
                  <div class="flex flex-wrap items-center gap-2 text-xs text-[oklch(68%_0.02_286)]">
                    <span>pi_lot</span>
                    <span class="text-[oklch(45%_0.02_286)]">/</span>
                    <span>Web UI foundation</span>
                    <span class="rounded-full border border-violet-300/16 bg-[oklch(19%_0.026_286)] px-2 py-0.5 font-medium text-violet-200 shadow-[0_0_16px_oklch(62%_0.22_286_/_0.12)]">
                      streaming
                    </span>
                  </div>
                  <h1 class="mt-1 truncate text-xl font-semibold tracking-tight text-[oklch(96%_0.01_286)]">
                    Add project session workspace
                  </h1>
                </div>

                <div class="grid grid-cols-2 gap-2 text-xs">
                  <.status_pill label="Model" value="Claude Sonnet 4.5" />
                  <.status_pill label="Context" value="41%" />
                </div>
              </div>
            </header>

            <div class="min-h-0 flex-1 overflow-hidden">
              <section aria-label="Chat transcript" class="flex h-full min-h-0 flex-col">
                <div class="flex-1 space-y-5 overflow-y-auto px-4 py-5 sm:px-6 lg:px-8">
                  <div class="rounded-2xl border border-amber-300/20 bg-amber-300/8 p-4 text-sm text-amber-100">
                    <div class="flex items-start gap-3">
                      <.icon name="hero-shield-exclamation" class="mt-0.5 size-5 text-amber-200" />
                      <div>
                        <p class="font-semibold">Safety gate ready</p>
                        <p class="mt-1 text-amber-100/78">
                          Bash and write tools are enabled for this trusted local session. Permission prompts will appear inline before risky commands.
                        </p>
                      </div>
                    </div>
                  </div>

                  <%= for message <- @messages do %>
                    <article class={[
                      "group flex gap-3",
                      message.role == :user && "justify-end"
                    ]}>
                      <div
                        :if={message.role != :user}
                        class="mt-1 grid size-8 shrink-0 place-items-center rounded-xl bg-[oklch(23%_0.024_286)] text-xs font-bold text-violet-200"
                      >
                        {message.avatar}
                      </div>
                      <div class={[
                        "max-w-[75ch] rounded-2xl border px-4 py-3 shadow-[0_18px_60px_oklch(8%_0.02_286_/_0.22)]",
                        message.role == :user &&
                          "border-violet-300/22 bg-[oklch(22%_0.04_286)] text-violet-50",
                        message.role == :assistant &&
                          "border-[oklch(29%_0.025_286)] bg-[oklch(18%_0.018_286)]",
                        message.role == :thinking &&
                          "border-[oklch(25%_0.02_286)] bg-[oklch(15%_0.016_286)]/70 text-[oklch(66%_0.016_286)] shadow-none",
                        message.role == :system &&
                          "border-violet-300/18 bg-[oklch(18%_0.026_286)]"
                      ]}>
                        <div class="flex items-center justify-between gap-3">
                          <p class="text-xs font-semibold uppercase tracking-[0.12em] text-[oklch(65%_0.035_286)]">
                            {message.label}
                          </p>
                          <p class="text-xs text-[oklch(55%_0.018_286)]">{message.time}</p>
                        </div>
                        <p class="mt-2 text-sm leading-6 text-[oklch(86%_0.014_286)]">
                          {message.body}
                        </p>

                        <div
                          :if={message.kind == :tool}
                          class="mt-3 overflow-hidden rounded-xl border border-[oklch(30%_0.024_286)] bg-[oklch(14%_0.018_286)]"
                        >
                          <div class="flex items-center justify-between border-b border-[oklch(28%_0.024_286)] px-3 py-2">
                            <span class="font-mono text-xs text-violet-200">
                              read lib/pi_lot_web/router.ex
                            </span>
                            <span class="rounded-full bg-violet-300/10 px-2 py-0.5 text-[0.68rem] text-violet-100">
                              complete
                            </span>
                          </div>
                          <pre class="overflow-x-auto p-3 text-xs leading-5 text-[oklch(74%_0.018_286)]"><code>scope "/", PiLotWeb do
    pipe_through :browser
    live "/", HomeLive
    end</code></pre>
                        </div>

                        <div
                          :if={message.kind == :bash}
                          class="mt-3 rounded-xl border border-emerald-300/15 bg-emerald-300/7 p-3"
                        >
                          <div class="flex items-center justify-between gap-3">
                            <p class="font-mono text-xs text-emerald-100">mix precommit</p>
                            <span class="text-xs text-emerald-200">running</span>
                          </div>
                        </div>
                      </div>
                    </article>
                  <% end %>
                </div>

                <div class="shrink-0 border-t border-[oklch(28%_0.024_286)] bg-[oklch(15%_0.017_286)] p-4 sm:p-5">
                  <div class="rounded-2xl border border-[oklch(31%_0.026_286)] bg-[oklch(18%_0.018_286)] shadow-[0_18px_80px_oklch(8%_0.02_286_/_0.28)] focus-within:border-violet-300/60 focus-within:ring-2 focus-within:ring-violet-300/20">
                    <label for="prompt" class="sr-only">Message pi</label>
                    <textarea
                      id="prompt"
                      rows="4"
                      class="min-h-28 w-full resize-none rounded-t-2xl bg-transparent px-4 py-3 text-sm leading-6 text-[oklch(92%_0.012_286)] placeholder:text-[oklch(55%_0.018_286)] focus:outline-none"
                      placeholder="Ask pi to inspect, edit, test, or explain this project..."
                    ></textarea>
                    <div class="flex flex-col gap-3 border-t border-[oklch(28%_0.024_286)] px-3 py-3 sm:flex-row sm:items-center sm:justify-between">
                      <div class="flex flex-wrap items-center gap-2 text-xs text-[oklch(66%_0.018_286)]">
                        <span class="rounded-full bg-[oklch(23%_0.02_286)] px-2.5 py-1">
                          Enter sends
                        </span>
                        <span class="rounded-full bg-[oklch(23%_0.02_286)] px-2.5 py-1">
                          ⌘ Enter newline
                        </span>
                        <span class="rounded-full bg-violet-400/12 px-2.5 py-1 text-violet-200">
                          follow-up queued
                        </span>
                      </div>
                      <div class="flex items-center gap-2">
                        <button class="rounded-xl border border-[oklch(32%_0.026_286)] px-3 py-2 text-sm font-medium text-[oklch(82%_0.015_286)] transition hover:bg-[oklch(23%_0.02_286)] focus:outline-none focus-visible:ring-2 focus-visible:ring-violet-300">
                          Abort
                        </button>
                        <button class="rounded-xl border border-violet-300/28 bg-[oklch(20%_0.034_286)] px-4 py-2 text-sm font-semibold text-violet-50 shadow-[0_0_20px_oklch(62%_0.22_286_/_0.18),0_0_44px_oklch(62%_0.22_286_/_0.08)] transition hover:border-violet-200/50 hover:bg-[oklch(22%_0.044_286)] hover:shadow-[0_0_28px_oklch(62%_0.22_286_/_0.24),0_0_56px_oklch(62%_0.22_286_/_0.12)] focus:outline-none focus-visible:ring-2 focus-visible:ring-violet-200">
                          Send prompt
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </section>
            </div>
          </main>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :projects, :list, required: true

  defp sidebar_content(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-3 border-b border-[oklch(28%_0.024_286)] px-4 py-4">
      <div class="flex items-center gap-3">
        <div class="grid size-9 place-items-center rounded-xl border border-violet-300/24 bg-[oklch(19%_0.028_286)] text-sm font-black text-violet-50 shadow-[0_0_22px_oklch(62%_0.22_286_/_0.28),0_0_44px_oklch(62%_0.22_286_/_0.12)]">
          π
        </div>
        <div>
          <p class="text-sm font-semibold tracking-tight">PiLot</p>
          <p class="text-xs text-[oklch(69%_0.018_286)]">Local agent cockpit</p>
        </div>
      </div>
      <button class="rounded-lg border border-violet-300/18 bg-[oklch(18%_0.022_286)] px-2.5 py-1.5 text-xs font-medium text-[oklch(84%_0.024_286)] shadow-[0_0_18px_oklch(62%_0.22_286_/_0.10)] transition hover:border-violet-400/60 hover:bg-violet-400/10 hover:shadow-[0_0_24px_oklch(62%_0.22_286_/_0.18)] focus:outline-none focus-visible:ring-2 focus-visible:ring-violet-300">
        New
      </button>
    </div>

    <div class="space-y-5 px-3 py-4">
      <div class="rounded-2xl border border-[oklch(28%_0.024_286)] bg-[oklch(18%_0.018_286)]/80 p-3">
        <div class="flex items-center justify-between gap-3">
          <p class="text-xs font-medium uppercase tracking-[0.14em] text-[oklch(68%_0.035_286)]">
            Projects root
          </p>
          <span class="rounded-full bg-emerald-400/10 px-2 py-0.5 text-[0.68rem] font-medium text-emerald-200">
            allowlisted
          </span>
        </div>
        <p class="mt-2 truncate font-mono text-xs text-[oklch(78%_0.015_286)]">
          /home/axot/Projects
        </p>
      </div>

      <nav aria-label="Projects and sessions" class="space-y-2">
        <%= for project <- @projects do %>
          <section class="rounded-2xl border border-[oklch(27%_0.022_286)] bg-[oklch(17%_0.016_286)]/72 p-2">
            <button class={[
              "flex w-full items-center justify-between rounded-xl px-2.5 py-2 text-left transition focus:outline-none focus-visible:ring-2 focus-visible:ring-violet-300",
              project.active &&
                "border border-violet-300/14 bg-[oklch(20%_0.024_286)] text-violet-50",
              !project.active && "hover:bg-[oklch(22%_0.018_286)]"
            ]}>
              <span class="min-w-0">
                <span class="block truncate text-sm font-semibold">{project.name}</span>
                <span class="mt-0.5 block truncate font-mono text-[0.68rem] text-[oklch(64%_0.017_286)]">
                  {project.path}
                </span>
              </span>
              <span class="ml-3 rounded-full border border-[oklch(32%_0.03_286)] px-2 py-0.5 text-[0.68rem] text-[oklch(74%_0.02_286)]">
                {length(project.sessions)}
              </span>
            </button>

            <div class="mt-1 space-y-1 pl-3">
              <%= for session <- project.sessions do %>
                <button class={[
                  "group flex w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-xs transition focus:outline-none focus-visible:ring-2 focus-visible:ring-violet-300",
                  session.active &&
                    "bg-[oklch(20%_0.028_286)] text-[oklch(96%_0.01_286)] shadow-[inset_0_0_0_1px_oklch(70%_0.16_286_/_0.12),0_0_18px_oklch(62%_0.22_286_/_0.10)]",
                  !session.active &&
                    "text-[oklch(70%_0.018_286)] hover:bg-[oklch(21%_0.018_286)] hover:text-[oklch(88%_0.014_286)]"
                ]}>
                  <span class={[
                    "size-1.5 rounded-full shrink-0",
                    session.status == :running &&
                      "bg-violet-300 shadow-[0_0_16px_oklch(75%_0.19_286)]",
                    session.status == :idle && "bg-[oklch(54%_0.02_286)]",
                    session.status == :error && "bg-rose-300"
                  ]}>
                  </span>
                  <span class="min-w-0 flex-1">
                    <span class="block truncate font-medium">{session.title}</span>
                    <span class="block truncate text-[0.68rem] text-[oklch(58%_0.017_286)]">
                      {session.meta}
                    </span>
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

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :tone, :string, default: "default"

  defp status_pill(assigns) do
    ~H"""
    <div class={[
      "rounded-xl border px-3 py-2",
      @tone == "default" && "border-[oklch(30%_0.024_286)] bg-[oklch(18%_0.018_286)]",
      @tone == "violet" && "border-violet-300/20 bg-violet-300/8",
      @tone == "safe" && "border-emerald-300/20 bg-emerald-300/8"
    ]}>
      <p class="text-[0.68rem] uppercase tracking-[0.12em] text-[oklch(58%_0.018_286)]">{@label}</p>
      <p class="mt-0.5 truncate font-medium text-[oklch(88%_0.014_286)]">{@value}</p>
    </div>
    """
  end

  defp projects do
    [
      %{
        name: "pi_lot",
        path: "~/Projects/pi_lot",
        active: true,
        sessions: [
          %{
            title: "Web UI foundation",
            meta: "Streaming · 6 messages",
            status: :running,
            active: true
          },
          %{title: "RPC worker spike", meta: "Today · 18 messages", status: :idle, active: false},
          %{
            title: "Session parser notes",
            meta: "Yesterday · 11 messages",
            status: :idle,
            active: false
          }
        ]
      },
      %{
        name: "garden",
        path: "~/Projects/garden",
        active: false,
        sessions: [
          %{
            title: "Fix deploy script",
            meta: "Apr 30 · 9 messages",
            status: :idle,
            active: false
          },
          %{
            title: "Permission denied",
            meta: "Errored · needs review",
            status: :error,
            active: false
          }
        ]
      },
      %{
        name: "notes_cli",
        path: "~/Projects/notes_cli",
        active: false,
        sessions: []
      }
    ]
  end

  defp messages do
    [
      %{
        role: :user,
        label: "You",
        avatar: "Y",
        time: "21:42",
        body:
          "Add a LiveView home page mock with project sessions and a complete chat window. Use mock data only for now.",
        kind: :text
      },
      %{
        role: :thinking,
        label: "thinking",
        avatar: "…",
        time: "21:42",
        body:
          "Inspect router and layout conventions. Keep mock data local. Preserve Phoenix 1.8 layout rules.",
        kind: :text
      },
      %{
        role: :assistant,
        label: "pi",
        avatar: "π",
        time: "21:42",
        body:
          "I will replace the starter page with a static LiveView workspace and keep the route ready for future events.",
        kind: :text
      },
      %{
        role: :assistant,
        label: "tool call",
        avatar: "T",
        time: "21:43",
        body: "Reading router and layout conventions before editing.",
        kind: :tool
      },
      %{
        role: :system,
        label: "permission",
        avatar: "!",
        time: "21:43",
        body:
          "Extension requested confirmation before running `mix precommit`. Approved for trusted project pi_lot.",
        kind: :text
      },
      %{
        role: :assistant,
        label: "pi",
        avatar: "π",
        time: "21:44",
        body:
          "The first pass is too busy. I will remove secondary panels, keep only project/session navigation, and make the chat area carry the page.",
        kind: :text
      },
      %{
        role: :user,
        label: "You",
        avatar: "Y",
        time: "21:45",
        body:
          "Simplify it. No tool activity or queue. Keep the top bar focused and make the prompt button quieter.",
        kind: :text
      },
      %{
        role: :thinking,
        label: "thinking",
        avatar: "…",
        time: "21:45",
        body:
          "Simplify the cockpit: remove secondary panels, reduce top-bar status, keep composer pinned.",
        kind: :text
      },
      %{
        role: :assistant,
        label: "pi",
        avatar: "π",
        time: "21:45",
        body:
          "Removing the right rail gives the transcript room to breathe. The sidebar remains the only navigation surface, and the header only reports model plus context.",
        kind: :text
      },
      %{
        role: :assistant,
        label: "tool call",
        avatar: "T",
        time: "21:46",
        body: "Updating the LiveView mock with fewer panels and a single violet accent system.",
        kind: :tool
      },
      %{
        role: :assistant,
        label: "pi",
        avatar: "π",
        time: "21:47",
        body:
          "HomeLive is in place. The mock now focuses on project scope, session history, scrollable transcript, inline tool blocks, safety notice, and composer controls.",
        kind: :bash
      },
      %{
        role: :assistant,
        label: "pi",
        avatar: "π",
        time: "21:48",
        body:
          "Next I would wire project selection to real assigns, then replace the static transcript with RPC events once the worker exists.",
        kind: :text
      }
    ]
  end
end
