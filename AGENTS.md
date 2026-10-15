# AGENTS.md - Afterlight: 2099

Android-first, portrait, 2D UI crafting/colony game in **Godot 4.x** (GDScript).

## Sources of truth
1. `docs/implementation_plan.md` - architecture, schemas, sprint roadmap.
2. `Ref/index.html` - the HTML prototype. UI layout, interactions and visual style follow it.
3. Where the two disagree, this file's decisions win; ask the user before deviating.

## Decisions (Task 1)
- Engine: project is saved with Godot 4.7. Keep code compatible with 4.3+ (no 4.4+-only APIs).
- Viewport: `1080x2340` portrait, stretch `canvas_items`, aspect `expand`.
- Renderer: `gl_compatibility` (widest Android device support). 2D only; no physics needed.
- **Item ids are the single source of truth.** Recipes, inventory and quests reference ids (`raw_mineral`),
  never display names. Display names live only in `data/items.json`.
- Gameplay content (items, recipes, quests) is data-driven from `res://data/*.json`. No hardcoded content in scripts
  except temporary starter seeding in `InventoryManager`.
- Writable/save data goes to `user://` (`res://` is read-only on Android).

## Architecture
- Autoloads (`scripts/autoloads/`): `GameState`, `InventoryManager` (more per plan later).
- UI scripts in `scripts/ui/`; scenes in `scenes/` (`hud/`, `modals/`, `components/`).
- Communicate via signals; UI never mutates state directly, it calls autoload methods.
- Static typing in GDScript where practical. Tabs for indentation (see `.editorconfig`).

## Android / portrait rules
- Touch targets >= 48dp equivalent (inventory slots are 160px at the 1080 base width).
- Handle taps through `Button.pressed`; no hover-only behaviour.
- Layout with Containers and anchors; never absolute positions. Respect safe area/notches.
- No emoji reliance long-term: current slots use emoji glyphs as placeholder icons (`glyph` in items.json).
  Replace with PNG/SVG in `assets/sprites/icons/` using the `icon` field.
- Handle Android back button and app pause (save) when those systems arrive.

## Workflow
- Implement one sprint/task at a time; do not build ahead of the approved task.
- Do not edit `.godot/`. Do not commit export keystores.
- Preserve existing comments/docs unrelated to your change.
