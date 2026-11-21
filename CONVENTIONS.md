# Conventions de Cleanification & Standard Luau (TWW / Rovue)

Ce document définit les règles strictes, standards de nommage, documentation Luau et architecture appliqués.

---

## 1. Règle d'Or : Zéro Cast Forcé (`::`)

- **AUCUN PRAGMA (`--!strict` / `--!nonstrict`)** : Ne pas ajouter de pragmas en tête de fichier, laisser le code Luau standard sans directive.
- **INTERDICTION STRICTE D'UTILISER L'OPÉRATEUR `::` DANS LE CORPS DU CODE** :
  - ❌ `return (self :: any) :: HolsterObject` -> ✅ `return self`
  - ❌ `local Part = model:FindFirstChild("Part") :: BasePart` -> ✅ `local Part = model:FindFirstChild("Part")`
  - ❌ `(Value :: any)` -> ✅ `value`
  - ❌ `local Module = {} :: CustomModule` -> ✅ `local CustomModule = {}`
- Le typage Luau doit être **déclaratif** :
  - Dans les blocs `export type ...`.
  - Dans les signatures de fonctions : `function Module.Update(self: CustomModule, deltaTime: number): ()`.
- Ne jamais encombrer le code avec des assertions de type ou du casting forcé.

---

## 2. Standards de Nommage (Naming Conventions)

### 2.1 Instances Roblox, Services & Classes : `PascalCase`
Toutes les variables représentant des **Instances Roblox**, des **Classes**, des **Services**, ou des **Objets OOP** doivent impérativement être en `PascalCase` :
- **Services Roblox** :
  ```luau
  local ReplicatedStorage = game:GetService("ReplicatedStorage")
  local RunService = game:GetService("RunService")
  local Players = game:GetService("Players")
  local TweenService = game:GetService("TweenService")
  local UserInputService = game:GetService("UserInputService")
  ```
- **Instances Roblox (Parts, Models, Humanoid, Attachments, Effects, etc.)** :
  - ❌ `local rootPart = character.RootPart`
  - ✅ `local RootPart = Character.HumanoidRootPart`
  - ❌ `local humanoid = character:FindFirstChild("Humanoid")`
  - ✅ `local Humanoid = Character:FindFirstChild("Humanoid")`
  - ❌ `local flameSound = template:Clone()`
  - ✅ `local FlameSound = TemplateSound:Clone()`
  - ❌ `local currentCamera = workspace.CurrentCamera`
  - ✅ `local CurrentCamera = workspace.CurrentCamera`

### 2.2 Variables Primitives & Valeurs Locales : `camelCase`
Les variables stockant des nombres, chaînes, booléens, buffers, ou offsets mathématiques :
- **Variables locales & calculs** : `deltaTime`, `timeElapsed`, `speedMultiplier`, `targetPosition`, `stepFraction`.
- **Paramètres de primitives** : `(deltaTime: number, fadeTime: number?, speed: number?)`.
- **Booléens** : Préfixés sémantiquement par `is`, `has`, `can`, `should`, `did`.
  - `isActive`, `isOwner`, `isDisabled`, `hasWaterCollision`, `canJump`.

### 2.3 Constantes : `SCREAMING_SNAKE_CASE`
- `local DEFAULT_PRIORITY = 500`
- `local MAX_BUFFER_CAPACITY = 65536`
- `local SOUND_FADE_TWEEN_INFO = TweenInfo.new(1)`

---

## 3. Documentation Standard Luau Doc (`--[=[ ... ]=]`)

**Chaque fonction** (constructeur, méthode publique, helper local, callback) doit comporter un bloc Luau Doc complet et standardisé au-dessus de sa signature, rédigé en **anglais intégral** :

### Format Requis :
```luau
--[=[
    Brief one-line summary of what the function accomplishes.
    Detailed description if the method involves complex mathematics,
    physics integration, network replication, or state machines.

    @param paramName Description of this parameter.
    @param optionalParam Optional parameter description.
    @return Description of what is returned.
    @example
        local instance = MyModule.new(Character)
        instance:Update(0.016)
]=]
```

### Balises Luau Doc Standards :
- `@param <name> [<description>]` : Description sémantique du paramètre (le type est déjà dans la signature).
- `@return [<description>]` : Description sémantique du retour (le type est déjà dans la signature).
- `@yields` : Indique si la fonction peut yield / suspendre le thread.
- `@within <ClassName>` : Indique l'appartenance à une classe ou un module.
- `@example` : Exemple concret d'utilisation.

---

## 4. Langue du Code (Full English)

- **100% Anglais** : Noms de variables, fonctions, types, commentaires, docstrings et logs doivent être exclusivement en anglais.
- Aucun commentaire ou terme français dans le code source.

---

## 5. Préservation 100% de la Logique & Sécurité Git

- **Intégrité absolue** : Ne jamais altérer la logique du code, les calculs physiques, les protocoles réseau, ou les layouts de buffers binaires.
- **Dépôt Git** : En cas d'erreur de manipulation ou de divergence, le dépôt `git` de `source/` sert de référence absolue pour vérifier les versions d'origine (`git diff`, `git checkout`).
- **Pas de vérifications CLI intempestives** : Pas besoin de lancer de builds rovue ou de commandes bloquantes en continu.

---

## 6. Structure Complète d'un Module Référence (`init.luau`)

Voici le modèle exact illustrant l'ensemble des conventions appliquées :

```luau
--[=[
    SwimController.luau
    Manages custom physics-driven swimming mechanics, surface buoyancy, water drag,
    and humanoid swimming state transitions within defined swimmable volume zones.
]=]

-- Services --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies --
local Global = require(ReplicatedStorage.SharedModules.Global)

-- Types --
export type SwimController = {
    Swimming: boolean,
    ClampSurfaceMovement: boolean,
    ProcessWeldedParts: boolean,
    DragForceMultiplier: number,
    SurfaceDepth: number,
    MaxJumpDepth: number,
    Zones: { BasePart },
    Character: Model?,
    RootPart: BasePart?,
    Humanoid: Humanoid?,

    AddZone: (self: SwimController, zonePart: BasePart) -> (),
    Start: (self: SwimController) -> (),
    Destroy: (self: SwimController) -> (),
}

-- Constants --
local DEFAULT_DRAG_FORCE_MULTIPLIER = 9.85
local DEFAULT_SURFACE_DEPTH = 0.35
local DEFAULT_MAX_JUMP_DEPTH = 2

-- Module Definition --
local SwimController = {
    Swimming = false,
    ClampSurfaceMovement = true,
    ProcessWeldedParts = true,
    DragForceMultiplier = DEFAULT_DRAG_FORCE_MULTIPLIER,
    SurfaceDepth = DEFAULT_SURFACE_DEPTH,
    MaxJumpDepth = DEFAULT_MAX_JUMP_DEPTH,
    Zones = {},
}
SwimController.__index = SwimController

-- Private Functions --

--[=[
    Checks if a given world position is contained within the oriented bounding box of a volume part.

    @param VolumePart The part representing the water volume.
    @param WorldPosition The point in world space to test.
    @param verticalMargin Optional vertical tolerance margin.
    @return True if the point is within the bounding box.
]=]
local function isPositionInPart(VolumePart: BasePart, WorldPosition: Vector3, verticalMargin: number?): boolean
    local localPos = VolumePart.CFrame:PointToObjectSpace(WorldPosition)
    local partSize = VolumePart.Size
    local margin = verticalMargin or 0

    return math.abs(localPos.X) <= partSize.X / 2
        and math.abs(localPos.Y) <= (partSize.Y / 2 + margin)
        and math.abs(localPos.Z) <= partSize.Z / 2
end

-- Public Methods --

--[=[
    Registers a new swimmable volume zone in the controller.

    @param ZonePart The volume part representing water.
]=]
function SwimController.AddZone(self: SwimController, ZonePart: BasePart): ()
    if not table.find(self.Zones, ZonePart) then
        table.insert(self.Zones, ZonePart)
    end
end

--[=[
    Initializes character listeners, heartbeat loops, and swimming physics updates.
]=]
function SwimController.Start(self: SwimController): ()
    -- Implementation...
end

return SwimController
```
