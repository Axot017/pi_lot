Phoenix web app.

## Project rules

- Done changing? Run `mix precommit`. Fix issues.
- HTTP client: use built-in `Req`. Avoid `:httpoison`, `:tesla`, `:httpc`.

### Phoenix 1.8

- LiveView templates start with `<Layouts.app flash={@flash} ...>` wrapping content.
- `Layouts` already aliased in `my_app_web.ex`. No extra alias needed.
- Missing `current_scope` assign means wrong auth routes or missing pass to `<Layouts.app>`. Move route into proper `live_session`; pass `current_scope`.
- `<.flash_group>` only in `layouts.ex`. Never call elsewhere.
- Icons: use `<.icon name="hero-x-mark" class="w-5 h-5"/>`. Never use `Heroicons` modules.
- Form inputs: use imported `<.input>` when available.
- Override `<.input class=...>`? Defaults gone. Your classes must fully style input.

### JS/CSS

- Use Tailwind classes + custom CSS. Make polished, responsive UI.
- Tailwind v4 app.css syntax. Keep it:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";

- No `tailwind.config.js` needed for phx.new Tailwind v4.
- Never use `@apply`.
- Build custom Tailwind components. No daisyUI.
- Only `app.js` and `app.css` bundles supported.
  - No external script `src` or link `href` in layouts.
  - Import vendor deps into `app.js` / `app.css`.
  - Never inline `<script>custom js</script>` in templates.

### UI/UX

- Make world-class UI: usable, aesthetic, modern.
- Add subtle micro-interactions: hover, transitions, loading states.
- Keep typography, spacing, layout balanced.
- Add delightful details without clutter.

<!-- usage-rules-start -->

<!-- phoenix:elixir-start -->
## Elixir

- Lists have no index access syntax. Never `mylist[i]`. Use `Enum.at/2`, pattern matching, or `List`.

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Variables immutable; can rebind. For `if`/`case`/`cond`, bind expression result outside. Never rebind only inside.

      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- One module per file. No nested multiple modules.
- Structs do not support map access by default. Never `changeset[:field]`. Use `struct.field` or `Ecto.Changeset.get_field/2`.
- Date/time: use stdlib `Time`, `Date`, `DateTime`, `Calendar`. No deps unless asked or parsing needs `date_time_parser`.
- Never `String.to_atom/1` on user input.
- Predicate funcs end with `?`; do not start with `is_` unless guard-style.
- OTP child specs need names: `{DynamicSupervisor, name: MyApp.MyDynamicSup}`. Then `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`.
- Concurrent enumeration: use `Task.async_stream(collection, fun, timeout: :infinity)` usually.

## Mix

- Read task docs/options first: `mix help task_name`.
- Debug tests by file: `mix test test/my_test.exs`; or failed only: `mix test --failed`.
- Avoid `mix deps.clean --all` unless strong reason.

## Tests

- Use `start_supervised!/1` for test processes. Cleanup guaranteed.
- Avoid `Process.sleep/1` and `Process.alive?/1`.
  - Wait for finish: monitor and assert DOWN.

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

  - Sync messages: use `_ = :sys.get_state(pid)`.
<!-- phoenix:elixir-end -->

<!-- phoenix:phoenix-start -->
## Phoenix

- Router `scope` alias prefixes routes. Avoid duplicate module prefixes.
- Do not add route aliases manually. Scope handles it:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser
        live "/users", UserLive, :index
      end

  Route points to `AppWeb.Admin.UserLive`.

- No `Phoenix.View`. Not needed.
<!-- phoenix:phoenix-end -->

<!-- phoenix:ecto-start -->
## Ecto

- Preload associations before template access, e.g. `message.user.email`.
- In `seeds.exs`, import `Ecto.Query` and needed modules.
- Schema fields use `:string`, even text columns: `field :name, :string`.
- `validate_number/2` has no `:allow_nil`. Do not use it.
- Use `Ecto.Changeset.get_field(changeset, :field)` for changeset fields.
- Programmatic fields (`user_id`) must not be in `cast`. Set explicitly.
- Generate migrations with `mix ecto.gen.migration migration_name_using_underscores`.
<!-- phoenix:ecto-end -->

<!-- phoenix:html-start -->
## Phoenix HTML / HEEx

- Templates use `~H` or `.html.heex`. Never `~E`.
- Forms: use `Phoenix.Component.form/1` and `inputs_for/1`. Never `Phoenix.HTML.form_for` / `inputs_for`.
- Forms use `to_form/2`; assign `form`; template uses `@form[:field]`.

      assign(socket, form: to_form(...))
      <.form for={@form} id="msg-form">
        <.input field={@form[:field]} />
      </.form>

- Add unique DOM IDs to forms, buttons, key elements.
- App-wide imports/aliases go in `my_app_web.ex` `html_helpers`.
- No `else if` / `elseif` in Elixir. Use `cond` or `case`.

      <%= cond do %>
        <% condition -> %>
          ...
        <% other_condition -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- Literal `{` or `}` in code blocks need `phx-no-curly-interpolation`.

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

- HEEx class conditionals use list syntax `[...]`; wrap `if(...)` with parens.

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100")
      ]}>Text</a>

- Never `<% Enum.each %>` for content. Use `<%= for item <- @collection do %>`.
- Template comments: `<%!-- comment --%>`.
- Attributes use `{...}` interpolation. Body values use `{...}`. Body blocks use `<%= ... %>`.

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

- Never attribute interpolation like `id="<%= @id %>"`. Never `{if ...}` blocks.
<!-- phoenix:html-end -->

<!-- phoenix:liveview-start -->
## LiveView

- No deprecated `live_redirect` / `live_patch`. Use `<.link navigate={href}>`, `<.link patch={href}>`, `push_navigate`, `push_patch`.
- Avoid LiveComponents unless strong need.
- Name LiveViews `AppWeb.WeatherLive`. Router default browser scope already aliases `AppWeb`; use `live "/weather", WeatherLive`.

### Streams

- Use streams for collections. Avoid assigning large lists.
  - Append: `stream(socket, :messages, [new_msg])`
  - Reset: `stream(socket, :messages, messages, reset: true)`
  - Prepend: `stream(socket, :messages, [new_msg], at: -1)`
  - Delete: `stream_delete(socket, :messages, msg)`

- Template for streams: parent has DOM id + `phx-update="stream"`; children use stream id.

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- Streams not enumerable. No `Enum.filter/2` or `Enum.reject/2` on streams. Refetch and reset stream.
- Streams have no count/empty support. Track count/empty via assign. Empty state may use `hidden only:block` as only sibling.

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @streams.tasks} id={id}>
          {task.name}
        </div>
      </div>

- Assign changes inside streamed items require re-streaming items.

      {:noreply,
       socket
       |> stream_insert(:messages, message)
       |> assign(:editing_message_id, String.to_integer(message_id))
       |> assign(:edit_form, edit_form)}

- Never `phx-update="append"` or `phx-update="prepend"` for collections.

### JS interop

- If `phx-hook` manages DOM, also set `phx-update="ignore"`.
- `phx-hook` needs unique DOM id.
- Hooks: colocated HEEx hooks or external hooks in `assets/js/` passed to `LiveSocket`.

#### Colocated hooks

- No raw embedded `<script>` in HEEx.
- Use colocated hook script tag:

    <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
      export default {
        mounted() {
          this.el.addEventListener("input", e => {
            let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
            if(match) {
              this.el.value = `${match[1]}-${match[2]}-${match[3]}`
            }
          })
        }
      }
    </script>

- Colocated hooks auto-bundle into `app.js`.
- Colocated hook names start with `.`.

#### External hooks

- Put external hooks in `assets/js/`; pass to `LiveSocket`.

    const MyHook = {
      mounted() { ... }
    }
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: { MyHook }
    });

#### Events

- Use `push_event/3` to send data to hook. Always return/rebind socket.

    socket = push_event(socket, "my_event", %{...})

    def handle_event("some_event", _, socket) do
      {:noreply, push_event(socket, "my_event", %{...})}
    end

- JS receives with `this.handleEvent`.

    mounted() {
      this.handleEvent("my_event", data => console.log("from server:", data));
    }

- JS sends with `this.pushEvent`; server can reply.

    mounted() {
      this.el.addEventListener("click", e => {
        this.pushEvent("my_event", { one: 1 }, reply => console.log("got reply from server:", reply));
      })
    }

    def handle_event("my_event", %{"one" => 1}, socket) do
      {:reply, %{two: 2}, socket}
    end

### LiveView tests

- Use `Phoenix.LiveViewTest` and `LazyHTML`.
- Drive form tests with `render_submit/2` and `render_change/2`.
- Make step-by-step test plan; split major cases into small files.
- Test via key element IDs from templates: `element/2`, `has_element?/2`, selectors.
- Never test raw HTML. Prefer selectors and outcomes.
- Avoid brittle text assertions; prefer key elements.
- `Phoenix.Component` output may differ. Test actual structure.
- Debug selectors with limited LazyHTML output.

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Forms

#### Params forms

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

- `to_form/1` map expects string keys.
- Use `as:` to nest params.

    def handle_event("submitted", %{"user" => user_params}, socket) do
      {:noreply, assign(socket, form: to_form(user_params, as: :user))}
    end

#### Changeset forms

- Changesets provide data, params, errors. `:as` auto-computed.

    %MyApp.Users.User{}
    |> Ecto.Changeset.change()
    |> to_form()

- Submit params under `%{"user" => user_params}`.
- Template:

    <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:field]} type="text" />
    </.form>

- Always explicit unique form DOM ID.

#### Avoid form errors

- LiveView assigns form via `to_form/2`; template uses `<.input>` and `@form[:field]`.
- Never pass changeset to `<.form>`. Never access changeset in template.
- Never `<.form let={f} ...>`. Use `<.form for={@form} ...>`.
- UI driven by `to_form/2` assign derived from changeset.
<!-- phoenix:liveview-end -->

<!-- usage-rules-end -->
