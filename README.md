# wibeOS

A fully hallucinated operating system for macOS, inspired by Steve Sanderson's
[vibeOS](https://vibeos.sh/) from BUILD 2026.

The desktop shell is real and local (menu bar, dock, draggable windows, menus —
all instant, zero API calls). The *apps* are not: each app window is hallucinated
by Claude as a self-contained interactive HTML mini-app running in a sandboxed
iframe. Claude writes working JavaScript on the fly, so a calculator actually
computes locally; only actions that need fresh imagination (navigating the fake
Safari, etc.) trigger a regeneration. Opened apps are cached, so reopening is
instant.

## Requirements

- macOS 13+
- Swift toolchain (Xcode or Command Line Tools: `xcode-select --install`)
- An Anthropic API key (https://console.anthropic.com)

## Run

```sh
make run          # build & launch
make app          # build WibeOS.app, then: open WibeOS.app
```

On first launch it asks for your API key (stored in the app's preferences;
or set `ANTHROPIC_API_KEY` in the environment instead).

## App Store & themes

The dock has an App Store stocked entirely with apps invented for whoever is
logged in — Get installs them to the dock permanently (per persona;
right-click a dock icon to remove). On first login each persona also gets a
full OS theme hallucinated for them — wallpaper, accent, menu bar, dock,
window chrome, fonts — and apps are told the accent/dark-mode so they match.

## Personas

Boot lands on a login screen. Who you log in as changes *everything*: the
persona is injected into every hallucination, so Grandma's Mail is chain
letters in giant fonts while the hacker kid's whole machine is neon-on-black
1998. Each persona gets its own app cache. Click **+** to invent new personas
("a medieval wizard discovering computers"); right-click an avatar to remove
it. Log out via the  menu.

## Use

- Click dock icons to "launch" apps — you watch the HTML stream by as Claude
  hallucinates the app, then it becomes real(ish). Click ✨ to imagine any app.
- Option-click a dock icon (or View → Re-imagine) to force a fresh hallucination
  instead of the cached version.
- Menu bar, window dragging/minimize/zoom, Cmd+W close — all local and instant.
- `Cmd+R` reboots. `Cmd+Ctrl+F` for full screen — recommended for the illusion.
- Right-click → Inspect Element works for debugging the generated HTML.
- Camera/photo-booth apps use your real webcam (macOS will ask once). For the
  permission prompt to be attributed correctly, run as a bundle: `make app`
  then `open WibeOS.app` — with `make run` the prompt belongs to your terminal.

## Speed

- **Persistent cache**: each app is hallucinated once, then stored in
  `~/Library/Application Support/wibeOS/cache` — reopening is instant, even
  across reboots. Option-click a dock icon or View → Re-imagine to regenerate.
- **Prefetch**: at boot, the dock apps are pre-hallucinated in the background
  (2 at a time), so most apps are ready before you click. Disable with
  `WIBEOS_PREFETCH=0` (first boot prefetch costs roughly 8 app generations).
- **Patch updates**: data-wibe actions (browser navigation, opening an email…)
  return only the changed region as `<wibe-patch select="…">` blocks instead of
  the whole app — a fraction of the tokens, applied live without remounting.
- **Prompt caching**: the system prompt is cached server-side across calls.
- **Model**: defaults to `claude-haiku-4-5-20251001` (fast). For fancier apps:
  `WIBEOS_MODEL=claude-sonnet-4-6 make run`.

## Tuning

- System prompt: edit `systemPrompt` in `Sources/WibeOS/AppDelegate.swift` to
  change the OS's personality, default dock, look, etc.

## How it works

```
open app ─▶ shell asks Claude for ONE self-contained HTML app (streamed)
         ─▶ injected bridge script added, mounted in sandboxed <iframe>
         ─▶ app runs locally (its own JS) — most clicks cost nothing
         ─▶ controls marked data-wibe / data-wibe-enter round-trip to Claude
            for fresh hallucinated content (whole-window re-render)
```

Each window keeps its own small conversation history (creation pair + last 6
messages), so updates stay consistent and cheap. The Swift layer is a stateless
streaming proxy to the Anthropic API.

Only app generation and data-wibe actions cost tokens; everything else is local.
