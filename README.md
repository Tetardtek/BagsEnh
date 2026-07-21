# BagsEnh

A World of Warcraft addon for **Ascension WoW** (3.3.0) that replaces the default
bags with a single unified window: smart categories, sub-categories for gear and
trade goods, instant search, physical sorting, and full customization — with **no
external dependencies**. Part of the **Enh** series (sister addon of
[LootEnh](https://github.com/Tetardtek/LootEnh)).

## Features

### Unified bag view
- One window replaces all your bags, items grouped by category
- **Two layouts, one click**: categorized view or **OneBag** (a single flat
  grid of every slot in bag order, empty slots included) — toggle from the
  header or `/be view`
- **Multi-column flow**: sections spread across the window width and rebalance
  as you resize — more width, more columns
- Fully **resizable** window (drag the bottom-right grip), draggable, position
  and size saved
- Mouse-wheel scrolling — the content never overflows
- **Item level** shown on gear icons (coloured by rarity)

### Bag management
- **Bags** popup: the backpack plus the four equipped bag slots with their
  free/total counts
- Left-click a slot to **swap** the bag, hover a bag to **highlight its slots**
  in the grid, or **Empty** a bag into your others (bag-family aware, aborts in
  combat)

### Smart categories
- Built-in categories: Equipment, Consumables, Gems, Profession & Trade, Quest,
  Junk, Miscellaneous, plus Ascension-specific (Worldforged, Mystic Scrolls…)
- **Unlearned Appearance** (Ascension): gear whose appearance you haven't
  collected yet is grouped and pinned first; it returns to its normal category
  once you learn the appearance
- **Your own categories**: create, rename, and delete custom sections, then
  file items into them (via the + badge or a name rule)
- **Sub-categories** from the client's own item data (localized):
  - Equipment → weapon type / armor material, sorted by equip slot
  - Profession & Trade → Leather / Cloth / Herb / Cooking / Metal & Stone…
- **Collapsible** sections — click a header to fold it
- **Custom section order** — arrange categories however you like

### Per-item control
- Hover an item and click the **+ badge** to move it to any category or hide it
- Hidden items get their own collapsible section (toggle in the footer)
- **Custom rules** by name pattern (e.g. "Scroll" → Consumables), longest match
  wins, shift-click an item to auto-fill its name

### Search & sort
- Instant **search** — type to dim non-matching items (slots stay in place)
- **Sort** button (OneBag view) — physically reorganizes your bags by category,
  safe defensive engine that aborts in combat

### Quality theming
- Colored outline around item icons by rarity
- Cropped icons (no baked-in border)

### New-item glow
- Freshly looted items glow — detected autonomously (bag diff) and enriched by
  LootEnh when both are installed
- Cleared when you hover the item or close the bags

### Profiles
- Save / Load / Delete named profiles
- **Export / Import** as Base64 strings (share your layout)
- Auto-load per character

### Localization
- English (enUS) and French (frFR)

## Installation

1. Download or clone this repository
2. Copy the `BagsEnh` folder into your `Interface/AddOns/` directory
3. Restart WoW (a full restart, not just `/reload`, on first install)

## Slash Commands

| Command | Action |
|---------|--------|
| `/be` | Toggle the bag window |
| `/be view` | Switch between the categorized and OneBag layouts |
| `/be toggle` | Switch between BagsEnh and the default Blizzard bags |
| `/be sort` | Sort bags physically |
| `/be reset` | Recenter the window |

## Configuration

**Escape → Interface → AddOns → BagsEnh**:

- **BagsEnh** — unified view toggle, window scale, items per row, icon size,
  icon spacing, item level on gear, group unlearned appearances, profiles
  (save/load/export/import)
- **Custom Categories** — create/rename/delete your own categories, plus
  name-pattern rules
- **Section Order** — reorder categories

## Requirements

- WoW Client 3.3.0 (Ascension / Project Ascension)
- No external library dependencies

## License

[MIT](LICENSE)
