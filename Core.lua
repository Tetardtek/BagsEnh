-- ============================================================
-- Core — events, coalesced refresh, slash commands
-- ============================================================

local core = CreateFrame("Frame")
core:RegisterEvent("PLAYER_LOGIN")
core:RegisterEvent("BAG_UPDATE")
core:RegisterEvent("PLAYER_MONEY")
core:RegisterEvent("ITEM_LOCK_CHANGED")
core:RegisterEvent("CURRENCY_DISPLAY_UPDATE")   -- watched currencies in the footer
-- Character bank (v2): only readable while its frame is open
core:RegisterEvent("BANKFRAME_OPENED")
core:RegisterEvent("BANKFRAME_CLOSED")
core:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
core:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
-- Guild-style banks (guild / personal / realm — Ascension routes all via the
-- guild bank API and frame)
core:RegisterEvent("GUILDBANKFRAME_OPENED")
core:RegisterEvent("GUILDBANKFRAME_CLOSED")
core:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
-- Marchand : contexte du Ctrl+clic « vendre une section » (F1)
core:RegisterEvent("MERCHANT_SHOW")
core:RegisterEvent("MERCHANT_CLOSED")
-- Ascension: fires when an appearance is learned — moves gear out of the
-- "uncollected" section live. pcall-guarded: absent on vanilla 3.3.5 clients.
pcall(function() core:RegisterEvent("APPEARANCE_COLLECTED") end)

-- Coalesced refresh: BAG_UPDATE fires in bursts (AoE loot, mail),
-- never refresh more than once per window
local REFRESH_DELAY = 0.1
local dirty = false
local elapsed = 0

core:SetScript("OnUpdate", function(self, dt)
    if not dirty then return end
    elapsed = elapsed + dt
    if elapsed >= REFRESH_DELAY then
        dirty = false
        elapsed = 0
        BagsEnh_Refresh()
    end
end)

function BagsEnh_MarkDirty()
    dirty = true
    elapsed = 0
end
local MarkDirty = BagsEnh_MarkDirty

-- ============================================================
-- New-item tracking — autonomous (diff of bag counts on BAG_UPDATE),
-- plus BagsEnh_OnNewLoot() so LootEnh (or any Enh addon) can flag items.
-- Session-only: cleared on reload and when the bags are closed (seen).
-- ============================================================
BagsEnh_newItems = {}      -- [itemID] = true
local lastCounts = {}
local scanInit = false

local function CountBags()
    local c = {}
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local link = GetContainerItemLink(bag, slot)
            local id = link and BagsEnh_ItemIDFromLink(link)
            if id then
                local _, count = GetContainerItemInfo(bag, slot)
                c[id] = (c[id] or 0) + (count or 1)
            end
        end
    end
    return c
end

function BagsEnh_ScanNewItems()
    local cur = CountBags()
    if scanInit then
        for id, n in pairs(cur) do
            if n > (lastCounts[id] or 0) then
                BagsEnh_newItems[id] = true
            end
        end
    end
    lastCounts = cur
    scanInit = true
end

-- Bridge entry point: LootEnh calls this on each loot it sees
function BagsEnh_OnNewLoot(link, count)
    local id = BagsEnh_ItemIDFromLink(link)
    if id then
        BagsEnh_newItems[id] = true
        if BagsEnh_IsShown() then MarkDirty() end
    end
end

function BagsEnh_ClearNew()
    BagsEnh_newItems = {}
    if BagsEnh_IsShown() then BagsEnh_Refresh() end
end

function BagsEnh_MarkSeen(id)
    if id then BagsEnh_newItems[id] = nil end
end

core:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        BagsEnh_InitializeDB()
        if BagsEnh_MigrateRealmBanks then BagsEnh_MigrateRealmBanks() end
        -- Options panels are optional UI: guard each so a module that failed to
        -- load (e.g. a newly added file on a stale .toc) can never abort the
        -- critical init below (hooks, profiles) and leave the bags broken.
        if BagsEnh_CreateOptionsPanel then BagsEnh_CreateOptionsPanel() end
        if BagsEnh_CreateDisplayPanel then BagsEnh_CreateDisplayPanel() end
        if BagsEnh_CreateCurrencyPanel then BagsEnh_CreateCurrencyPanel() end
        if BagsEnh_CreateCategoriesPanel then BagsEnh_CreateCategoriesPanel() end
        if BagsEnh_CreateOrderPanel then BagsEnh_CreateOrderPanel() end
        if BagsEnh_CreateAltsPanel then BagsEnh_CreateAltsPanel() end
        BagsEnh_AutoLoadProfile()
        BagsEnh_InstallHooks()
        BagsEnh_ScanNewItems()   -- baseline snapshot, no items flagged
        if BagsEnh_CacheBags then BagsEnh_CacheBags() end   -- initial cache snapshot
        if BagsEnh_CacheCurrencies then BagsEnh_CacheCurrencies() end
    elseif event == "BAG_UPDATE" then
        BagsEnh_ScanNewItems()   -- detect new items even while closed
        if BagsEnh_CacheBags then BagsEnh_CacheBags() end   -- keep the cache fresh
        if BagsEnh_CacheCurrencies then BagsEnh_CacheCurrencies() end   -- item-currency counts
        if BagsEnh_RefreshWarehouses then BagsEnh_RefreshWarehouses() end
        if BagsEnh_IsShown() then MarkDirty() end
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        if BagsEnh_CacheCurrencies then BagsEnh_CacheCurrencies() end
        if BagsEnh_IsShown() then MarkDirty() end
    elseif event == "BANKFRAME_OPENED" then
        if BagsEnh_SetBankOpen then BagsEnh_SetBankOpen(true) end
        if BagsEnh_ShowBank then BagsEnh_ShowBank() end
        if BagsEnh_CacheBank then BagsEnh_CacheBank() end
    elseif event == "BANKFRAME_CLOSED" then
        if BagsEnh_SetBankOpen then BagsEnh_SetBankOpen(false) end
        if BagsEnh_HideBank then BagsEnh_HideBank() end
    elseif event == "MERCHANT_SHOW" then
        if BagsEnh_SetMerchantOpen then BagsEnh_SetMerchantOpen(true) end
    elseif event == "MERCHANT_CLOSED" then
        if BagsEnh_SetMerchantOpen then BagsEnh_SetMerchantOpen(false) end
    elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
        if BagsEnh_CacheBank then BagsEnh_CacheBank() end
        if BagsEnh_RefreshWarehouses then BagsEnh_RefreshWarehouses() end
        if BagsEnh_IsBankShown and BagsEnh_IsBankShown() then BagsEnh_RefreshBank() end
    elseif event == "GUILDBANKBAGSLOTS_CHANGED" then
        if BagsEnh_CacheGuildStyle then BagsEnh_CacheGuildStyle() end
        if BagsEnh_RefreshWarehouses then BagsEnh_RefreshWarehouses() end
        if BagsEnh_IsBankShown and BagsEnh_IsBankShown() then BagsEnh_RefreshBank() end
    elseif event == "GUILDBANKFRAME_OPENED" then
        if BagsEnh_ShowGuildBank then BagsEnh_ShowGuildBank() end
    elseif event == "GUILDBANKFRAME_CLOSED" then
        if BagsEnh_HideBank then BagsEnh_HideBank() end
    else
        if BagsEnh_IsShown() then
            MarkDirty()
        end
    end
end)

-- ============================================================
-- Slash commands
-- ============================================================
SLASH_BAGSENH1 = "/be"
SlashCmdList["BAGSENH"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "toggle" then
        BagsEnh_SetUnified(not BagsEnhDB.enabled)
    elseif msg == "view" then
        BagsEnhDB.viewMode = (BagsEnhDB.viewMode == "onebag") and "category" or "onebag"
        if BagsEnh_IsShown() then BagsEnh_Refresh() end
    elseif msg == "sort" then
        BagsEnh_SortBags()
    elseif msg == "merge" or msg == "compact" then
        -- Banque perso ouverte → compacte la banque ; sinon les sacs.
        if BagsEnh_IsBankShown and BagsEnh_IsBankShown() and BagsEnh_MergeBankStacks then
            BagsEnh_MergeBankStacks()
        elseif BagsEnh_MergeBagStacks then
            BagsEnh_MergeBagStacks()
        end
    elseif msg == "alts" or msg == "warehouse" or msg == "coffre" then
        if BagsEnh_OpenWarehouse then BagsEnh_OpenWarehouse() end
    elseif msg == "version" or msg == "v" then
        if BagsEnh_VersionInfo then BagsEnh_VersionInfo() end
    elseif msg == "clearcache" then
        if BagsEnh_ClearCache then BagsEnh_ClearCache() end
    elseif msg == "debug" then
        BagsEnh_DebugDump()
    elseif msg == "reset" then
        BagsEnhDB.posX, BagsEnhDB.posY = 0, 0
        if BagsEnhFrame then
            BagsEnhFrame:ClearAllPoints()
            BagsEnhFrame:SetPoint("CENTER", 0, 0)
        end
    else
        BagsEnh_Toggle()
    end
end
