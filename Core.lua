-- ============================================================
-- Core — events, coalesced refresh, slash commands
-- ============================================================

local core = CreateFrame("Frame")
core:RegisterEvent("PLAYER_LOGIN")
core:RegisterEvent("BAG_UPDATE")
core:RegisterEvent("PLAYER_MONEY")
core:RegisterEvent("ITEM_LOCK_CHANGED")

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

core:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        BagsEnh_InitializeDB()
        BagsEnh_CreateOptionsPanel()
        BagsEnh_CreateCategoriesPanel()
        BagsEnh_AutoLoadProfile()
        BagsEnh_InstallHooks()
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
