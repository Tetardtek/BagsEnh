-- ============================================================
-- Actions — Ctrl+clic contextuel sur une section (F1).
--   marchand ouvert       -> vend la section (objets à prix de vente > 0)
--   banque perso ouverte  -> dépose la section en banque
--   rien d'ouvert         -> aucune action
--
-- Branché sur les EN-TÊTES de section (boutons custom) : aucun risque de taint,
-- contrairement aux boutons d'items dont l'OnClick natif reste intact.
-- Mécanique : UseContainerItem() EST le « clic droit » qui s'adapte au
-- contexte du jeu — il vend au marchand, dépose banque ouverte. On se contente
-- de le déclencher sur les bons slots, avec les gardes de contexte.
-- ============================================================

local BAGS = { 0, 1, 2, 3, 4 }
local ctx = { merchant = false, bank = false }

-- Renseigné par Core sur MERCHANT_SHOW/CLOSED et BANKFRAME_OPENED/CLOSED.
function BagsEnh_SetMerchantOpen(on) ctx.merchant = (on and true) or false end
function BagsEnh_SetBankOpen(on)     ctx.bank = (on and true) or false end

-- "merchant" | "bank" | nil
function BagsEnh_BagContext()
    if ctx.merchant then return "merchant" end
    if ctx.bank then return "bank" end
    return nil
end

-- Modificateur configurable (Panel Affichage) : ctrl (défaut) | alt | shift.
function BagsEnh_ActionModifierDown()
    local m = (BagsEnhDB and BagsEnhDB.actionModifier) or "ctrl"
    if m == "alt" then return IsAltKeyDown() end
    if m == "shift" then return IsShiftKeyDown() end
    return IsControlKeyDown()
end

local function Msg(s) DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBagsEnh:|r " .. s) end

local function Coin(c)
    return (GetCoinTextureString and GetCoinTextureString(c)) or tostring(c)
end

-- Slots de sacs de la catégorie (snapshot avant de bouger). `desc` optionnel
-- restreint à une SOUS-section : desc.sub (matériau) et/ou desc.slot (emplacement).
local function SectionSlots(catKey, desc)
    local out = {}
    for _, bag in ipairs(BAGS) do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local _, _, locked, _, _, _, link = GetContainerItemInfo(bag, slot)
            if link and not locked then
                local cat, _, subCat, equipLoc = BagsEnh_Categorize(link)
                if cat == catKey
                        and (not desc or not desc.sub or (subCat or "?") == desc.sub)
                        and (not desc or not desc.slot or equipLoc == desc.slot) then
                    out[#out + 1] = { bag = bag, slot = slot, link = link }
                end
            end
        end
    end
    return out
end

-- Action groupée sur une section (ou sous-section via `desc`), selon la fenêtre.
function BagsEnh_SectionAction(catKey, desc)
    local c = BagsEnh_BagContext()
    if not c then return end                    -- rien d'ouvert : no-op
    local ld = BagsEnh_L()
    local slots = SectionSlots(catKey, desc)
    local n = 0
    if c == "merchant" then
        local gold = 0
        for _, it in ipairs(slots) do
            local sell = select(11, GetItemInfo(it.link))
            if sell and sell > 0 then           -- ne vend jamais un objet sans valeur
                local _, count = GetContainerItemInfo(it.bag, it.slot)
                gold = gold + sell * (count or 1)
                UseContainerItem(it.bag, it.slot)
                n = n + 1
            end
        end
        Msg(n > 0 and ld.ACT_SOLD:format(n, Coin(gold)) or ld.ACT_NOTHING_SELL)
    elseif c == "bank" then
        for _, it in ipairs(slots) do
            UseContainerItem(it.bag, it.slot)   -- banque ouverte : déplace en banque
            n = n + 1
        end
        Msg(n > 0 and ld.ACT_DEPOSITED:format(n) or ld.ACT_NOTHING_DEPOSIT)
    end
end
