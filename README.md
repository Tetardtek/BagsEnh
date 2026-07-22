# BagsEnh

A World of Warcraft addon for **Ascension WoW** (3.3.0) that replaces the default
bags with a single unified window: smart categories, sub-categories for gear and
trade goods, instant search, physical sorting, categorized **bank** views (incl.
the guild / personal / realm banks), and full customization — with **no external
dependencies**. Part of the **Enh** series (sister addon of
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

### Bank (Ascension)
- Opens a categorized window at the banker for **every bank type**: character
  bank, and the guild / personal / realm banks
- Guild-style banks show **all tabs merged into one categorized view** — no more
  hunting tab by tab
- **Search**, plus full interaction: click to pick up / withdraw, right-click to
  withdraw a stack, drop an item on the window to deposit
- **Resizable** (drag the grip), same sub-grouping as the bags
- The default bank window is hidden while BagsEnh drives it (toggle in Display)

### Warehouse (cross-character)
- `/be alts` opens a **read-only** window to browse any character's bags and
  banks (character / personal / realm / guild) from anywhere — no NPC needed
- Character + container pickers, search, resizable; **open several at once**
- Backed by an account-wide cache that fills in as you play each character

### Currencies
- Watched game currencies and **pinned item-currencies** show next to the gold
- Pin any item as a currency from its **+ badge** — it joins a **Special**
  section and its count appears in the footer
- Hover a currency (or the gold) for a **per-character breakdown and total**;
  mark shared currencies **account-wide** so they're shown once, not summed

### Smart categories
- Built-in categories: Equipment, Consumables, Gems, Profession & Trade, Quest,
  Junk, Miscellaneous, plus Ascension-specific (Worldforged, Mystic Scrolls…)
- **Unlearned Appearance** (Ascension): gear whose appearance you haven't
  collected yet is grouped and pinned first; it returns to its normal category
  once you learn the appearance
- **Your own categories**: create, rename, and delete custom sections, then
  file items into them (via the + badge or a name rule)
- **Configurable gear grouping**: sub-group equipment (and the appearance
  section) by *material + slot*, *material*, *slot*, or *none* — line up all
  your gloves, or keep it compact, your call
- **Promote trade goods**: give any material (Herbs, Ore, Leather, Cloth,
  Enchanting mats…) its own top-level section, ordered by profession
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
| `/be alts` | Open a cross-character warehouse window (read-only) |
| `/be view` | Switch between the categorized and OneBag layouts |
| `/be toggle` | Switch between BagsEnh and the default Blizzard bags |
| `/be sort` | Sort bags physically |
| `/be reset` | Recenter the window |

## Configuration

**Escape → Interface → AddOns → BagsEnh**:

- **BagsEnh** — unified view toggle, window scale, items per row, icon size,
  icon spacing, profiles (save/load/export/import)
- **Display** — item level on gear, group unlearned appearances, hide the
  default bank window, how equipment / the appearance section are sub-grouped
  (material + slot, material, slot, or none), and which trade goods get promoted
  to their own category
- **Currency** — footer display, cross-character total, and the list of tracked
  currencies with a per-currency "account-wide" flag
- **Custom Categories** — create/rename/delete your own categories, plus
  name-pattern rules
- **Section Order** — reorder categories

## Requirements

- WoW Client 3.3.0 (Ascension / Project Ascension)
- No external library dependencies

## License

[MIT](LICENSE)
