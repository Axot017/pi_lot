# Product

## Register

product

## Users

Solo developers using PiLot to control the `pi` AI coding agent across local projects. They work in focused coding sessions, often switching between projects and conversation history while expecting the agent to operate directly on host files.

## Product Purpose

PiLot provides a local-network Phoenix LiveView interface for selecting projects, chatting with `pi`, resuming sessions, and monitoring agent activity. Success means the developer can move faster than terminal-only control while still trusting project scope, session state, and safety boundaries.

## Brand Personality

Precise, calm, technical. The interface should feel fast, quiet, and dense in the spirit of Linear and Raycast: confident structure, low visual noise, excellent keyboard and scanning affordances.

## Anti-references

Avoid generic SaaS dashboards, toy chat UIs, decorative AI gloss, hacker neon, over-stylized terminal cosplay, and layouts that hide safety-critical state. Avoid anything that makes host file access feel casual or ambiguous.

## Design Principles

1. Make scope visible: current project, cwd, session, model, and tool profile must stay understandable.
2. Preserve flow: project/session switching and prompt entry should be quick, keyboard-friendly, and visually quiet.
3. Treat power with respect: dangerous actions, tool access, LAN exposure, and extension approvals need clear status and friction where appropriate.
4. Show agent work without noise: stream text, tool calls, queues, and errors in a way that is inspectable but not overwhelming.
5. Earn familiarity: use proven product UI patterns and reserve delight for helpful micro-interactions.

## Accessibility & Inclusion

Best-effort accessibility with strong keyboard support, visible focus states, readable contrast, semantic structure, and reduced-motion respect. Important safety and state information should not rely on color alone.
