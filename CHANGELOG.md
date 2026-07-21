# Changelog

All notable changes to BagsEnh are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.1.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v1.1.0
[1.0.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v1.0.0
