-- ============================================================
-- Version — annonce de version entre joueurs (F6).
-- Chaque client diffuse sa version via les messages d'addon (guilde / groupe).
-- Si un pair annonce une version SUPÉRIEURE, on prévient le joueur une fois par
-- session avec le lien du dépôt GitHub. Aucune dépendance, dégradation propre
-- si le serveur ne relaie pas les messages d'addon.
-- ============================================================

local PREFIX = "BagsEnh"
local GITHUB = "https://github.com/Tetardtek/BagsEnh"
local VERSION = (GetAddOnMetadata and GetAddOnMetadata("BagsEnh", "Version")) or "?"

local function Msg(s) DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBagsEnh:|r " .. s) end

local function ToTuple(v)
    local t = {}
    for n in tostring(v or ""):gmatch("%d+") do t[#t + 1] = tonumber(n) end
    return t
end

-- a strictement plus récent que b ?
local function VerGreater(a, b)
    local ta, tb = ToTuple(a), ToTuple(b)
    local n = math.max(#ta, #tb)
    for i = 1, n do
        local x, y = ta[i] or 0, tb[i] or 0
        if x ~= y then return x > y end
    end
    return false
end

local notified = false
local function Notify(v)
    if not notified and VerGreater(v, VERSION) then
        notified = true
        Msg(BagsEnh_L().VER_NEW:format(v, GITHUB))
    end
end

local function Broadcast()
    if VERSION == "?" then return end
    local msg = "V:" .. VERSION
    if IsInGuild and IsInGuild() then SendAddonMessage(PREFIX, msg, "GUILD") end
    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        SendAddonMessage(PREFIX, msg, "RAID")
    elseif GetNumPartyMembers and GetNumPartyMembers() > 0 then
        SendAddonMessage(PREFIX, msg, "PARTY")
    end
end

-- Affichage manuel (/be version).
function BagsEnh_VersionInfo()
    Msg("v" .. VERSION .. " — " .. GITHUB)
end

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")
f:RegisterEvent("RAID_ROSTER_UPDATE")

local me = nil
local pending, acc, lastCast = false, 0, -100

f:SetScript("OnEvent", function(self, event, a1, a2, a3, a4)
    if event == "CHAT_MSG_ADDON" then
        me = me or UnitName("player")
        local prefix, message, sender = a1, a2, a4
        if prefix == PREFIX and sender ~= me then
            local v = message and message:match("^V:([%d%.]+)")
            if v then Notify(v) end
        end
    else
        -- login ou changement de roster/groupe : (re)diffuser bientôt
        pending = true
    end
end)

-- 3.3.5 n'a pas de timer fiable : on temporise via OnUpdate (laisser le roster
-- se charger après le login) et on plafonne à une diffusion toutes les 25 s.
f:SetScript("OnUpdate", function(self, e)
    if not pending then return end
    acc = acc + e
    if acc < 6 then return end
    acc = 0; pending = false
    local now = GetTime()
    if now - lastCast > 25 then
        lastCast = now
        Broadcast()
    end
end)
