-- ============================================================
-- Category engine — resolves every item to a category key.
-- Priority: custom rules (v1.1) > Ascension > quality > native type.
-- Ascension taxonomy is data, kept apart from the logic — the new
-- realms will move it around.
-- ============================================================

-- Display order of sections in the unified view
BagsEnh_CATEGORY_ORDER = {
    "new",          -- v1.1 — LootEnh bridge
    "worldforged",
    "mystic",
    "raidmats",
    "equipment",
    "consumables",
    "gems",
    "profession",
    "quest",
    "junk",
    "misc",
}

BagsEnh_CATEGORY_LABELS = {
    new = "CAT_NEW",
    worldforged = "CAT_WORLDFORGED",
    mystic = "CAT_MYSTIC",
    raidmats = "CAT_RAIDMATS",
    equipment = "CAT_EQUIPMENT",
    consumables = "CAT_CONSUMABLES",
    gems = "CAT_GEMS",
    profession = "CAT_PROFESSION",
    quest = "CAT_QUEST",
    junk = "CAT_JUNK",
    misc = "CAT_MISC",
}

-- ============================================================
-- Ascension data (name patterns — TODO v1.1: reuse LootEnh itemID lists)
-- ============================================================
local ASCENSION_PATTERNS = {
    { pattern = "Worldforged", category = "worldforged" },
    { pattern = "^Mystic Scroll", category = "mystic" },
}

-- Native itemType → category (enUS client types)
local TYPE_TO_CATEGORY = {
    ["Weapon"] = "equipment",
    ["Armor"] = "equipment",
    ["Consumable"] = "consumables",
    ["Gem"] = "gems",
    ["Trade Goods"] = "profession",
    ["Recipe"] = "profession",
    ["Reagent"] = "profession",
    ["Projectile"] = "consumables",
    ["Quiver"] = "equipment",
    ["Quest"] = "quest",
}

local categoryCache = {}   -- [itemID] = categoryKey

function BagsEnh_InvalidateCategoryCache()
    categoryCache = {}
end

-- Resolves an item link to a category key ("misc" fallback).
function BagsEnh_Categorize(link)
    if not link then return "misc" end
    local itemID = BagsEnh_ItemIDFromLink(link)
    if itemID and categoryCache[itemID] then
        return categoryCache[itemID]
    end

    local name, _, quality, _, _, itemType = GetItemInfo(link)
    if not name then return "misc" end -- not cached yet, no cache write

    local category

    -- 1. Custom rules (v1.1)
    -- 2. Ascension taxonomy
    if not category then
        for _, rule in ipairs(ASCENSION_PATTERNS) do
            if name:find(rule.pattern) then
                category = rule.category
                break
            end
        end
    end

    -- 3. Quality: junk
    if not category and quality == 0 then
        category = "junk"
    end

    -- 4. Native item type
    if not category then
        category = TYPE_TO_CATEGORY[itemType]
    end

    category = category or "misc"
    if itemID then
        categoryCache[itemID] = category
    end
    return category
end
