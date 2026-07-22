local defaults = {
    lang = "enUS",
    enabled = true,      -- unified view replaces default bags
    scale = 1.0,
    columns = 7,          -- items per row inside a section
    iconSize = 37,
    spacing = 4,          -- gap between item icons
    width = 620,          -- window size (resizable) — ~2 section columns
    height = 480,
    posX = 0,
    posY = 0,
    bankWidth = 460,     -- character bank window (v2)
    bankHeight = 500,
    bankPosX = 260,
    bankPosY = 0,
    hideNativeBank = true, -- stow the default bank / guild bank frames off-screen
    cache = {},          -- [char] = { bags, bank, money, lastSeen, class, currencies } — cross-char browse
    showCurrencies = true,   -- watched + pinned currencies next to the gold
    currencyTotal = true,    -- cross-character total in the currency tooltip
    currencyOtherChars = true, -- include other characters in that total
    itemCurrencies = {}, -- [itemID] = true — items pinned as currencies (-> "special" section + footer)
    currencyShared = {}, -- [currencyKey] = true — account-wide currency (shown once, not summed)
    viewMode = "category", -- "category" (sections) | "onebag" (flat, empty slots shown)
    showItemLevel = true, -- draw the item level on equippable items
    groupUncollected = true, -- Ascension: gear with an unlearned appearance -> its own section
    equipGrouping = "material_slot", -- equipment sub-grouping: material_slot | material | slot | none
    uncollectedGrouping = "none",    -- "unlearned appearance" sub-grouping (flat by default)
    promotedProf = {},   -- [tradeGoodsSubclassIndex] = true -> its own top-level category
    collapsed = {},      -- [categoryKey] = true when section is collapsed
    userCategories = {}, -- [userKey] = display name (user-created sections)
    userCatSeq = 0,      -- monotonic counter for unique user category keys
    customRules = {},    -- name pattern -> category key (panel UI, v1.1)
    itemOverrides = {},  -- [itemID] = categoryKey | "hidden" (badge menu)
    showHidden = false,  -- reveal the "hidden" section
    profiles = {},       -- [name] = settings snapshot
    charProfiles = {},   -- [char-realm] = profile name (auto-load)
}

function BagsEnh_DeepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = BagsEnh_DeepCopy(v)
    end
    return copy
end

function BagsEnh_InitializeDB()
    BagsEnhDB = BagsEnhDB or {}
    for k, v in pairs(defaults) do
        if BagsEnhDB[k] == nil then
            -- Deep copy: never hand the defaults table itself to the DB
            BagsEnhDB[k] = BagsEnh_DeepCopy(v)
        elseif type(v) == "table" then
            for sk, sv in pairs(v) do
                if BagsEnhDB[k][sk] == nil then
                    BagsEnhDB[k][sk] = BagsEnh_DeepCopy(sv)
                end
            end
        end
    end
end
