-- ============================================================
-- Currency system (v2 polish). "Tracked currencies" = the game currencies you
-- watch in the Currency panel (GetBackpackCurrencyInfo) + items you pin as
-- currencies. Both show next to the gold and get a cross-character total.
-- Keys: "cur:<name>" for game currencies, "item:<itemID>" for pinned items.
-- ============================================================

function BagsEnh_IsPinnedItem(itemID)
    return itemID and BagsEnhDB.itemCurrencies and BagsEnhDB.itemCurrencies[itemID] ~= nil or false
end

function BagsEnh_TogglePinItem(itemID)
    if not itemID then return end
    BagsEnhDB.itemCurrencies = BagsEnhDB.itemCurrencies or {}
    if BagsEnhDB.itemCurrencies[itemID] then
        BagsEnhDB.itemCurrencies[itemID] = nil
    else
        BagsEnhDB.itemCurrencies[itemID] = true
    end
    if BagsEnh_InvalidateCategoryCache then BagsEnh_InvalidateCategoryCache() end
    if BagsEnh_CacheCurrencies then BagsEnh_CacheCurrencies() end
    if BagsEnh_MarkDirty then BagsEnh_MarkDirty() end
    if BagsEnhFrame and BagsEnhFrame:IsShown() then BagsEnh_Refresh() end
end

function BagsEnh_CurShared(key)
    return BagsEnhDB.currencyShared and BagsEnhDB.currencyShared[key] and true or false
end

-- Current character's tracked currencies with live counts, in display order:
-- game (watched) first, then pinned items.
function BagsEnh_CurrencyList()
    local list = {}
    if type(GetBackpackCurrencyInfo) == "function" then
        local i = 1
        while true do
            local name, count, _, icon = GetBackpackCurrencyInfo(i)
            if not name then break end
            list[#list + 1] = { kind = "cur", key = "cur:" .. name, name = name, icon = icon, count = count or 0 }
            i = i + 1
        end
    end
    if BagsEnhDB.itemCurrencies then
        for itemID in pairs(BagsEnhDB.itemCurrencies) do
            local name = GetItemInfo(itemID) or ("item " .. itemID)
            local icon = GetItemIcon(itemID)
            local count = GetItemCount(itemID, true) or 0   -- bags + bank
            list[#list + 1] = { kind = "item", key = "item:" .. itemID, name = name,
                icon = icon, count = count, itemID = itemID }
        end
    end
    return list
end

-- Snapshot the current character's currencies into the account-wide cache.
function BagsEnh_CacheCurrencies()
    if not BagsEnhDB or not BagsEnh_CharKey then return end
    BagsEnhDB.cache = BagsEnhDB.cache or {}
    local key = BagsEnh_CharKey()
    BagsEnhDB.cache[key] = BagsEnhDB.cache[key] or {}
    BagsEnhDB.cache[key].currencies = BagsEnh_CurrencyList()
end

-- Per-character rows { char, count } + the total for a currency key.
-- Shared currencies are shown once (this character's value); others are summed.
-- Honours the "include other characters" option.
function BagsEnh_CurrencyBreakdown(key)
    local rows, total = {}, 0
    local shared = BagsEnh_CurShared(key)
    local me = BagsEnh_CharKey()
    local onlyMe = (BagsEnhDB.currencyOtherChars == false)
    for _, ck in ipairs(BagsEnh_CachedChars()) do
        if not onlyMe or ck == me then
            local c = BagsEnh_GetCache(ck)
            local cur = c and c.currencies
            local cnt
            if cur then
                for _, e in ipairs(cur) do
                    if e.key == key then cnt = e.count; break end
                end
            end
            if cnt then
                rows[#rows + 1] = { char = ck, count = cnt }
                if not shared then total = total + cnt end
            end
        end
    end
    if shared then
        total = 0
        for _, r in ipairs(rows) do if r.char == me then total = r.count end end
        if total == 0 and rows[1] then total = rows[1].count end
    end
    return rows, total
end
