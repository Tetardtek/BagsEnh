# Changelog

All notable changes to BagsEnh are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.6.0] - 2026-08-02

### Changed
- **Version checking moved out of BagsEnh entirely.** It now lives in AllEnh, the
  hub, and nowhere else. BagsEnh keeps one line — it declares itself to the hub
  if the hub is there — plus `/be version`, which prints the release link.

  The protocol removed here only reached your **guild and your group**, so a
  player with neither was never told anything. It also carried a second copy of
  a version comparator the hub already had. Every way of keeping two copies
  identical came down to manual synchronisation dressed up as a guarantee.

  Checking a version is not a feature of BagsEnh; it is a feature of the suite.
  BagsEnh sorts your bags perfectly on its own, and that is what standing alone
  means. Without the hub you check the GitHub page, like any other addon — the
  link is at the top of the README.

## [2.5.0] - 2026-08-02

### Added
- **Sub-sections everywhere they mean something.** Until now only Equipment and
  Profession & Trade had a second level; the other ten categories received the
  item's subtype from the client and threw it away. Consumables now split into
  Potion / Elixir / Flask / Scroll / Food & Drink / Bandage, Miscellaneous into
  Junk / Reagent / Pet / Mount / Holiday, and gems, recipes, bags and glyphs
  group the same way. Nothing was misfiled — there simply was no second level.
- **Bags & Containers, Recipes and Glyphs** are categories of their own. These
  three native item classes were mapped nowhere and all landed in
  Miscellaneous. Recipes also leave Profession & Trade, where a thing you learn
  sat next to the ore it is used on.
- **Bloodforged (PvP) gear is never sold to a vendor.** On Ascension this gear
  grants a bonus in PvP and a *penalty* in PvE, and is worth far more at the
  auction house than at a merchant — where the sale cannot be undone. A group
  sell used to send it off with everything else. On by default, with a
  checkbox in the Display panel; the sell report states what was held back.

### Changed
- **Items are sorted by item level before name.** On gear, quality usually
  decides the order; on materials it is nearly constant, so sorting fell back
  to the alphabet — Linen, Mageweave, Runecloth, Silk, Wool instead of the
  tiers a player thinks in. Item level tracks the tier without any hardcoded
  table, so it holds for Ascension's own items too.
- All of the above applies to the bags, every bank and the cross-character
  warehouse at once: they share one layout engine since 2.1.0.

## [2.4.0] - 2026-08-02

### Fixed
- **Addon chat messages were never displayed.** `BagsEnh_Print`, introduced in
  2.3.1 as the single source of the chat prefix, called *itself* instead of the
  chat frame — every message of the addon ended in an infinite recursion. Sell
  reports, sort and compaction results, profile confirmations: none of them
  could ever reach the chat.
- **The French locale was never used.** `BagsEnh_L()` read `BagsEnhDB.lang`,
  which nothing ever wrote, and fell back to English. The 148 translated keys
  had never been shown once. The language is now resolved from the client
  (`GetLocale()`) unless explicitly set — see below.

### Added
- **Language selector** (main panel) — *Auto (client)*, English, Français. A
  client running in English can be played in French (translation provided by an
  addon), so client detection alone is not enough; an explicit choice is needed.
  Changing it prints a reminder to reload the UI, as already-built labels cannot
  be retranslated on the fly.
- **Compact button in the bag window** — mirrors the one in the character bank.
  The underlying `BagsEnh_MergeBagStacks` already existed and was only reachable
  through `/be merge`. Never hidden: it acts on the real slots, so it stays
  relevant in both views.
- **Selling limits for group actions** (Display panel) — a **max rarity** and a
  **max item level** (0 = no limit). Group selling never sells above either.
  Protects an epic from a stray modifier-click, where the previous guard only
  skipped items with no vendor value. The sell report now states how many items
  were kept back, so a section that does not sell is never mistaken for an empty
  one.
- **Group move by category and sub-category, both ways.** Withdrawing was
  missing entirely: a modifier-click on a section header in the bank window now
  sends the whole group back to the bags, the mirror of the existing deposit.
  Works on the character bank (container API) and on the guild / personal /
  realm banks (`AutoStoreGuildBankItem`, targeting the right tab first).
- Bank section headers and sub-headers are now buttons rather than plain frames
  and font strings, so they can carry that action.

### Fixed (context)
- **Deposit did nothing on the personal and realm banks.** Ascension routes
  guild, personal and realm banks through the guild bank API, and
  `GUILDBANKFRAME_OPENED` never set the bag-action context — so a
  modifier-click on a section found no context at all and stayed silent.

### Internal
- `*.zip` is now ignored. Tracked release zips were bloating the history and,
  worse, being packaged *inside* the next release archive: v2.3.1 shipped with
  v2.3.0 embedded (80 KB of dead weight for players).

## [2.3.1] - 2026-07-31

### Fixed
- Unified the per-character key used across the cache, currencies, warehouse and
  profiles — two slightly different formats had drifted apart. Existing
  per-character profile auto-load bindings are migrated automatically on login.

### Internal
- Removed dead code and routed all addon chat output through a single helper
  (`BagsEnh_Print`). No behaviour change.

## [2.3.0] - 2026-07-31

### Added
- **Contextual group actions (modifier + click)** — hold the modifier and click a
  section **or sub-section** header to act on the whole group, depending on the
  window open next to your bags: **sell** at a merchant, **deposit** at the
  character bank. Only items with a vendor value are ever sold (quest/no-value
  items are protected). The modifier key (**Ctrl / Alt / Shift**) is configurable
  in the Display options panel.
- **Collapsible sub-sections** — click a sub-section header (material / equip
  slot) to fold or unfold it; a collapsed material also hides its slot lines.
- **Stack compaction** — a **Compact** button in the character bank (and the
  `/be merge` command) merges partial stacks of the same item up to their max,
  freeing slots. Throttled and combat-safe (defensive state machine, no taint).
- **Shared realm bank** — the realm bank is now stored **once per server** and
  visible from **every character** of that realm via `/be alts`, even ones that
  never opened it. No more per-character duplication, and no cross-server mix.
- **Cached-character management** — remove obsolete alts from the cross-character
  cache: a quick **Remove** button (with confirmation) in the warehouse, plus a
  full list with per-character delete and **Clear all** in a new **Cached
  characters** options panel.
- **Version check** — the addon announces its version over guild/party; if a
  newer version is seen in play, you are pointed to the GitHub page once.
  `/be version` prints your version and the repository link.
- **Bank free-slot counter** — the character bank footer now shows free slots
  (`used/total (N free)`).

### Changed
- **Cleaner item icons** — the native slot frame that overlapped item icons has
  been removed; the quality-coloured border delimits each item on its own.

### Migration
- Existing per-character realm-bank snapshots are merged once into the new
  shared-per-server store on first load.

## [2.2.0] - 2026-07-22

### Added
- **Cross-character warehouse** — a read-only window (`/be alts`) to browse any
  character's bags and banks (character bank, personal, realm, guild) from
  anywhere, no NPC needed. Spawnable (open several at once), with a character +
  container picker, search and resizing. Backed by an account-wide cache that
  fills in as you play each character.
- **Gold across characters** — hover the gold in the bags footer for a
  per-character breakdown and grand total.
- **Currency system** — watched game currencies and pinned item-currencies are
  shown next to the gold. Pin any item as a currency from its `+` badge: it
  joins a new **Special** section and its count appears in the footer. Hover a
  currency for a per-character breakdown and total. A **Currency** options panel
  toggles the footer display, the cross-character total and whether other
  characters are included, and lists tracked currencies with a per-currency
  **account-wide** flag (shown once instead of summed — tick it for shared
  currencies; per-character ones like Runes of Ascension are summed).

### Notes
- The cache builds up as you visit each character's bags/banks and open their
  banks; alt data appears once seen. The warehouse and cross-character totals
  are read-only.

## [2.1.1] - 2026-07-22

### Fixed
- Guild / personal / realm bank crashed on open: the item count was lost to
  Lua's `and/or` truncation of multiple return values (`used` / `total` became
  `nil`). Replaced with an explicit branch.
- Promoting a trade-goods subtype crashed when the promoted category was
  labelled: a helper (`BuildProfessionOrder`) was defined after its first
  caller, so it resolved to a nil global. The profession-order helpers now sit
  ahead of everything that uses them.

## [2.1.0] - 2026-07-22

### Added
- **Promote trade goods to their own categories** — in the Display panel, tick
  any Trade Goods subtype (Herb, Metal & Stone, Leather, Cloth, Enchanting mats,
  Jewelcrafting…) to give it its own top-level section instead of nesting it
  under Profession & Trade. Per-subtype, saved in profiles, applies to both the
  bags and the bank. The subtype list is read from the client, so it matches
  whatever the realm actually has.
- **Resizable bank window** — drag the bottom-right grip; more width means more
  columns, and the size is saved between sessions.

### Changed
- **Unified layout engine** — the bank now uses the exact same sub-grouping as
  the bags (material → slot sub-headers, honouring the Display grouping modes),
  so gear and trade goods read identically everywhere.
- **Profession sub-sections are ordered by profession** (gathering mats first,
  then per-profession, misc last) instead of alphabetically. Locale-independent:
  it keys off the client's own subclass indices, not the localized names.

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

[2.6.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v2.6.0
[2.5.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v2.5.0
[2.4.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v2.4.0
[2.3.1]: https://github.com/Tetardtek/BagsEnh/releases/tag/v2.3.1
[2.3.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v2.3.0
[2.2.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v2.2.0
[2.1.1]: https://github.com/Tetardtek/BagsEnh/releases/tag/v2.1.1
[2.1.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v2.1.0
[2.0.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v2.0.0
[1.2.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v1.2.0
[1.1.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v1.1.0
[1.0.0]: https://github.com/Tetardtek/BagsEnh/releases/tag/v1.0.0
