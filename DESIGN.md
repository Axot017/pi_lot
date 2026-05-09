---
name: PiLot
description: Local agent cockpit for precise project/session control
colors:
  cockpit-bg: "oklch(13% 0.018 286)"
  cockpit-panel: "oklch(16% 0.018 286)"
  cockpit-surface: "oklch(18% 0.018 286)"
  cockpit-surface-active: "oklch(20% 0.024 286)"
  cockpit-border: "oklch(28% 0.024 286)"
  cockpit-text: "oklch(92% 0.012 286)"
  cockpit-text-muted: "oklch(69% 0.018 286)"
  violet-accent: "oklch(62% 0.22 286)"
  violet-soft: "oklch(75% 0.19 286)"
  amber-warning: "oklch(78% 0.12 78)"
  emerald-safe: "oklch(74% 0.14 158)"
typography:
  headline:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif"
    fontSize: "1.25rem"
    fontWeight: 600
    lineHeight: 1.35
    letterSpacing: "-0.01em"
  title:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "-0.01em"
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif"
    fontSize: "0.75rem"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "0.12em"
  code:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace"
    fontSize: "0.75rem"
    fontWeight: 400
    lineHeight: 1.45
rounded:
  sm: "0.5rem"
  md: "0.75rem"
  lg: "1rem"
  xl: "1.25rem"
spacing:
  xs: "0.25rem"
  sm: "0.5rem"
  md: "0.75rem"
  lg: "1rem"
  xl: "1.5rem"
components:
  button-primary:
    backgroundColor: "{colors.cockpit-surface-active}"
    textColor: "{colors.cockpit-text}"
    rounded: "{rounded.md}"
    padding: "0.5rem 1rem"
  button-secondary:
    backgroundColor: "{colors.cockpit-surface}"
    textColor: "{colors.cockpit-text-muted}"
    rounded: "{rounded.md}"
    padding: "0.5rem 0.75rem"
  message-assistant:
    backgroundColor: "{colors.cockpit-surface}"
    textColor: "{colors.cockpit-text}"
    rounded: "{rounded.xl}"
    padding: "0.75rem 1rem"
  message-user:
    backgroundColor: "{colors.cockpit-surface-active}"
    textColor: "{colors.cockpit-text}"
    rounded: "{rounded.xl}"
    padding: "0.75rem 1rem"
  input-composer:
    backgroundColor: "{colors.cockpit-surface}"
    textColor: "{colors.cockpit-text}"
    rounded: "{rounded.xl}"
    padding: "0.75rem 1rem"
---

# Design System: PiLot

## 1. Overview

**Creative North Star: "Dim Control Room"**

PiLot should feel like a quiet control surface in a dark room: compact, legible, and precise, with enough light to identify the active system state without turning the product into a neon poster. The current visual language is a dark violet-tinted product UI with one accent family, restrained surfaces, dense spacing, and external glow used only on active or primary affordances.

The design serves a powerful local coding agent. It must make project scope, session context, model state, and safety cues visible without ceremony. It explicitly rejects generic SaaS dashboards, toy chat UIs, decorative AI gloss, hacker neon, over-stylized terminal cosplay, and layouts that hide safety-critical state.

**Key Characteristics:**

- Dark, violet-tinted neutral shell with no pure black and no pure white.
- Dense, quiet, keyboard-ready controls.
- Tonal layering first; glow only for active or primary accents.
- Full-height app shell where navigation and transcript scroll independently.
- Functional copy, visible state, and no decorative gradients on broad backgrounds.

## 2. Colors

The palette is a restrained dark violet system: almost all pixels are neutral violet-black surfaces, with one luminous violet accent used sparingly for focus, active state, and primary action.

### Primary

- **Control Violet** (`violet-accent`): The only accent family. Use for focus rings, active status dots, primary button glow, selected session aura, and streaming/state chips. Never spread it across page backgrounds.
- **Soft Signal Violet** (`violet-soft`): Small live indicators and soft glows. It is a signal, not decoration.

### Secondary

- **Safety Amber** (`amber-warning`): Warnings, permission gates, and safety notices. Use with low-opacity amber surfaces, not saturated blocks.
- **Trusted Emerald** (`emerald-safe`): Safe/allowlisted states and successful checks. Use as a small chip or status marker only.

### Neutral

- **Cockpit Background** (`cockpit-bg`): Full viewport app background.
- **Cockpit Panel** (`cockpit-panel`): Sidebar and top-level navigation surfaces.
- **Cockpit Surface** (`cockpit-surface`): Cards, message bubbles, composer, and status pills.
- **Cockpit Active Surface** (`cockpit-surface-active`): Selected rows and user messages.
- **Cockpit Border** (`cockpit-border`): Structural dividers and quiet component outlines.
- **Cockpit Text** (`cockpit-text`): Primary readable text on dark surfaces.
- **Muted Console Text** (`cockpit-text-muted`): Metadata, timestamps, helper labels, and paths.

### Named Rules

**The One Light Rule.** Violet is the only luminous accent. If a second glow hue appears, remove it unless it is a semantic warning or success state.

**The No Sun Rule.** No large radial glows, blobs, hero halos, or atmospheric circles behind the interface. Glow belongs to small controls and active states only.

**The No Broad Gradient Rule.** Page backgrounds, chat backgrounds, and large panels stay flat. Gradients are not the system; controlled external light is.

## 3. Typography

**Display Font:** System UI stack (`-apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif`)  
**Body Font:** System UI stack  
**Label/Mono Font:** `ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace` for paths, commands, and code

**Character:** Native, fast, and product-grade. The type should feel closer to Linear and Raycast than a branded marketing page. There is no display face; trust comes from hierarchy, spacing, and restraint.

### Hierarchy

- **Headline** (600, `1.25rem`, `1.35`): Current session title and primary screen heading.
- **Title** (600, `0.875rem`, `1.4`): Project names, message authors, component headings, and prominent row labels.
- **Body** (400, `0.875rem`, `1.5`): Chat copy, descriptions, and most UI text. Keep prose under roughly 75ch.
- **Label** (600, `0.75rem`, `0.12em`, uppercase): Status labels, metadata headings, and compact pills.
- **Code** (400, `0.75rem`, `1.45`): Paths, commands, code snippets, and tool output.

### Named Rules

**The Native Tool Rule.** Use one system sans family for UI. Do not introduce display fonts, decorative type, or marketing-style type contrast into the product shell.

**The Metadata Stays Small Rule.** Paths, timestamps, counts, and helper text stay compact and muted. They support scanning; they never compete with session title or transcript content.

## 4. Elevation

PiLot uses layered dark surfaces, borders, and occasional external glow. It does not use heavy drop shadows for card depth. Shadows are mostly ambient black for modal-like density and violet glow for active/primary accents.

### Shadow Vocabulary

- **Ambient Transcript Shadow** (`0 18px 60px oklch(8% 0.02 286 / 0.22)`): Message bubbles and contained transcript elements.
- **Composer Lift** (`0 18px 80px oklch(8% 0.02 286 / 0.28)`): Pinned composer surface above the transcript.
- **Accent Glow** (`0 0 20px oklch(62% 0.22 286 / 0.18), 0 0 44px oklch(62% 0.22 286 / 0.08)`): Primary action and logo only.
- **Active Micro Glow** (`0 0 16px oklch(62% 0.22 286 / 0.12)`): Streaming pills and live session dots.

### Named Rules

**The Layer Before Light Rule.** Use surface lightness and borders before shadows. Add glow only when it clarifies active state or primary action.

**The Small Source Rule.** Glow must come from a small object: logo, primary button, live status dot, or selected session marker. Large glowing backgrounds are forbidden.

## 5. Components

### Buttons

- **Shape:** Gently rounded product control (`0.75rem`).
- **Primary:** Flat violet-tinted dark surface with violet border, white-violet text, and external violet glow. Padding is compact (`0.5rem 1rem`).
- **Hover / Focus:** Hover increases border contrast and glow slightly. Focus uses a visible violet ring. Never remove focus indicators.
- **Secondary / Ghost:** Dark transparent or low-contrast surface with border, muted text, no glow unless hovered.

### Chips

- **Style:** Compact rounded pills with low-opacity surface, tight horizontal padding, and small label text.
- **State:** Streaming/live chips may use a soft violet glow. Semantic chips use amber or emerald, but only as low-opacity status color.

### Cards / Containers

- **Corner Style:** Large rounded containers (`1rem` to `1.25rem`) for distinct UI surfaces.
- **Background:** Flat dark OKLCH surfaces. No broad gradients.
- **Shadow Strategy:** Tonal layer first, ambient shadow second. Violet glow only for active or primary accents.
- **Border:** Quiet violet-tinted borders around all major surfaces.
- **Internal Padding:** Dense product spacing (`0.75rem` to `1rem` normally, `1.5rem` for major areas).

### Inputs / Fields

- **Style:** Pinned composer uses a flat dark surface, visible border, and rounded outer shell.
- **Focus:** Border shifts to violet and adds a soft violet focus ring.
- **Error / Disabled:** Errors should use amber or rose semantic surfaces with explicit text. Disabled controls reduce contrast but keep shape and label visible.

### Navigation

- **Style:** Project tree lives in a left sidebar. The active project is flat and bordered; the active session may glow lightly because it represents the live conversational context.
- **Typography:** Project names use title weight; paths and metadata use monospace or muted label text.
- **Responsive:** Sidebar can become a capped, independently scrollable top region on small screens. Chat input remains pinned to viewport bottom.

### Chat Transcript

- **Assistant Messages:** Neutral dark surface, readable body copy, avatar on the left.
- **User Messages:** Slightly more violet active surface, aligned right.
- **System/Permission Messages:** Inline, visible, and serious. No modal by default.
- **Tool Blocks:** Nested code surfaces may appear inside messages, but must stay flat, compact, and inspectable.

## 6. Do's and Don'ts

### Do:

- **Do** keep the app as a full-height cockpit with independent sidebar and transcript scrolling.
- **Do** use OKLCH values for new UI color work.
- **Do** keep project, session, model, context, and safety state visible where relevant.
- **Do** use violet glow only for active/primary accents: logo, send button, live session dot, streaming chip.
- **Do** keep chat input pinned to the bottom of the viewport.
- **Do** use system UI fonts and compact product spacing.
- **Do** write direct UI copy: “Send prompt”, “Abort”, “Safety gate ready”.

### Don't:

- **Don't** use generic SaaS dashboards.
- **Don't** make toy chat UIs.
- **Don't** add decorative AI gloss.
- **Don't** use hacker neon or over-stylized terminal cosplay.
- **Don't** hide safety-critical state.
- **Don't** use large radial glows, blobs, suns, or atmospheric circles.
- **Don't** put gradients on page backgrounds, chat windows, or broad panels.
- **Don't** add side-stripe borders, gradient text, glassmorphism, or identical decorative card grids.
