-- ============================================================
-- Core — events, coalesced refresh, slash commands
-- ============================================================

local core = CreateFrame("Frame")
core:RegisterEvent("PLAYER_LOGIN")
core:RegisterEvent("BAG_UPDATE")
core:RegisterEvent("PLAYER_MONEY")
core:RegisterEvent("ITEM_LOCK_CHANGED")
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
        BagsEnh_CreateOptionsPanel()
        BagsEnh_CreateCategoriesPanel()
        BagsEnh_CreateOrderPanel()
        BagsEnh_AutoLoadProfile()
        BagsEnh_InstallHooks()
        BagsEnh_ScanNewItems()   -- baseline snapshot, no items flagged
    elseif event == "BAG_UPDATE" then
        BagsEnh_ScanNewItems()   -- detect new items even while closed
        if BagsEnh_IsShown() then MarkDirty() end
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
