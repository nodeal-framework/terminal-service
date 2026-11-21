# Engineering Conventions — Luau & Rovue (TWW)

This is the single source of truth for how we write Luau in this project. It is written
for both humans and AI assistants.

**Priority:** a direct instruction in the current task overrides this file. If the
codebase conflicts with this guide, stop and report the conflict; do not silently pick a side.

**How to read it:** the Quick reference is the summary. Sections 1–5 are the rules;
section 6 is a full example to copy when creating or restructuring a module.

**Sections:** [Quick reference](#quick-reference) · [Golden rule](#1-golden-rule-no-forced-casts) ·
[Naming](#2-naming) · [Documentation](#3-documentation) ·
[Language](#4-language-and-comments) · [Formatting](#5-formatting) ·
[Module structure](#6-module-structure) · [Logic and Git](#7-logic-integrity-and-git-safety) ·
[AI assistants](#8-working-with-ai-assistants)

## Quick reference

| Topic | Rule |
| --- | --- |
| Pragmas | Never add `--!strict` or `--!nonstrict`. |
| Casts | Never use `::` inside a function body. |
| Types | Declare shapes with `export type`; annotate parameters and returns. |
| Services / instances | `PascalCase` (`Players`, `Humanoid`, `CurrentCamera`). |
| Classes, modules, public members | `PascalCase` (`Shell`, `CommandContext`, `Shell:RunSimple`). |
| Locals, primitive parameters, privates | `camelCase` (`deltaTime`, `playerCount`, `_commands`). |
| Constants | `SCREAMING_SNAKE_CASE` (`MAX_STEPS`, `DEFAULT_PRIORITY`). |
| Booleans | Prefix with `is`, `has`, `can`, `should`, `did`. |
| Language | English only: code, comments, docs, logs. |
| Function docs | A `--[=[ ... ]=]` block with summary, `@param`, `@return`. |
| Module layout | License, services, requires, types, constants, module, private, public, `return`. |
| Logic | Never change behavior while editing style. Git is the reference. |
| Done | `rovue check --strict` passes, `rovue build` succeeds, changed files reported. |

---

## 1. Golden rule: no forced casts

- **No pragmas.** Never add `--!strict` or `--!nonstrict`; write standard Luau.
- **Never use `::` in a function body.** Not for `any`, not for Roblox instances, not to
  silence the type checker.

```luau
-- ❌ Wrong
return (self :: any) :: HolsterObject
local Part = model:FindFirstChild("Part") :: BasePart
local value = (Value :: any)
local Module = {} :: CustomModule

-- ✅ Right
return self
local Part = model:FindFirstChild("Part")
local value = Value
local CustomModule = {}
```

- **Typing is declarative.** Describe shapes in `export type` blocks and annotate
  signatures; never assert types in the middle of logic.

```luau
export type UpdateOptions = {
	DeltaTime: number,
	FadeTime: number?,
}

function Module.Update(self: Module, deltaTime: number, fadeTime: number?): ()
```

If the type checker disagrees, fix the data flow or the annotation. A cast hides the bug
the checker just found.

---

## 2. Naming

Spell words out fully. Abbreviations save typing but cost every future reader.

| Style | Use for | Examples |
| --- | --- | --- |
| `PascalCase` | Roblox services and instances, classes, module tables, public fields and methods, and any variable or parameter holding one | `Players`, `RootPart`, `Shell`, `SwimController.AddZone`, `VolumePart: BasePart` |
| `camelCase` | Locals, parameters and private helpers holding primitives (numbers, strings, booleans, buffers, offsets) | `deltaTime`, `targetPosition`, `verticalMargin`, `isActive` |
| `SCREAMING_SNAKE_CASE` | Module-level constants | `MAX_STEPS`, `DEFAULT_PRIORITY` |
| `_camelCase` | Private module state that must not be exposed | `_commands`, `_historyMax` |

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RootPart = Character.HumanoidRootPart
local Humanoid = Character:FindFirstChild("Humanoid")

local deltaTime = 0.016
local speedMultiplier = 1.5
local isOwner = true

local DEFAULT_PRIORITY = 500
local MAX_BUFFER_CAPACITY = 65536
```

The distinction follows the value, not the position: `VolumePart: BasePart` and
`WorldPosition: Vector3` are PascalCase, while `verticalMargin: number` and
`fadeTime: number` are camelCase.

- **Booleans** carry their meaning in the prefix: `isActive`, `hasWaterCollision`,
  `canJump`, `shouldFollow`, `didSpawn`.
- **Acronyms are words:** `jsonValue`, `makeHttpCall`, `idToken`. Keep a set capitalized:
  `anRGBValue`, `getXYZ`.
- **Files and folders match the exported table:** `Shell/init.luau` returns `Shell`.
  Use `init.luau` when the folder itself is the module; one module per file.

---

## 3. Documentation

Every function — constructor, public method, local helper, callback — gets a standard
Luau Doc block directly above its signature, written in English.

```luau
--[=[
	Brief one-line summary of what the function accomplishes.

	Detailed description when the function involves complex mathematics, physics,
	network replication, state machines, or a non-obvious invariant.

	@param paramName Description of this parameter.
	@param optionalParam Optional parameter description.
	@return Description of what is returned.
	@yields
	@example
		local instance = MyModule.new(Character)
		instance:Update(0.016)
]=]
```

| Tag | Purpose |
| --- | --- |
| `@param <name> <description>` | Semantic meaning. The type is already in the signature. |
| `@return <description>` | Semantic meaning of the return value. |
| `@yields` | Marks a function that can yield or suspend the thread. |
| `@example` | A concrete usage example. |

The summary is mandatory. Describe intent and edge cases, not syntax.

---

## 4. Language and comments

- **100% English.** Names, types, comments, docstrings and logs are English. No French
  terms in source files.
- Comments explain **why**, not what. If the code already says it, delete the comment.
- Every module starts with a block comment explaining why the file exists and what it owns.
- Section markers in the repository style are allowed and encouraged in large modules:
  `--// Services //--`, `--// Modules //--`, `--// Private //--`, `--// Public //--`.
  Do not use them to avoid splitting a genuinely oversized file.

---

## 5. Formatting

- Indent with **tabs** (four columns wide).
- Keep code lines under **100 columns**; wrap comment prose at **80**.
- Prefer **double quotes**. Use single quotes only when it avoids escapes.
- One statement per line; put function bodies on their own lines.
- No semicolons.
- Add trailing commas in multi-line tables.
- Use a single blank line between logical groups; do not start a block with a blank line.
- End every file with a newline.

---

## 6. Module structure

Every `init.luau` follows this order:

1. The standard Nodeal license header (copy it from an existing module; never remove it).
2. A block comment describing the module's purpose.
3. Services, via `game:GetService`.
4. Module dependencies, via `require`.
5. Types, via `export type`.
6. Constants.
7. The module table and its `__index`.
8. Private functions.
9. Public methods.
10. `return` the module table.

```luau
--[=[
	Manages custom physics-driven swimming mechanics and swimmable volume zones.
]=]

--// Services //--
local Players = game:GetService("Players")

--// Modules //--
local Global = require(script.Parent.Global)

--// Types //--
export type SwimController = {
	Swimming: boolean,
	DragForceMultiplier: number,
	Zones: { BasePart },
	Character: Model?,

	AddZone: (self: SwimController, ZonePart: BasePart) -> (),
	Start: (self: SwimController) -> (),
}

--// Constants //--
local DEFAULT_DRAG_FORCE_MULTIPLIER = 9.85

--// Module //--
local SwimController = {
	Swimming = false,
	DragForceMultiplier = DEFAULT_DRAG_FORCE_MULTIPLIER,
	Zones = {},
}
SwimController.__index = SwimController

--// Private //--

--[=[
	Checks whether a world position is inside the bounding box of a volume part.

	@param VolumePart The part representing the water volume.
	@param WorldPosition The point in world space to test.
	@param verticalMargin Optional vertical tolerance margin.
	@return True when the point is within the bounding box.
]=]
local function isPositionInPart(VolumePart: BasePart, WorldPosition: Vector3, verticalMargin: number?): boolean
	local localPos = VolumePart.CFrame:PointToObjectSpace(WorldPosition)
	local partSize = VolumePart.Size
	local margin = verticalMargin or 0

	return math.abs(localPos.X) <= partSize.X / 2
		and math.abs(localPos.Y) <= (partSize.Y / 2 + margin)
		and math.abs(localPos.Z) <= partSize.Z / 2
end

--// Public //--

--[=[
	Registers a swimmable volume zone.

	@param ZonePart The volume part representing water.
]=]
function SwimController.AddZone(self: SwimController, ZonePart: BasePart): ()
	if not table.find(self.Zones, ZonePart) then
		table.insert(self.Zones, ZonePart)
	end
end

--[=[
	Initializes character listeners, heartbeat loops, and swimming updates.
]=]
function SwimController.Start(self: SwimController): ()
	-- Implementation...
end

return SwimController
```

---

## 7. Logic integrity and Git safety

- **Never alter logic while editing.** Physics, calculations, network protocols, binary
  buffer layouts and state machines must behave exactly as before unless the task is
  explicitly about changing them.
- **Git is the absolute reference.** Use `git diff` and `git checkout` to compare or
  restore the original version of `package/src`.
- **No unnecessary CLI churn.** Do not run `rovue build` or other blocking commands in a
  loop while editing. Run validation once before declaring the work finished.
- Do not rewrite, rename or reformat code unrelated to the request.

---

## 8. Working with AI assistants

These rules apply to humans and agents alike. An AI assistant should:

- Read the target file and at least one neighboring module before editing.
- Match the local style. If the code conflicts with this guide, report it; do not guess.
- Make the smallest diff that solves the task.
- Never add dependencies, change a public API, remove the license header, or edit
  generated artifacts (`.rbxm`, `sourcemap.json`) without asking.
- Never introduce `::`, pragmas, French text, or undocumented functions.
- Ask when the requirement is ambiguous; do not invent a convention.

### Definition of done

1. `cd package && rovue check --strict` passes.
2. `cd package && rovue build` succeeds.
3. New functions have Luau Doc blocks.
4. The final report lists changed files, checks run, and anything intentionally skipped.

### Boundaries

- Do not commit or push unless asked.
- Do not modify `.gitignore`, license text, or release artifacts without approval.
- Do not delete tests or validation code to make a check pass.
