-- ============================================================
-- Cross-character cache (v2 phase 3). BagsEnhDB is account-wide
-- (## SavedVariables), so whatever a character sees of its bags / bank is
-- stored here and can be browsed from any other character — read-only.
-- Stored per item: just { link, count }; category / quality / icon are
-- resolved from the link at display time.
-- ============================================================

local BANK_CONTAINERS = { -1, 5, 6, 7, 8, 9, 10, 11 }
local BAG_CONTAINERS = { 0, 1, 2, 3, 4 }

function BagsEnh_CharKey()
    local name = UnitName("player") or "?"
    local realm = GetRealmName() or "?"
    return name .. " - " .. realm
end

local function ScanContainers(containers)
    local items = {}
    for _, c in ipairs(containers) do
        for slot = 1, GetContainerNumSlots(c) or 0 do
            local _, count, _, _, _, _, link = GetContainerItemInfo(c, slot)
            if link then
                items[#items + 1] = { link = link, count = count or 1 }
            end
        end
    end
    return items
end

local function Entry()
    BagsEnhDB.cache = BagsEnhDB.cache or {}
    local key = BagsEnh_CharKey()
    BagsEnhDB.cache[key] = BagsEnhDB.cache[key] or {}
    local e = BagsEnhDB.cache[key]
    e.class = e.class or select(2, UnitClass("player"))
    return e
end

-- Called on BAG_UPDATE (current character only)
function BagsEnh_CacheBags()
    if not BagsEnhDB then return end
    local e = Entry()
    e.bags = ScanContainers(BAG_CONTAINERS)
    e.money = GetMoney()
    e.lastSeen = time()
end

-- Called while the bank is open (its slots are only readable then)
function BagsEnh_CacheBank()
    if not BagsEnhDB then return end
    local e = Entry()
    e.bank = ScanContainers(BANK_CONTAINERS)
    e.lastSeen = time()
end

-- Guild-style banks (personal / realm / guild) — scan every tab and store the
-- merged list under a per-type key. Stored per character (each char keeps the
-- snapshot it last saw, even for shared banks — simple and browsable).
function BagsEnh_CacheGuildStyle()
    if not BagsEnhDB or not GuildBankFrame then return end
    local mode
    if GuildBankFrame.IsPersonalBank then mode = "personalbank"
    elseif GuildBankFrame.IsRealmBank then mode = "realmbank"
    else mode = "guildbank" end

    local items = {}
    local nTabs = GetNumGuildBankTabs() or 0
    local maxSlots = MAX_GUILDBANK_SLOTS_PER_TAB or 98
    for tab = 1, nTabs do
        for slot = 1, maxSlots do
            local link = GetGuildBankItemLink(tab, slot)
            if link then
                local _, count = GetGuildBankItemInfo(tab, slot)
                items[#items + 1] = { link = link, count = count or 1 }
            end
        end
    end

    local e = Entry()
    e[mode] = items
    e.lastSeen = time()
end

-- Sorted list of cached character keys
function BagsEnh_CachedChars()
    local list = {}
    if BagsEnhDB.cache then
        for k in pairs(BagsEnhDB.cache) do list[#list + 1] = k end
        table.sort(list)
    end
    return list
end

function BagsEnh_GetCache(charKey)
    return BagsEnhDB.cache and BagsEnhDB.cache[charKey] or nil
end

-- Character short name, coloured by class (from the cache).
function BagsEnh_CharColorName(key)
    local e = BagsEnh_GetCache(key)
    local name = key:match("^(.-) %- ") or key
    if e and e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class] then
        local c = RAID_CLASS_COLORS[e.class]
        return ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, name)
    end
    return name
end

function BagsEnh_ClearCache()
    BagsEnhDB.cache = {}
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBagsEnh:|r " .. (BagsEnh_L().WH_CACHE_CLEARED or "cache cleared."))
end
