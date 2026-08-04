-- ============================================================
-- Category engine — resolves every item to a category key.
-- Priority: custom rules (v1.1) > Ascension > quality > native type.
-- Ascension taxonomy is data, kept apart from the logic — the new
-- realms will move it around.
-- ============================================================

-- ============================================================
-- Trade Goods subtype order/maps (defined first — used by CategoryLabel,
-- Categorize and the grouping engine below). Curated display order expressed
-- as positions in the client's own GetAuctionItemSubClasses(6) list, so it is
-- locale-independent. Ascension order: 1 Elemental, 2 Cloth, 3 Leather,
-- 4 Metal & Stone, 5 Meat, 6 Herb, 7 Enchanting, 8 Jewelcrafting, 9 Parts,
-- 10 Devices, 11 Explosives, 12 Materials, 13 Other, 14 Armor Ench,
-- 15 Weapon Ench. Gathering mats first, then per-profession, misc last.
-- ============================================================
local TRADEGOODS_ORDER_BY_INDEX = { 6, 4, 3, 2, 5, 1, 7, 8, 9, 10, 11, 14, 15, 12, 13 }
local professionSubRank        -- [name] = display rank
local profSubName              -- [clientIndex] = localized name
local profNameToIndex          -- [name] = clientIndex
local function BuildProfessionOrder()
    if professionSubRank or type(GetAuctionItemSubClasses) ~= "function" then return end
    local subs = { GetAuctionItemSubClasses(6) }
    if #subs == 0 then return end   -- API not ready yet; retry on the next call
    local rankByIndex = {}
    for rank, idx in ipairs(TRADEGOODS_ORDER_BY_INDEX) do rankByIndex[idx] = rank end
    professionSubRank, profSubName, profNameToIndex = {}, {}, {}
    for i, name in ipairs(subs) do
        professionSubRank[name] = rankByIndex[i] or (100 + i)
        profSubName[i] = name
        profNameToIndex[name] = i
    end
end

-- Trade Goods subtypes in curated display order: { index=clientIndex, name=... }
function BagsEnh_ProfSubtypes()
    BuildProfessionOrder()
    local list = {}
    if not profSubName then return list end
    for idx, name in pairs(profSubName) do
        list[#list + 1] = { index = idx, name = name, rank = professionSubRank[name] or 999 }
    end
    table.sort(list, function(a, b) return a.rank < b.rank end)
    return list
end

function BagsEnh_IsProfPromoted(index)
    return BagsEnhDB and BagsEnhDB.promotedProf and BagsEnhDB.promotedProf[index] ~= nil
end

-- Display order of sections in the unified view
BagsEnh_CATEGORY_ORDER = {
    "new",          -- v1.1 — LootEnh bridge
    "special",      -- user-pinned "currency" items
    "uncollected",  -- Ascension: gear whose appearance isn't collected yet
    "worldforged",
    "mystic",
    "raidmats",
    "equipment",
    "consumables",
    "gems",
    "profession",
    "recipes",
    "quest",
    "bags",
    "glyphs",
    "junk",
    "misc",
    "hidden",       -- rendered only when BagsEnhDB.showHidden
}

BagsEnh_CATEGORY_LABELS = {
    new = "CAT_NEW",
    special = "CAT_SPECIAL",
    uncollected = "CAT_UNCOLLECTED",
    worldforged = "CAT_WORLDFORGED",
    mystic = "CAT_MYSTIC",
    raidmats = "CAT_RAIDMATS",
    equipment = "CAT_EQUIPMENT",
    consumables = "CAT_CONSUMABLES",
    gems = "CAT_GEMS",
    profession = "CAT_PROFESSION",
    quest = "CAT_QUEST",
    recipes = "CAT_RECIPES",
    bags = "CAT_BAGS",
    glyphs = "CAT_GLYPHS",
    junk = "CAT_JUNK",
    misc = "CAT_MISC",
    hidden = "CAT_HIDDEN",
}

-- ============================================================
-- User-defined categories — BagsEnhDB.userCategories[key] = display name.
-- Keys are "user<N>" (N = monotonic userCatSeq), never reused, so they never
-- clash with the built-in keys and stay stable across renames.
-- ============================================================

-- Display label for any category key: user name > localized built-in > raw key
function BagsEnh_CategoryLabel(key)
    local uc = BagsEnhDB and BagsEnhDB.userCategories
    if uc and uc[key] then return uc[key] end
    local pi = type(key) == "string" and key:match("^prof(%d+)$")
    if pi then
        BuildProfessionOrder()
        return (profSubName and profSubName[tonumber(pi)]) or key
    end
    local ld = BagsEnh_L()
    return ld[BagsEnh_CATEGORY_LABELS[key]] or key
end

-- User category keys in creation order (numeric suffix, not lexicographic)
function BagsEnh_UserCategoryKeys()
    local keys = {}
    local uc = BagsEnhDB and BagsEnhDB.userCategories
    if uc then
        for k in pairs(uc) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            return (tonumber(a:match("%d+")) or 0) < (tonumber(b:match("%d+")) or 0)
        end)
    end
    return keys
end

function BagsEnh_AddUserCategory(name)
    if not name or name == "" then return nil end
    BagsEnhDB.userCategories = BagsEnhDB.userCategories or {}
    BagsEnhDB.userCatSeq = (BagsEnhDB.userCatSeq or 0) + 1
    local key = "user" .. BagsEnhDB.userCatSeq
    BagsEnhDB.userCategories[key] = name
    if BagsEnh_MarkDirty then BagsEnh_MarkDirty() end
    if BagsEnhFrame and BagsEnhFrame:IsShown() then BagsEnh_Refresh() end
    return key
end

function BagsEnh_RenameUserCategory(key, name)
    if not key or not name or name == "" then return end
    if BagsEnhDB.userCategories and BagsEnhDB.userCategories[key] then
        BagsEnhDB.userCategories[key] = name
        if BagsEnh_MarkDirty then BagsEnh_MarkDirty() end
        if BagsEnhFrame and BagsEnhFrame:IsShown() then BagsEnh_Refresh() end
    end
end

-- Deleting a category also purges every reference to it (item overrides,
-- name rules, collapse state, saved order) so nothing points at a ghost key.
function BagsEnh_RemoveUserCategory(key)
    if not key or not BagsEnhDB.userCategories then return end
    BagsEnhDB.userCategories[key] = nil
    if BagsEnhDB.itemOverrides then
        for id, cat in pairs(BagsEnhDB.itemOverrides) do
            if cat == key then BagsEnhDB.itemOverrides[id] = nil end
        end
    end
    if BagsEnhDB.customRules then
        for pat, cat in pairs(BagsEnhDB.customRules) do
            if cat == key then BagsEnhDB.customRules[pat] = nil end
        end
    end
    if BagsEnhDB.collapsed then BagsEnhDB.collapsed[key] = nil end
    if BagsEnhDB.categoryOrder then
        local kept = {}
        for _, c in ipairs(BagsEnhDB.categoryOrder) do
            if c ~= key then kept[#kept + 1] = c end
        end
        BagsEnhDB.categoryOrder = kept
    end
    BagsEnh_InvalidateCategoryCache()
    if BagsEnh_MarkDirty then BagsEnh_MarkDirty() end
    if BagsEnhFrame and BagsEnhFrame:IsShown() then BagsEnh_Refresh() end
end

-- Accent colour per category (section-header dot). User categories fall back
-- to the series accent.
BagsEnh_CATEGORY_COLORS = {
    uncollected = {0.90, 0.73, 0.25},
    special     = {0.30, 0.85, 0.90},
    new         = {0.10, 0.80, 1.00},
    worldforged = {1.00, 0.50, 0.00},
    mystic      = {0.64, 0.35, 0.93},
    raidmats    = {0.30, 0.80, 0.75},
    equipment   = {0.45, 0.62, 1.00},
    consumables = {0.30, 0.82, 0.45},
    gems        = {1.00, 0.45, 0.72},
    profession  = {0.82, 0.62, 0.35},
    quest       = {1.00, 0.85, 0.12},
    junk        = {0.62, 0.62, 0.62},
    misc        = {0.72, 0.75, 0.78},
    hidden      = {0.50, 0.52, 0.55},
}
function BagsEnh_CategoryColor(key)
    local c = BagsEnh_CATEGORY_COLORS[key]
    if c then return c[1], c[2], c[3] end
    if type(key) == "string" and key:match("^prof%d+$") then
        local pc = BagsEnh_CATEGORY_COLORS.profession
        return pc[1], pc[2], pc[3]
    end
    return BagsEnh_ACCENT[1], BagsEnh_ACCENT[2], BagsEnh_ACCENT[3]
end

-- ============================================================
-- Ascension data (name patterns — TODO v1.1: reuse LootEnh itemID lists)
-- ============================================================
local ASCENSION_PATTERNS = {
    { pattern = "Worldforged", category = "worldforged" },
    { pattern = "^Mystic Scroll", category = "mystic" },
}

-- Équipement PvP d'Ascension. Ces objets donnent un bonus de dégâts et de
-- résistance en PvP, et un MALUS en PvE — l'équipement PvE fait l'inverse. Ce
-- sont donc deux jeux d'équipement qu'on alterne, et qu'il ne faut surtout pas
-- confondre : ni au moment de s'habiller pour un raid, ni au moment de vendre
-- (leur valeur est à l'hôtel des ventes, pas chez le marchand).
--
-- Détection par le NOM et non par l'identifiant : sur 1 744 objets Bloodforged
-- relevés dans le cache client, les identifiants s'étalent sur 19 plages (de
-- 6,0 M à 8,5 M, plus des isolés bien plus bas) alors que le préfixe, lui, est
-- systématique.
function BagsEnh_IsBloodforged(link)
    if not link then return false end
    local name = GetItemInfo(link)
    return (name and name:find("Bloodforged", 1, true)) and true or false
end

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
    ["Reagent"] = "profession",
    ["Projectile"] = "consumables",
    ["Quiver"] = "equipment",
    ["Quest"] = "quest",
    -- Ces trois classes n'étaient mappées nulle part et tombaient donc toutes
    -- dans « Divers », qui n'a par ailleurs aucun second niveau. Container et
    -- Glyph sont des classes natives à part entière ; Recipe quittait la
    -- catégorie artisanat, où un apprentissage voisinait avec le minerai qu'il
    -- sert à travailler.
    ["Container"] = "bags",
    ["Glyph"] = "glyphs",
    ["Recipe"] = "recipes",
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
        [projectile or ""] = "consumables",
        [quiver or ""] = "equipment",
        [gem or ""] = "gems",
        [quest or ""] = "quest",
        -- container, glyph et recipe etaient extraits de GetAuctionItemClasses
        -- puis jamais utilises : les trois finissaient dans « Divers ».
        [container or ""] = "bags",
        [glyph or ""] = "glyphs",
        [recipe or ""] = "recipes",
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

-- "uncollected" then "new" always lead (pinned, not reorderable); "hidden"
-- always trails; everything between is user-orderable.
local FIXED_FIRST = { "uncollected", "new" }
local FIXED_LAST = "hidden"

local function IsFixed(c)
    if c == FIXED_LAST then return true end
    for _, f in ipairs(FIXED_FIRST) do
        if c == f then return true end
    end
    return false
end

-- Returns the orderable categories in the user's order, validated against
-- the built-in list (drops unknowns, appends any category added later so a
-- new BagsEnh version never loses a section).
function BagsEnh_GetOrderableCategories()
    local default, valid = {}, {}
    for _, c in ipairs(BagsEnh_CATEGORY_ORDER) do
        if not IsFixed(c) then
            -- promoted trade-goods subtypes sit just before the profession bucket
            if c == "profession" then
                for _, sub in ipairs(BagsEnh_ProfSubtypes()) do
                    if BagsEnh_IsProfPromoted(sub.index) then
                        local k = "prof" .. sub.index
                        if not valid[k] then default[#default + 1] = k; valid[k] = true end
                    end
                end
            end
            default[#default + 1] = c
            valid[c] = true
        end
    end
    -- user categories are orderable too, appended after the built-ins by default
    for _, k in ipairs(BagsEnh_UserCategoryKeys()) do
        if not valid[k] then
            default[#default + 1] = k
            valid[k] = true
        end
    end
    local saved = BagsEnhDB and BagsEnhDB.categoryOrder
    if not saved then return default end
    local seen, result = {}, {}
    for _, c in ipairs(saved) do
        if valid[c] and not seen[c] then
            result[#result + 1] = c
            seen[c] = true
        end
    end
    for _, c in ipairs(default) do
        if not seen[c] then result[#result + 1] = c end
    end
    return result
end

-- Full render order: uncollected + new + orderable + hidden
function BagsEnh_GetCategoryOrder()
    local list = {}
    for _, c in ipairs(FIXED_FIRST) do
        list[#list + 1] = c
    end
    for _, c in ipairs(BagsEnh_GetOrderableCategories()) do
        list[#list + 1] = c
    end
    list[#list + 1] = FIXED_LAST
    return list
end

-- Moves a category up (delta -1) or down (delta +1) in the user order
function BagsEnh_MoveCategory(cat, delta)
    local order = BagsEnh_GetOrderableCategories()
    local idx
    for i, c in ipairs(order) do
        if c == cat then idx = i break end
    end
    if not idx then return end
    local j = idx + delta
    if j < 1 or j > #order then return end
    order[idx], order[j] = order[j], order[idx]
    BagsEnhDB.categoryOrder = order
    if BagsEnh_MarkDirty then BagsEnh_MarkDirty() end
    if BagsEnhFrame and BagsEnhFrame:IsShown() then BagsEnh_Refresh() end
end

-- ============================================================
-- Shared sub-grouping engine (used by both the bags and the bank so gear and
-- trade goods are laid out identically everywhere).
-- ============================================================

-- Sub-grouping mode for a category (nil = plain flat, no sub-headers).
-- equipment / appearance are user-configurable; profession is material-only.
-- Catégories dont le sous-type natif porte une vraie information et mérite donc
-- un second niveau. Liste explicite plutôt que « toutes » : sur « camelote »,
-- « nouveau » ou « quête », un sous-en-tête par objet serait du bruit, pas du
-- classement.
local SUBGROUPED = {
    consumables = true,   -- Potion / Élixir / Flacon / Parchemin / Nourriture / Bandage
    misc = true,          -- Camelote / Composant / Familier / Monture / Fête / Autre
    gems = true,          -- Rouge / Bleue / Jaune / Méta…
    recipes = true,       -- Alchimie / Couture / Forge / Ingénierie…
    bags = true,          -- Sac / Sacoche d'herboriste / Carquois…
    glyphs = true,
}

function BagsEnh_GroupingFor(cat)
    if cat == "equipment" then
        local g = BagsEnhDB.equipGrouping or "material_slot"
        return g ~= "none" and g or nil
    elseif cat == "profession" or SUBGROUPED[cat] then
        return "material"
    elseif cat == "uncollected" then
        local g = BagsEnhDB.uncollectedGrouping or "none"
        return g ~= "none" and g or nil
    end
    -- Un sous-type promu en catégorie propre (prof<N>) garde ses sous-sections.
    if type(cat) == "string" and cat:match("^prof%d+$") then return "material" end
    return nil
end

-- Sort key for a sub-category: profession subtypes get their curated rank so
-- they order by profession; everything else keeps its name (alphabetical).
function BagsEnh_SubCatKey(subCat)
    BuildProfessionOrder()
    local r = professionSubRank and subCat and professionSubRank[subCat]
    if r then return string.format("%03d", r) end
    return "999" .. (subCat or "")
end

-- Niveau d'objet, mémorisé. Volontairement lu ICI plutôt qu'ajouté aux
-- structures d'items : celles-ci sont construites dans Frames.lua, Bank.lua ET
-- Warehouse.lua — trois constructeurs, donc trois occasions d'en oublier un et
-- de laisser une fenêtre trier autrement que les deux autres.
-- table.sort appelle le comparateur O(n log n) fois, d'où la mémoïsation.
local ilvlCache = {}

function BagsEnh_ItemLevel(link)
    if not link then return 0 end
    local id = BagsEnh_ItemIDFromLink(link)
    if not id then return 0 end
    local v = ilvlCache[id]
    if v ~= nil then return v end
    local _, _, _, lvl = GetItemInfo(link)
    -- Pas encore en cache client : on rend 0 sans mémoriser, pour relire au
    -- prochain passage plutôt que de figer un mauvais rang.
    if not lvl then return 0 end
    ilvlCache[id] = lvl
    return lvl
end

function BagsEnh_CmpMaterialFirst(a, b)
    local sa, sb = BagsEnh_SubCatKey(a.subCat), BagsEnh_SubCatKey(b.subCat)
    if sa ~= sb then return sa < sb end
    local ea = BagsEnh_EQUIPLOC_ORDER[a.equipLoc or ""] or 99
    local eb = BagsEnh_EQUIPLOC_ORDER[b.equipLoc or ""] or 99
    if ea ~= eb then return ea < eb end
    if (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
    -- Le palier avant le nom. Sur de l'équipement la qualité tranche déjà le
    -- plus souvent ; sur des matériaux elle est quasi constante, et le tri
    -- retombait alors sur l'alphabet : Lin, Fil de mage, Tissu runique, Soie,
    -- Laine. Le niveau d'objet suit le palier pour tous les matériaux
    -- d'artisanat, sans table codée en dur — donc valable aussi pour les objets
    -- propres à Ascension.
    local la, lb = BagsEnh_ItemLevel(a.link), BagsEnh_ItemLevel(b.link)
    if la ~= lb then return la < lb end
    return (a.link or "") < (b.link or "")
end

function BagsEnh_CmpSlotFirst(a, b)
    local ea = BagsEnh_EQUIPLOC_ORDER[a.equipLoc or ""] or 99
    local eb = BagsEnh_EQUIPLOC_ORDER[b.equipLoc or ""] or 99
    if ea ~= eb then return ea < eb end
    local sa, sb = BagsEnh_SubCatKey(a.subCat), BagsEnh_SubCatKey(b.subCat)
    if sa ~= sb then return sa < sb end
    if (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
    return (a.link or "") < (b.link or "")
end

-- Lays a gear-like section with sub-headers per the grouping mode. Pure of any
-- frame specifics: the caller supplies place(item, col, y) and header(text,
-- indent, y) plus geometry. Returns the new running y.
--   o = { place, header, perRow, yStep, subH }
function BagsEnh_LayoutGrouped(items, mode, o, y)
    table.sort(items, mode == "slot" and BagsEnh_CmpSlotFirst or BagsEnh_CmpMaterialFirst)
    local wantMat = (mode == "material_slot" or mode == "material")
    local wantSlot = (mode == "material_slot" or mode == "slot")
    local slotIndent = (mode == "material_slot") and 16 or 4
    local lastMat, lastSlot, col = nil, nil, 0
    -- Sous-sections repliables (F1) : o.collapsed(desc) -> true pour cacher les
    -- items d'un sous-groupe (matériau replié cache aussi ses sous-en-têtes de
    -- slot). Callback optionnel : le Warehouse ne le fournit pas.
    local matCollapsed, slotCollapsed = false, false
    for _, item in ipairs(items) do
        if wantMat then
            local mat = item.subCat or "?"
            if mat ~= lastMat then
                if col > 0 then y = y + o.yStep; col = 0 end
                lastMat, lastSlot = mat, nil
                o.header("|cffaaaaaa" .. mat .. "|r", 4, y, { sub = mat })
                y = y + o.subH
                matCollapsed = (o.collapsed and o.collapsed({ sub = mat })) or false
                slotCollapsed = false
            end
        end
        if not matCollapsed and wantSlot then
            local eloc = item.equipLoc
            if eloc and BagsEnh_EQUIPLOC_ORDER[eloc] and eloc ~= lastSlot then
                if col > 0 then y = y + o.yStep; col = 0 end
                lastSlot = eloc
                local d = { slot = eloc, sub = wantMat and lastMat or nil }
                o.header("|cff808080" .. (_G[eloc] or eloc) .. "|r", slotIndent, y, d)
                y = y + o.subH
                slotCollapsed = (o.collapsed and o.collapsed(d)) or false
            end
        end
        if not matCollapsed and not slotCollapsed then
            o.place(item, col, y)
            col = col + 1
            if col >= o.perRow then col = 0; y = y + o.yStep end
        end
    end
    if col > 0 then y = y + o.yStep end
    return y
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
-- Ascension wardrobe: true when the item carries an appearance the player
-- hasn't collected yet. Guarded so the addon still runs on a vanilla 3.3.5
-- client where these C_Appearance APIs don't exist.
function BagsEnh_IsUncollectedAppearance(itemID)
    if not itemID then return false end
    if not (C_Appearance and C_Appearance.GetItemAppearanceID
            and C_AppearanceCollection and C_AppearanceCollection.IsAppearanceCollected) then
        return false
    end
    local appearanceID = C_Appearance.GetItemAppearanceID(itemID)
    if not appearanceID then return false end
    return not C_AppearanceCollection.IsAppearanceCollected(appearanceID)
end

function BagsEnh_Categorize(link)
    if not link then return "misc", true end
    local itemID = BagsEnh_ItemIDFromLink(link)

    -- User override (badge menu) — absolute priority, never cached
    local override = itemID and BagsEnhDB.itemOverrides and BagsEnhDB.itemOverrides[itemID]
    if override then
        return override, true
    end

    -- Base category (type/rules) is cached; the appearance status is applied
    -- live on top of it further down.
    local baseCat, subCat, equipLoc
    local cached = itemID and categoryCache[itemID]
    if cached then
        baseCat, subCat, equipLoc = cached[1], cached[2], cached[3]
    else
        BuildTypeMap()
        local name, _, quality, _, _, itemType, itemSubType, _, eLoc = GetItemInfo(link)
        if not name then return "misc", false end -- not cached yet, no cache write

        local category

        -- 1. Custom rules — user name patterns. Longest match wins
        --    (deterministic when several patterns match the same item).
        if BagsEnhDB.customRules then
            local lname = name:lower()
            local bestPat
            for pattern, catKey in pairs(BagsEnhDB.customRules) do
                if lname:find(pattern, 1, true) and (not bestPat or #pattern > #bestPat) then
                    bestPat = pattern
                    category = catKey
                end
            end
        end

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

        -- Items pinned as currencies get their own "special" section
        if itemID and BagsEnhDB.itemCurrencies and BagsEnhDB.itemCurrencies[itemID] then
            category = "special"
        end

        -- Sub-category from itemSubType (localized by the client, display-ready).
        -- Renseignée pour TOUTE catégorie, plus seulement l'équipement et
        -- l'artisanat : le client fournit un sous-type pour chaque objet et on
        -- le jetait pour dix catégories sur douze. C'est ce qui rendait Divers
        -- et les consommables illisibles — pas un défaut de classement, une
        -- absence de second niveau.
        --   consommables → Potion / Élixir / Flacon / Parchemin / Nourriture…
        --   divers       → Camelote / Composant / Familier / Monture / Fête…
        --   artisanat    → Tissu / Métal et pierre / Herbe / Cuir / Viande…
        --   équipement   → type d'arme / matériau d'armure
        if itemSubType and itemSubType ~= "" then
            subCat = itemSubType
        end
        -- Promote a trade-goods subtype to its own top-level category if enabled
        -- (cached; the options toggle invalidates the cache).
        if category == "profession" and subCat and BagsEnhDB.promotedProf then
            BuildProfessionOrder()
            local idx = profNameToIndex and profNameToIndex[subCat]
            if idx and BagsEnhDB.promotedProf[idx] then
                category = "prof" .. idx
            end
        end
        equipLoc = eLoc
        baseCat = category

        if itemID then
            categoryCache[itemID] = {category, subCat, equipLoc}
        end
    end

    -- Uncollected appearance (Ascension) overrides the base category, but is
    -- checked live and never cached: learning the appearance moves the item
    -- back to its normal category on the next refresh, no cache flush needed.
    -- equipLoc is preserved so the item level badge still shows.
    if itemID and BagsEnhDB.groupUncollected and BagsEnh_IsUncollectedAppearance(itemID) then
        return "uncollected", true, subCat, equipLoc
    end

    return baseCat, true, subCat, equipLoc
end

-- Sets (or clears with nil) a user category override for an item
function BagsEnh_SetItemOverride(itemID, category)
    if not itemID then return end
    BagsEnhDB.itemOverrides = BagsEnhDB.itemOverrides or {}
    BagsEnhDB.itemOverrides[itemID] = category
    if BagsEnh_MarkDirty then BagsEnh_MarkDirty() end
end

-- Adds a custom name-pattern rule (pattern is matched case-insensitively
-- as a plain substring). Clears the cache so it takes effect immediately.
function BagsEnh_AddCustomRule(pattern, category)
    if not pattern or pattern == "" or not category then return false end
    BagsEnhDB.customRules = BagsEnhDB.customRules or {}
    BagsEnhDB.customRules[pattern:lower()] = category
    BagsEnh_InvalidateCategoryCache()
    if BagsEnh_MarkDirty then BagsEnh_MarkDirty() end
    return true
end

function BagsEnh_RemoveCustomRule(pattern)
    if not pattern or not BagsEnhDB.customRules then return end
    BagsEnhDB.customRules[pattern:lower()] = nil
    BagsEnh_InvalidateCategoryCache()
    if BagsEnh_MarkDirty then BagsEnh_MarkDirty() end
end

-- Debug: dumps every bag item's raw GetItemInfo data + resolved category
function BagsEnh_DebugDump()
    BuildTypeMap()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBagsEnh debug|r — name | type | subType | quality | category")
    for bag = 0, 4 do
        for slot = 1, BagsEnh_GetContainerNumSlots(bag) or 0 do
            local link = BagsEnh_GetContainerItemLink(bag, slot)
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
