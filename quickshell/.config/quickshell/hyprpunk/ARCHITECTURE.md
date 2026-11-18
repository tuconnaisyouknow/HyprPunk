# HyprPunk shell architecture

How the shell is put together and the invariants every change keeps. It's the target of
the rewrite: code that doesn't follow it yet is code still to rewrite, not an exception.
The craft rules (CLAUDE.md, Craft) say what the shell must feel like; this file says how
the code makes that possible.

## The principle

**Every piece of state has exactly one owner, and everything else only reads it.**

- The system's state (audio, network, battery, players…) belongs to a service, once for
  the whole shell.
- What's open or showing belongs to the shell's state: once for the shell, or once per
  screen.
- Each surface owns only its own looks: where things are and how they move.

A surface never decides for another one, a service never knows a surface exists, and two
screens never compute the same thing twice.

## Tree

```
shell.qml        the root: services that start with the shell, one ScreenShell per
                 screen, the lock, the IPC commands
VisualizerShell.qml  the desktop's music wave, run as its own process
config/          one singleton per settings file (*Settings.qml) and SettingsFile
theme/           Colors, Metrics, Motion
state/           ShellState (the shell's state) and ScreenState (one per screen)
services/        one singleton per system domain, owning its processes
components/      what surfaces are built from: glass, controls, fields, Anim…
modules/         the surfaces, one folder each: bar, island, notifications,
                 controlcenter, lock, settings, capture, music, workspaces, airpods
windows/         ScreenShell, the window each screen draws in, and the Card contract
shaders/, data/  the shaders and the data files, found with Quickshell.shellPath()
```

- **Folders are modules.** Files import them (`import qs.services`), never by relative
  path. Both entry points stay at the root, because `qs` resolves from the folder of the
  file it runs.
- **A file lives where it's used.** One used by a single module lives in that module's
  folder, and moves to `components/` once a second module needs it.

## Services

- **A service owns its domain whole:** the state, the processes and files that feed it,
  and the actions on it. No surface runs a `Process`, reads a system file or calls a
  script. It asks the service.
- **A service works only while someone looks.** A surface that shows a service's values
  holds a `ServiceRef` while it's visible. The service polls and streams only while its
  count is above zero. Only duties that can't wait are always on: the notification
  server, the polkit agent, the portals, battery warnings, idle. Each service says which
  kind it is in its header.
- **A service's first values are a baseline, not a change.** It exposes `ready`, and
  nothing reacts to a change (an OSD, a sound, an animation) before `ready`. This
  replaces every `volumeInitialized`, `micStateInitialized` and `powerEventsReady` of
  the old code.
- **Logic about the system lives in its service, not in a surface.** The battery's
  warning stages, the time left, the network's icon and the OSD to show on a volume
  change are computed once in their services, not once per screen in the bar.

## Shell state

State that more than one surface needs lives here; state only one surface needs stays
in that surface (a card's preview, its pinned state, the page shown).

- **`ShellState`** holds what spans screens: do not disturb, caffeine, screenshots, the
  AirPods OSD, and the surfaces that belong to no screen (the settings window).
- **`ScreenState`**, one per screen (a `Variants` in `ShellState`), holds that screen's
  island and the way to its surfaces. `ShellState.forScreen(screen)` and
  `ShellState.focused()` find it.
- **Opening is a call, not a broadcast.** A surface registers under its name on its
  screen (`register`), and `screenState.open(name)`, `close` and `toggle` reach it
  through its `requestAction(action, origin)`. The IPC commands, the launcher and
  the services make the same calls. No request counters, no signal every panel filters.
  Only the prompts open over a fullscreen window. A panel opened from another goes back
  to it on Escape (`return`), which keeps its own way back.
- **The island has one owner at a time, by claim.** A surface that wants the island on a
  screen claims it with a rank:
  1. the prompts an app waits on (polkit, file chooser, screen share): first come,
     never pushed away;
  2. the panels you open, and the calendar: the last one takes the island, and the one
     it takes it from closes. None opens while a prompt holds it;
  3. the cards that come on their own (notifications, AirPods): first come, and they
     wait while anything else holds it.

  `islandOwner` is the first prompt, else the panel, else the first card. An island
  panel is open exactly while it owns the island, so it can't disagree with the state.
  `IslandFrame` follows the open card. The OSD and the chips aren't claims: they never
  wait their turn, they're the island at rest. The OSD shows in the island while nobody
  holds it, and beside the card that does otherwise.

## Surfaces and windows

- **One window per screen** (`ScreenShell`) draws the bar and every card, so a pill and
  its card change in the same frame. A card follows the `Card` contract and never gets a
  window of its own. The only other windows are the lock (a session lock, required by
  Wayland), the settings window (a real window you can move) and the desktop's music
  wave (its own process, so the shell's stalls never freeze it).
- **The shell's window is never resized:** Hyprland shows a resized layer's new buffer
  in its old box for a frame.
- **Blur is asked for shape by shape, by a window no bigger than it needs.** Hyprland
  blurs the whole of a window that asks for blur, again at every frame something moves
  behind it. So the pills' blur belongs to a second window of the bar's size that draws
  nothing (a glass on the desktop puts a `BlurShape` in itself), and the shell's window
  only asks for its open cards' (`Card.cardRect`). Never a blur rule on a full-screen
  layer: it cost a third of the graphics card all through a wallpaper's transition.
- **What's closed costs nothing, and opens without a stall.** A card's content is built
  off the critical path: by an asynchronous `Loader` once the bar has its first values.
  Then it's kept. While closed, its content is `visible: false`, holds no `ServiceRef`,
  and nothing in it animates, recomputes a list or keeps a live `ShaderEffectSource` or
  layer.
- **A surface is a view.** It binds to services and state, and holds only presentation
  state of its own: the selected entry, the scroll, the page.

- **Pages go in and back out the way you came.** A panel with pages (the control
  center) keeps the pages you went through as a history (`PageStack`): back is always
  the page before, never a rule written per page. A page with a subject (a network, a
  device) takes it in its own `show()`, and runs what it follows (a scan) only while
  it's shown in an open panel.

## Motion

- **Every animation takes its timing from `Motion`.** No duration or easing is written
  anywhere else. The tokens are named by what the element does:

  | Token | For |
  |---|---|
  | `move` | an element going somewhere |
  | `resize` | a shape growing or shrinking |
  | `enter` | an element appearing (decelerates) |
  | `leave` | an element going away (accelerates, shorter) |
  | `color` | a color or an opacity changing |
  | `bounce` | an answer to a press (`BounceAnimation`) |
  | `settle` | a card's shape going a little past its size, then back (`CardSettle`) |
  | `drop` | a pill that comes and goes from above the bar: it falls in and bounces, then flies back up |
  | `pulse` | something breathing on its own while a state lasts |

  The first five come in `small`, `normal` and `large`, by the distance travelled, and
  are played with `Anim` and `ColorFade` (`Anim { token: Motion.leave.small }`,
  `ColorFade on color { token: Motion.color.small }`). A color only fades for a change
  of state: a new palette lands at once everywhere, and `ColorFade` lets it through.
  `bounce`, `settle`, `drop` and `pulse` are gestures of their own, each with its
  components.
- **Springs for what follows a moving target.** A value that can change while it
  animates (a drag, a size that changes mid-animation) follows it with a spring, which
  keeps its speed when the target moves. A transition between two fixed states uses a
  curve.
- **Every animation can be interrupted.** It starts from the current value, never from
  where it would have been, and a reversed animation turns back smoothly.
- **What stays keeps living.** When the screen changes from one view to the next, each
  element is one of three kinds:
  - in both views: it moves and resizes to its new place;
  - only in the old view: it leaves;
  - only in the new view: it enters.

  A view never fades out whole to bring the next one in. When a shared element has to
  cross into another surface (the bar's pills into the lock), its twin starts exactly
  where it is, in the same frame, and it crosses while at rest. Coming back, the bar
  can't draw under the lock and would show a stale frame as it goes: the lock hands
  its island, at rest, to a window made for that moment (LockRelay), whose first frame
  shows until the bar draws again.
- **Nothing hidden animates.** An animation on something you can't see costs frames on
  what you can.
- **Each screen animates at its own refresh rate.** Qt has one animation clock per
  process; the HyprPunk.Frames plugin (`frames/` in the dotfiles) moves it with each
  window's frames, so a 120 Hz screen gets 120 states a second and a screen where
  nothing moves doesn't draw. Each window draws one frame at a time, at its screen's
  beat, and the swap never waits for a screen, so a 60 Hz screen doesn't hold the
  120 Hz one back. Both shells import it (`shell.qml`, `VisualizerShell.qml`).

## Looks

- **Colors are roles** (`Colors`, from matugen), as CLAUDE.md says.
- **Sizes are tokens.** The text scale, the spacing grid (4 px), the corners and the
  pill and card sizes come from `Metrics`, so the shell keeps one rhythm. A size written
  by hand is one the design doesn't know about.
- **Nested corners stay parallel.** A rounded shape inside another takes
  `Metrics.inner(outer, inset)`, never the same radius as its parent.
- **Shared looks are shared components.** Glass, fields, rows, toggles, sliders and the
  bounce exist once in `components/`. A surface that needs something new adds it there
  if anything else could use it.

## Settings and scripts

- **Each settings file has one writer, its script** (`hyprpunk <domain> set …`), so the
  shell and your terminal change settings the same way. The script also owns the
  defaults, written on install and update.
- **The shell only reads settings,** through its `config/` singleton. It writes them by
  calling the script through that singleton, never directly.
- **Scripts do one domain each.** One that grows past what one domain needs gets split,
  like the shell's services.

## Checking a change

- **Every state:** first start, restart, two screens, a screen plugged in and out, no
  battery, no Bluetooth, no player, empty and huge lists.
- **Every palette, and long text.**
- **Animations:** interrupted, reversed, two at once, while the other screen animates.
- **Display glitches:** the first frame, resizes, blinks between a pill and its card.
- **Measure on a freshly restarted shell,** with the methods in the project's memory:
  frame diffs with wf-recorder, stall timers, startup stamps.
