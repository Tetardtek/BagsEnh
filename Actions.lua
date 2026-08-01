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
local ctx = { merchant = false, bank = false, gbank = false }

-- Renseigné par Core sur MERCHANT_SHOW/CLOSED, BANKFRAME_OPENED/CLOSED et
-- GUILDBANKFRAME_OPENED/CLOSED. Sur Ascension, les banques guilde, perso et
-- royaume passent TOUTES par l'API guild bank : sans ce troisième drapeau, le
-- dépôt groupé restait muet devant elles (aucun contexte détecté).
function BagsEnh_SetMerchantOpen(on)  ctx.merchant = (on and true) or false end
function BagsEnh_SetBankOpen(on)      ctx.bank = (on and true) or false end
function BagsEnh_SetGuildBankOpen(on) ctx.gbank = (on and true) or false end

-- "merchant" | "bank" | nil
-- Les deux familles de banques rendent "bank" : le DÉPÔT est identique pour
-- l'une et l'autre (UseContainerItem depuis les sacs). Seul le RETRAIT diffère,
-- et il est traité à part, dans la fenêtre de banque.
function BagsEnh_BagContext()
    if ctx.merchant then return "merchant" end
    if ctx.bank or ctx.gbank then return "bank" end
    return nil
end

-- Modificateur configurable (Panel Affichage) : ctrl (défaut) | alt | shift.
function BagsEnh_ActionModifierDown()
    local m = (BagsEnhDB and BagsEnhDB.actionModifier) or "ctrl"
    if m == "alt" then return IsAltKeyDown() end
    if m == "shift" then return IsShiftKeyDown() end
    return IsControlKeyDown()
end


local function Coin(c)
    return (GetCoinTextureString and GetCoinTextureString(c)) or tostring(c)
end

-- Garde-fous de la vente groupée : un objet au-dessus du plafond de qualité
-- ou de niveau n'est JAMAIS vendu, même s'il a une valeur marchande. Le but
-- est d'éviter la bêtise irréversible (un épique parti d'un Ctrl+clic), pas
-- de filtrer finement — d'où deux plafonds simples et cumulatifs.
-- quality : 0 médiocre … 5 légendaire. ilvl 0 = plafond désactivé.
local function SellProtected(quality, ilvl)
    local maxQ = BagsEnhDB and BagsEnhDB.sellMaxQuality
    if maxQ and quality and quality > maxQ then return true end
    local maxI = BagsEnhDB and BagsEnhDB.sellMaxILvl
    if maxI and maxI > 0 and ilvl and ilvl > maxI then return true end
    return false
end

-- Slots de la catégorie dans `containers` (snapshot avant de bouger). `desc`
-- optionnel restreint à une SOUS-section : desc.sub (matériau) et/ou
-- desc.slot (emplacement). Par défaut les sacs du personnage.
local function SectionSlots(catKey, desc, containers)
    local out = {}
    for _, bag in ipairs(containers or BAGS) do
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
        local gold, kept = 0, 0
        for _, it in ipairs(slots) do
            local _, _, quality, ilvl, _, _, _, _, _, _, sell = GetItemInfo(it.link)
            if sell and sell > 0 then           -- ne vend jamais un objet sans valeur
                if SellProtected(quality, ilvl) then
                    kept = kept + 1             -- au-dessus d'un plafond : on laisse
                else
                    local _, count = GetContainerItemInfo(it.bag, it.slot)
                    gold = gold + sell * (count or 1)
                    UseContainerItem(it.bag, it.slot)
                    n = n + 1
                end
            end
        end
        -- Le nombre de protégés est TOUJOURS dit quand il y en a : sans lui, une
        -- section qui ne part pas est indiscernable d'une section vide.
        if n > 0 then
            BagsEnh_Print(kept > 0 and ld.ACT_SOLD_KEPT:format(n, Coin(gold), kept)
                                    or ld.ACT_SOLD:format(n, Coin(gold)))
        else
            BagsEnh_Print(kept > 0 and ld.ACT_ALL_KEPT:format(kept)
                                    or ld.ACT_NOTHING_SELL)
        end
    elseif c == "bank" then
        for _, it in ipairs(slots) do
            UseContainerItem(it.bag, it.slot)   -- banque ouverte : déplace en banque
            n = n + 1
        end
        BagsEnh_Print(n > 0 and ld.ACT_DEPOSITED:format(n) or ld.ACT_NOTHING_DEPOSIT)
    end
end

-- Sens inverse : retire une section de la BANQUE du personnage vers les sacs.
-- Même mécanique (UseContainerItem = le clic droit contextuel), mais appliquée
-- aux conteneurs de banque. Réservé à la banque du personnage : les banques
-- guilde/royaume passent par une autre API de déplacement, comme le compactage.
--
-- Comme pour le dépôt, `n` compte les déplacements DEMANDÉS, pas ceux qui ont
-- abouti : UseContainerItem est asynchrone et échoue en silence si les sacs
-- sont pleins. Le chiffre est donc un majorant — cohérent avec ACT_DEPOSITED,
-- et suffisant tant qu'on ne promet pas un bilan exact.
local BANK_CONTAINERS = { -1, 5, 6, 7, 8, 9, 10, 11 }

function BagsEnh_SectionWithdraw(catKey, desc)
    if not ctx.bank then return end             -- banque fermée : no-op
    local ld = BagsEnh_L()
    local slots = SectionSlots(catKey, desc, BANK_CONTAINERS)
    local n = 0
    for _, it in ipairs(slots) do
        UseContainerItem(it.bag, it.slot)       -- banque ouverte : renvoie aux sacs
        n = n + 1
    end
    BagsEnh_Print(n > 0 and ld.ACT_WITHDRAWN:format(n) or ld.ACT_NOTHING_WITHDRAW)
end

-- Même geste pour les banques guilde / perso / royaume. Elles ne sont PAS des
-- conteneurs : leurs emplacements se lisent par (onglet, slot) et se retirent
-- avec AutoStoreGuildBankItem — l'API qu'utilise déjà le clic droit d'un item
-- dans Bank.lua. D'où une fonction séparée plutôt qu'un paramètre de plus.
function BagsEnh_SectionWithdrawGuild(catKey, desc)
    if not ctx.gbank then return end
    local ld = BagsEnh_L()
    -- Repli : si le serveur n'expose pas l'API de retrait, on le dit plutôt
    -- que de laisser un clic sans effet ni explication.
    if not AutoStoreGuildBankItem then
        BagsEnh_Print(ld.ACT_WITHDRAW_GUILD)
        return
    end
    local nTabs = GetNumGuildBankTabs() or 0
    local maxSlots = MAX_GUILDBANK_SLOTS_PER_TAB or 98
    local n = 0
    for tab = 1, nTabs do
        for slot = 1, maxSlots do
            local link = GetGuildBankItemLink(tab, slot)
            if link then
                local cat, _, subCat, equipLoc = BagsEnh_Categorize(link)
                if cat == catKey
                        and (not desc or not desc.sub or (subCat or "?") == desc.sub)
                        and (not desc or not desc.slot or equipLoc == desc.slot) then
                    -- Cibler l'onglet avant de retirer : sans ça, un retrait
                    -- inter-onglets s'applique à l'onglet courant.
                    if SetCurrentGuildBankTab then SetCurrentGuildBankTab(tab) end
                    if AutoStoreGuildBankItem then AutoStoreGuildBankItem(tab, slot) end
                    n = n + 1
                end
            end
        end
    end
    BagsEnh_Print(n > 0 and ld.ACT_WITHDRAWN:format(n) or ld.ACT_NOTHING_WITHDRAW)
end
