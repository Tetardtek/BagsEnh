# Changelog

All notable changes to BagsEnh are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-07-21

### Added
- **Bank views** — a categorized window for every bank type on Ascension,
  reusing the whole engine (categories, colours, item level, unlearned
  appearance):
  - **Character bank** (main bank + the 7 bank bag slots), container-based, with
    native item behaviour (click / tooltip / shift-move to bags).
  - **Guild / Personal / Realm bank** — Ascension routes all three through the
    guild bank API; BagsEnh detects the type and shows **every tab merged into a
    single categorized view**, so there's no more sorting by tab.
- **Bank search** — filter bank contents just like the bags.
- **Bank interaction** — left-click to pick up / deposit onto a slot,
  right-click to withdraw a stack to your bags, and **drop an item on the window
  to deposit** it (the merged view shows no empty slots, so this is how you put
  things in). Shift / Ctrl keep the native modified click (chat link, dress-up).
- **Hide the default bank window** (Display panel) — the native bank and guild
  bank frames are stowed off-screen while BagsEnh drives the bank. On by default.

### Notes
- Bank contents are read while the bank window is open at the banker; an offline
  cache (browse a bank while away from it) is planned for a later release.

## [1.2.0] - 2026-07-21

### Added
- **Display panel** ("Affichage") — a dedicated options page gathering the
  content toggles (item level, unlearned-appearance grouping) and the new
  grouping controls in one place.
- **Configurable gear grouping** — equipment and the "Unlearned Appearance"
  section can be sub-grouped by *Material + slot*, *Material only*, *Slot only*,
  or *None (flat)*, saved in profiles. Equipment now shows a two-level layout by
  default (material → equip slot, e.g. Leather → Gloves → items) so identical
  slots line up; the appearance section stays flat by default to save space.

### Changed
- **Visual pass**: flat dark panel with a thin accent-tinted border, a proper
  title bar closed by dividers, header buttons aligned in a chain (no more magic
  offsets), category headers tinted per category with a colour dot, and a
  fade-in when the window opens. The equipped-bags popup matches the new style.
- The item level and unlearned-appearance toggles moved from the main panel to
  the new Display panel.

### Fixed
- Login init is now resilient: an options-panel module that fails to load (for
  instance a newly added file on a stale `.toc`) can no longer abort addon setup
  (hooks, profiles) and leave the bags non-functional.

## [1.1.0] - 2026-07-21

### Added
- **OneBag view** — a flat single-grid layout of every slot in bag order,
  empty slots included, so free space is visible and items can be dropped
  straight into a real bag slot. Toggle from the header button or `/be view`;
  the mode is saved and travels in profiles.
- **Item level** drawn on gear icons (top-right, coloured by rarity), shown
  only for equippable items. Toggle in the options panel.
- **Equipped-bags popup** (header "Bags" button): the backpack plus the four
  equipped bag slots with free/total counts. Left-click a slot to swap the bag
  natively, hover a bag to highlight its slots in the grid, and **Empty** a bag
  to move its whole contents into your other bags (bag-family aware, aborts in
  combat, disabled when already empty).
- **Custom categories** — create, rename, and delete your own sections in the
  Custom Categories panel, then file items into them via the item's `+` badge.
  They appear in the move menu, the section-order panel, physical sort, and
  profiles. Deleting one purges every reference to it.
- **Unlearned Appearance** category (Ascension wardrobe) — gear whose appearance
  you haven't collected yet is grouped on its own, checked live and pinned first;
  once you learn the appearance it returns to its normal category automatically
  (`APPEARANCE_COLLECTED`). Toggle in the options panel.

### Changed
- **Physical sort** now lays items last-to-first (reversed order) and is shown
  only in the OneBag view, where the real slots — and the result of the sort —
  are actually visible.
- The **Custom Categories panel** was reworked: a "your categories" section for
  creating/managing your own categories, above the existing name-pattern rules
  (whose target can now be one of your custom categories).

## [1.0.0] - 2026-07-05

### Added
- Unified bag window replacing the default bags: multi-column flow, resizable,
  draggable, mouse-wheel scrolling.
- Smart categories with sub-categories (weapon type / armor material / trade
  goods) from the client's own item data, plus Ascension-specific categories.
- Collapsible sections and a customizable section order.
- Per-item control via the `+` badge (move to a category or hide), custom
  name-pattern rules, instant search, and a defensive physical sort engine.
- Quality-coloured icon outlines and the new-item glow (autonomous detection
  plus the LootEnh bridge).
- Profiles: save / load / delete, Base64 export / import, per-character
  auto-load.
- English (enUS) and French (frFR) localization.

[2.0.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v2.0.0
[1.2.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v1.2.0
[1.1.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v1.1.0
[1.0.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v1.0.0
