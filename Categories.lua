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

-- Native itemType → category.
-- Static English fallback, completed at runtime by GetAuctionItemClasses():
-- the client tells us its own (possibly custom/localized) class strings —
-- robust against Ascension's custom item classes.
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

local typeMapBuilt = false
local function BuildTypeMap()
    if typeMapBuilt or not GetAuctionItemClasses then return end
    -- 3.3.5 order: Weapon, Armor, Container, Consumable, Glyph,
    -- Trade Goods, Projectile, Quiver, Recipe, Gem, Miscellaneous, Quest
    local weapon, armor, container, consumable, glyph, tradegoods,
          projectile, quiver, recipe, gem, misc, quest = GetAuctionItemClasses()
    local map = {
        [weapon or ""] = "equipment",
        [armor or ""] = "equipment",
        [consumable or ""] = "consumables",
        [tradegoods or ""] = "profession",
        [recipe or ""] = "profession",
        [projectile or ""] = "consumables",
        [quiver or ""] = "equipment",
        [gem or ""] = "gems",
        [quest or ""] = "quest",
    }
    map[""] = nil
    for k, v in pairs(map) do
        TYPE_TO_CATEGORY[k] = v
    end
    typeMapBuilt = true
end

local categoryCache = {}   -- [itemID] = {category, subCat, equipLoc}

function BagsEnh_InvalidateCategoryCache()
    categoryCache = {}
end

-- Equipment slot display order (head → trinket, weapons last)
BagsEnh_EQUIPLOC_ORDER = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3,
    INVTYPE_CLOAK = 4, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
    INVTYPE_BODY = 6, INVTYPE_TABARD = 7, INVTYPE_WRIST = 8,
    INVTYPE_HAND = 9, INVTYPE_WAIST = 10, INVTYPE_LEGS = 11,
    INVTYPE_FEET = 12, INVTYPE_FINGER = 13, INVTYPE_TRINKET = 14,
    INVTYPE_WEAPON = 20, INVTYPE_2HWEAPON = 21, INVTYPE_WEAPONMAINHAND = 22,
    INVTYPE_WEAPONOFFHAND = 23, INVTYPE_SHIELD = 24, INVTYPE_HOLDABLE = 25,
    INVTYPE_RANGED = 26, INVTYPE_RANGEDRIGHT = 26, INVTYPE_THROWN = 27,
    INVTYPE_RELIC = 28, INVTYPE_AMMO = 29,
}

-- Resolves an item link to (category, resolved, subCategory, equipLoc).
-- resolved=false when the item wasn't in the client cache yet
-- (caller may retry later, nothing is cached in that case).
-- subCategory is set for equipment only: weapon type or armor material.
function BagsEnh_Categorize(link)
    if not link then return "misc", true end
    local itemID = BagsEnh_ItemIDFromLink(link)
    local cached = itemID and categoryCache[itemID]
    if cached then
        return cached[1], true, cached[2], cached[3]
    end

    BuildTypeMap()
    local name, _, quality, _, _, itemType, itemSubType, _, equipLoc = GetItemInfo(link)
    if not name then return "misc", false end -- not cached yet, no cache write

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

    -- Equipment sub-category: weapon type / armor material (itemSubType,
    -- localized by the client — display-ready as-is)
    local subCat
    if category == "equipment" and itemSubType then
        subCat = itemSubType
    end

    if itemID then
        categoryCache[itemID] = {category, subCat, equipLoc}
    end
    return category, true, subCat, equipLoc
end

-- Debug: dumps every bag item's raw GetItemInfo data + resolved category
function BagsEnh_DebugDump()
    BuildTypeMap()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBagsEnh debug|r — name | type | subType | quality | category")
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local name, _, quality, _, _, itemType, itemSubType = GetItemInfo(link)
                local cat = BagsEnh_Categorize(link)
                DEFAULT_CHAT_FRAME:AddMessage(("%s | %s | %s | q%s | → %s"):format(
                    tostring(name), tostring(itemType), tostring(itemSubType),
                    tostring(quality), cat))
            end
        end
    end
end
