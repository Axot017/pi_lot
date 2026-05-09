# pi Web UI Plan — Caveman

## Goal

Build LAN web UI for `pi` AI coding agent with Elixir Phoenix LiveView.

UI = control/display layer only. `pi` still works on host files in selected project cwd.

Need:

- Project picker from configured projects root.
- Per-project chat with `pi`.
- Per-project session history.
- New session, resume session, switch session.
- LAN access with safety controls. `pi` can read/write/edit/run commands.

## Research Summary

### Best integration: `pi --mode rpc`

Use RPC mode:

```bash
pi --mode rpc
```

RPC uses stdin/stdout JSONL. Good for Elixir. No Node inside BEAM. TypeScript SDK useful reference only. Maybe future Node sidecar.

Docs:

- `README.md` — modes, flags, sessions, tools, resources.
- `docs/rpc.md` — JSONL command/event protocol.
- `docs/session.md` — session JSONL + `SessionManager`.
- `docs/sdk.md` — SDK/session internals.
- `docs/extensions.md` — permission gates, tool interception, RPC UI.

### Project scoping

Start `pi` with cwd = project path:

```elixir
Port.open({:spawn_executable, pi_path}, [
  :binary,
  :exit_status,
  :use_stdio,
  :stderr_to_stdout,
  {:args, ["--mode", "rpc", ...]},
  {:cd, project_path}
])
```

`cwd` controls:

- File tool path resolution.
- `bash` directory.
- `.pi/` resource discovery.
- `AGENTS.md` / `CLAUDE.md` context discovery.
- Session grouping and default session dir name.
- Project settings from `.pi/settings.json`.

Never accept browser filesystem path. Browser sends project id/name. Server maps to validated dir under configured root.

### Project picker

Config:

```bash
PI_WEBUI_PROJECTS_DIR=/home/user/Projects
```

List direct child dirs. Rules:

- Resolve root to absolute path at boot.
- Ignore files and hidden/system dirs by default.
- Reject symlinks by default, or resolve and require still under root.
- Use stable id from dir name or hash of abs path.
- Later show git branch/status. Not MVP need.

### Chat protocol basics

LiveView sends RPC commands. UI renders streamed events.

Commands:

- `prompt` — send user message.
- `prompt` + `streamingBehavior: "steer"` — steer active run.
- `prompt` + `streamingBehavior: "followUp"` — queue after current run.
- `steer` / `follow_up` — explicit queued messages.
- `abort` — stop run.
- `get_state` — model, session id/file/name, streaming flags.
- `get_messages` — full conversation.
- `new_session` — fresh session.
- `switch_session` — load session JSONL.
- `fork`, `clone`, `get_fork_messages` — future branching.
- `set_session_name` — name session.
- `get_session_stats` — token/cost/context.
- `get_available_models`, `set_model`, `cycle_model` — model controls.
- `set_thinking_level`, `cycle_thinking_level` — reasoning controls.
- `compact`, `set_auto_compaction` — compaction.
- `get_commands` — extension commands, prompt templates, skills.

Events:

- `agent_start`, `agent_end`
- `turn_start`, `turn_end`
- `message_start`, `message_update`, `message_end`
- `tool_execution_start`, `tool_execution_update`, `tool_execution_end`
- `queue_update`
- `compaction_start`, `compaction_end`
- `auto_retry_start`, `auto_retry_end`
- `extension_error`
- `extension_ui_request`

JSONL framing:

- Split stdout on byte `\n` only.
- Strip optional trailing `\r`.
- Preserve partial records between port messages.
- Do not use generic line reader with weird newline semantics.

### Session persistence and history

`pi` sessions = JSONL files. Default path:

```text
~/.pi/agent/sessions/--<cwd-with-slashes-replaced>--/<timestamp>_<uuid>.jsonl
```

Header:

```json
{"type":"session","version":3,"id":"uuid","timestamp":"...","cwd":"/path/to/project"}
```

Then messages, model changes, thinking changes, compactions, labels, branches, metadata.

For normal chat, do not start `pi` with `--no-session`.

Startup modes:

- New persisted session:
  ```bash
  pi --mode rpc
  ```
- Continue latest project session:
  ```bash
  pi --mode rpc --continue
  ```
- Open specific session:
  ```bash
  pi --mode rpc --session /path/to/session.jsonl
  ```
- Web UI controlled session dir:
  ```bash
  pi --mode rpc --session-dir /path/to/webui/sessions
  ```

RPC has `switch_session`. No documented `list_sessions`. Web UI must list sessions itself.

Session listing plan:

1. Configure `PI_WEBUI_SESSION_DIR`, or use default `~/.pi/agent/sessions`.
2. For project, compute/discover project session folder.
3. Read `.jsonl` files.
4. Parse:
   - header: id, cwd, timestamp, parentSession.
   - latest `session_info`: display name.
   - first/last user message fallback title.
   - latest timestamp.
   - message count.
5. Filter `cwd` == canonical project path.
6. Sort latest first.

Alternative: Node sidecar using TS SDK `SessionManager.list(cwd, sessionDir)` for exact parity. Not MVP need.

### Database?

No DB required for MVP.

`pi` already stores chat/session history in JSONL. Projects come from dirs. LiveView active state lives in GenServers.

MVP no DB:

- Projects: read `PI_WEBUI_PROJECTS_DIR`.
- Sessions: read pi JSONL files.
- Active chat: supervised GenServers wrapping `pi --mode rpc`.
- Browser session: Phoenix signed cookie.

DB useful later for:

- Users/authz.
- Per-project UI prefs.
- Favorites/pins/tags.
- Prompt/tool audit logs.
- Team shared state.
- Fast search.
- Background jobs/durable registry.

If needed: SQLite via `ecto_sqlite3`. Postgres only for team/multi-user service.

### LAN security

LAN still dangerous. UI controls agent with host file + shell access.

Minimum before LAN bind:

- Explicit opt-in bind address. Endpoint `ip: {0,0,0,0}` only when configured.
- Auth, at least shared password for MVP.
- CSRF + LiveView origin checks. Avoid `check_origin: false` unless conscious risk.
- Project allowlist only under `PI_WEBUI_PROJECTS_DIR`.
- No arbitrary browser paths.
- No raw RPC command passthrough to clients.
- Sanitize downloads/exports.
- Avoid secret display when possible.

Pi safety knobs:

- Tool profiles:
  - Full: `read,bash,edit,write,grep,find,ls`.
  - Read-only: `--tools read,grep,find,ls`.
  - None: `--no-tools`.
- Disable untrusted project resources:
  - `--no-extensions`
  - `--no-skills`
  - `--no-prompt-templates`
  - `--no-context-files`
- Extensions run arbitrary TypeScript with full system permissions. Project `.pi/extensions` in untrusted repos = big risk.
- Consider permission-gate extension for dangerous bash.
- Consider protected-paths extension for `.env`, `.git/`, `node_modules/`, credentials, secrets.
- Consider dedicated OS user or container for stronger isolation.

Safety modes:

1. Trusted personal: full tools, project resources enabled, password, LAN ok.
2. Safer LAN: read-only default, project extensions off, explicit write/bash toggle.
3. Untrusted project: no project extensions/context unless manual enable.

### Extension UI

RPC can emit `extension_ui_request`:

- `select`
- `confirm`
- `input`
- `editor`
- `notify`
- `setStatus`
- `setWidget`
- `setTitle`
- `set_editor_text`

LiveView should render modals/forms/notifications and respond with `extension_ui_response` matching id.

MVP support at least:

- `notify`
- `confirm`
- `select`

Without this, permission extensions can hang until timeout.

## Architecture

### Phoenix/LiveView modules

- `PiWebui.Projects`
  - Reads project dirs from `PI_WEBUI_PROJECTS_DIR`.
  - Validates dirs.
  - Maps project id to canonical path.

- `PiWebui.Sessions`
  - Lists/parses session JSONL.
  - Computes title, timestamp, message count.
  - Later delete/rename.

- `PiWebui.PiSupervisor`
  - DynamicSupervisor for active RPC workers.

- `PiWebui.PiSession`
  - GenServer owning one `pi --mode rpc` port.
  - Keyed by `{project_id, session_file_or_new}`.
  - Sends RPC commands.
  - Parses JSONL stdout.
  - Tracks state + transcript.
  - Broadcasts via Phoenix PubSub.

- `PiWebui.PiTranscript`
  - Converts pi messages/events to UI chat items.
  - Handles assistant streaming deltas + tool updates.

- `PiWebuiWeb.WorkspaceLive`
  - Main UI: project picker, sessions, chat, input, status.

- `PiWebuiWeb.ExtensionUiLiveComponent`
  - Modals for extension UI requests.

### Process lifecycle

- One `PiSession` GenServer per active `{project, session}`.
- Reuse worker if another LiveView opens same project/session.
- Stop idle workers after timeout.
- On project/session switch, subscribe to new PubSub topic.

Startup:

- New session:
  ```bash
  pi --mode rpc --session-dir <configured-session-dir>
  ```
- Existing session:
  ```bash
  pi --mode rpc --session-dir <configured-session-dir> --session <session-file>
  ```

On start:

1. Spawn port with cwd = project path.
2. Send `get_state`.
3. Send `get_messages`.
4. Send `get_commands`.
5. Maybe send `get_session_stats`.
6. Broadcast initial snapshot.

### UI layout

Sidebar:

- Projects root status.
- Project picker/list.
- Session history.
- New session button.
- Search/filter later.

Main chat:

- Project name/path.
- Session name/id.
- Streaming transcript.
- Collapsible tool calls/results.
- Collapsible thinking blocks.
- Errors + extension notifications.

Input:

- Multi-line textarea.
- Send button.
- While streaming: steer/follow-up choice.
- Abort button.
- Queue display from `queue_update`.

Status/footer:

- Model + thinking level.
- Token/cost/context.
- Session file path.
- Compaction/retry indicators.

### Transcript rendering

Handle roles/types:

- `user`
- `assistant`
  - `text`
  - `thinking`
  - `toolCall`
- `toolResult`
- `bashExecution`
- `custom`
- `branchSummary`
- `compactionSummary`

Streaming updates assistant messages from `message_update`. Tool progress updates tool blocks by `toolCallId`.

## Implementation Plan

### Phase 1 — Foundation

1. Create Phoenix LiveView app.
2. Add config:
   - `PI_WEBUI_PROJECTS_DIR`
   - optional `PI_WEBUI_SESSION_DIR`
   - optional `PI_WEBUI_PI_PATH`, default `pi`
   - `PI_WEBUI_BIND_LAN` or endpoint IP config
   - shared password/basic auth
   - default pi args/tool profile
3. Implement project discovery.
4. Implement canonical paths + allowlist checks.
5. Build LiveView shell: project picker + empty chat.

### Phase 2 — pi RPC worker

1. Implement `PiSession` GenServer around Port.
2. Spawn `pi --mode rpc` with cwd = project.
3. Implement JSONL buffer + LF splitting.
4. Implement request ids + response correlation.
5. Implement `prompt`, `abort`, `get_state`, `get_messages`.
6. Track process exit and show errors.
7. Broadcast snapshots via PubSub.

### Phase 3 — Basic chat UI

1. Render user + assistant messages.
2. Render streaming text deltas.
3. Show streaming state from `agent_start` / `agent_end`.
4. Add input + send.
5. Add abort.
6. After prompt complete, run `get_messages` for consistency.

### Phase 4 — Session history

1. Use persistent sessions. Avoid `--no-session`.
2. Choose session storage: pi default or configured `--session-dir`.
3. Implement JSONL listing/parsing per project.
4. Show session history.
5. Implement new session.
6. Open/switch session via `--session` or `switch_session`.
7. Implement `set_session_name`.

### Phase 5 — Tools, queue, status

1. Render tool calls/results.
2. Render `tool_execution_start/update/end` progress.
3. Support messages while streaming:
   - steer
   - follow-up
4. Render `queue_update`.
5. Show model/thinking from `get_state`.
6. Show stats from `get_session_stats`.
7. Render compaction/retry events.

### Phase 6 — Extension UI and safety gates

1. Handle `extension_ui_request`.
2. Add modals for:
   - confirm
   - select
   - input
   - editor
3. Add notifications/status/widgets.
4. Add permission-gate/protected-paths config.
5. Add settings UI for tool profile:
   - full coding
   - read-only
   - no tools
6. Add config for disabling project extensions/skills/context.

### Phase 7 — LAN hardening

1. Add auth before LAN binding.
2. Configure LiveView `check_origin`.
3. Harden CSRF/session.
4. Add banner: safety mode + host exposure.
5. Add audit log option for prompts, switches, dangerous approvals.
6. Document safe deploy:
   - run dedicated OS user if possible,
   - firewall to trusted LAN/VPN,
   - never expose public internet.

### Phase 8 — Enhancements

1. Session search across JSONL.
2. Branch/fork/clone UI with `get_fork_messages`, `fork`, `clone`.
3. Model selector via `get_available_models`, `set_model`.
4. Slash command browser via `get_commands`.
5. Image/file attachments.
6. HTML export via `export_html`.
7. Optional SQLite for UI metadata, favorites, audit logs, indexes.
8. Idle worker shutdown + reconnect/reopen behavior.

## Open Decisions

1. Use pi default session dir or web-app `--session-dir`?
2. Enable project-local extensions/context by default?
3. LAN default tool profile: full coding or read-only?
4. Shared-password auth enough, or user accounts?
5. Allow symlinked projects?
6. Allow multiple browsers to control same active `pi` session?
7. Worker model: one per project, one per session, or one per browser?

## MVP Choices

- Use RPC mode, not SDK.
- No DB initially.
- Use dedicated configurable `--session-dir` for indexing/backups.
- One supervised `pi` process per active project/session.
- Project list only from `PI_WEBUI_PROJECTS_DIR`.
- Shared-password auth before LAN binding.
- Localhost default trusted personal mode.
- LAN default read-only or explicit full-tools opt-in.
- Session list by parsing JSONL.
- Implement extension `confirm`/`select` early so permission gates work.
