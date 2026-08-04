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

-- Realm (serveur) extrait d'une clé perso « Nom - Realm ». La realm bank est
-- commune à tout le compte sur un même serveur : on l'indexe par realm, pas
-- par perso, pour qu'aucun serveur n'entre en conflit avec un autre.
function BagsEnh_RealmOf(charKey)
    return (charKey and charKey:match(" %- (.+)$")) or (GetRealmName() or "?")
end

local function ScanContainers(containers)
    local items = {}
    for _, c in ipairs(containers) do
        for slot = 1, BagsEnh_GetContainerNumSlots(c) or 0 do
            local _, count, _, _, _, _, link = BagsEnh_GetContainerItemInfo(c, slot)
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
    if mode == "realmbank" then
        -- Realm bank = partagée par tout le compte sur ce serveur → un seul
        -- exemplaire par realm, visible de tous les persos (cf. /be alts).
        BagsEnhDB.realmbanks = BagsEnhDB.realmbanks or {}
        BagsEnhDB.realmbanks[GetRealmName() or "?"] = { items = items, lastSeen = time() }
    else
        e[mode] = items
    end
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
    BagsEnh_Print((BagsEnh_L().WH_CACHE_CLEARED or "cache cleared."))
end

-- Remove a single character's cached snapshot (obsolete alt cleanup).
function BagsEnh_DeleteCachedChar(key)
    if key and BagsEnhDB.cache and BagsEnhDB.cache[key] then
        BagsEnhDB.cache[key] = nil
        return true
    end
    return false
end

-- Last time this character's cache was refreshed (epoch seconds), or nil.
function BagsEnh_CharLastSeen(key)
    local e = BagsEnh_GetCache(key)
    return e and e.lastSeen or nil
end

-- Realm bank partagée du serveur `realm` (ou du realm courant), ou nil.
function BagsEnh_GetRealmBank(realm)
    realm = realm or (GetRealmName() or "?")
    return BagsEnhDB.realmbanks and BagsEnhDB.realmbanks[realm] or nil
end

-- Migration : avant la v2.3, la realm bank était stockée par perso
-- (cache[key].realmbank), donc dupliquée. On la regroupe une fois par serveur
-- en gardant le snapshot le plus récent, puis on nettoie les copies par perso.
function BagsEnh_MigrateRealmBanks()
    if not BagsEnhDB or not BagsEnhDB.cache then return end
    BagsEnhDB.realmbanks = BagsEnhDB.realmbanks or {}
    for key, e in pairs(BagsEnhDB.cache) do
        if type(e) == "table" and e.realmbank then
            local realm = BagsEnh_RealmOf(key)
            local cur = BagsEnhDB.realmbanks[realm]
            local ts = e.lastSeen or 0
            if not cur or (cur.lastSeen or 0) < ts then
                BagsEnhDB.realmbanks[realm] = { items = e.realmbank, lastSeen = ts }
            end
            e.realmbank = nil
        end
    end
end
