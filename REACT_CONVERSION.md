# React conversion pattern

How to convert a template-Instance view module to React. Reference
implementation: `src/shared/DialogueView.lua` + `src/shared/DialogueView.spec.lua`
(converted from the template tree recorded in
`ui-reference/ModuleTemplates/DialogueView.json`).

## The pattern

1. **Public API stays byte-compatible.** Before converting, grep the whole of
   `src/` for the module name and catalog every consumer touchpoint: methods,
   signals, and especially any direct pokes into the view's GUI children from
   outside the module. Instance names and hierarchy paths that outsiders (or
   specs) rely on must keep working.
2. **Host instance is imperative, contents are React.** `new()` creates the
   template root instance manually (copy its properties from the ui-reference
   JSON), then mounts the contents with `StatefulRoot.create(host, Component,
   initialState)` from `src/shared/Components/StatefulRoot.lua`. `GetGui()`
   returns the host. `SetVisible` and friends that touch only the host stay
   imperative.
3. **Every `Set*` method becomes a `setState` call.** State is a flat table;
   the render component is a pure function of it. Use `StatefulRoot.None` to
   clear a key (nil values can't be expressed in a merge table). Event
   callbacks (button clicks) go into the initial state once; they fire the
   view's signals just like the old connection code did.
4. **Property fidelity comes from ui-reference JSON.** Omit properties that
   match the class default. Preserve behavioral quirks of the original code
   faithfully (e.g. DialogueView's swapped button labels) — note them with the
   original's comment if it had one.
5. **Shared styled widgets become components.** If a template snippet is
   styled identically across views (the Win98 button/slider/tab set), make a
   React component in `src/shared/Components/` (UpperCamelCase file returning
   the component function). The old imperative module (e.g. `WindowsButton.lua`)
   stays untouched until its last template-based consumer is converted.
6. **Specs.** `<Name>.spec.lua` beside the module. Use the `withView` helper
   pattern from `DialogueView.spec.lua`: mount into a ScreenGui in CoreGui,
   wrap `new()` and every state-changing call in `ReactRoblox.act`, always
   unmount+destroy in cleanup. Cover the mount structure and each `Set*`
   method's observable effect. Specs require modules via
   `game.ReplicatedStorage.X` — never relative paths.
7. **Conventions:** `--!strict`, `React.createElement` aliased as `e`,
   `mMutableState`/`kConstant` naming, requires via `game.ReplicatedStorage.*`
   (this includes `game.ReplicatedStorage.Packages.React`).

## What conversion does NOT include (orchestrator steps)

- Running `python runtests.py` (single shared port/place).
- Deleting the template instances from the place, or removing the module's
  `.meta.json` file — done after tests pass.
- Committing.

## State of the conversion

Converted: SoundManager (code-defined sounds, no React needed), DialogueView.
Everything else still clones templates.
