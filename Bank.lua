-- ============================================================
-- Bank — categorized view of every bank type (v2).
--   character : container-based (main bank -1 + bank bags 5..11), native
--               item buttons -> click / tooltip / shift-move work.
--   guild / personal / realm : Ascension routes all three through the guild
--               bank API (GuildBankFrame.IsPersonalBank / .IsRealmBank flags).
--               Read across ALL tabs and merge them into one categorized view
--               (no more sorting by tab). Read-only for now (phase 2 = moves).
-- One window, reused per bank type (only one bank is ever open at a time).
-- ============================================================

local PADDING = 10
local HEADER_H = 18
local SUBHEADER_H = 15

local bankFrame
local bankMode = "character"   -- character | guild | personal | realm
local bankOpen = false
local bankParents = {}         -- [container] = hidden parent (character bank only)

-- Two button pools: native container buttons (character) and plain read
-- buttons (guild-style, no container behaviour).
local cPool, cActive = {}, {}
local rPool, rActive = {}, {}
local headerPool, headerActive = {}, {}
local subHeaderPool, subHeaderActive = {}, {}

BagsEnh_bankSearch = ""

local function BankContainers()
    local c = { -1 }
    for b = 5, 11 do c[#c + 1] = b end
    return c
end

local function IsGuildStyle() return bankMode ~= "character" end

-- ============================================================
-- Hide the native bank frames off-screen (keeps the session open, unlike
-- :Hide() which would close the bank). Hooked once so re-shows re-stow.
-- ============================================================
local function StowFrame(f)
    if not f then return end
    f:ClearAllPoints()
    f:SetPoint("LEFT", UIParent, "RIGHT", 500, 0)
end
local function HideNative(f)
    if not f or not BagsEnhDB.hideNativeBank then return end
    StowFrame(f)
    if not f.beStowHooked then
        f.beStowHooked = true
        hooksecurefunc(f, "Show", function(self)
            if BagsEnhDB.hideNativeBank then StowFrame(self) end
        end)
    end
end

-- ============================================================
-- Pools
-- ============================================================
local cCount = 0
local function AcquireContainerButton(container)
    local btn = table.remove(cPool)
    if not btn then
        cCount = cCount + 1
        btn = CreateFrame("Button", "BagsEnhBankItem" .. cCount, bankParents[container], "ContainerFrameItemButtonTemplate")
        btn:SetSize(37, 37)
        local icon = _G[btn:GetName() .. "IconTexture"]
        if icon then icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); icon:SetAllPoints(btn) end
        -- Cadre de slot natif retiré (cf. Frames.lua) : il débordait par-dessus
        -- l'icône. La bordure de qualité (beBorder) délimite l'item.
        local nt = btn:GetNormalTexture()
        if nt then
            nt:SetTexture(nil)
            nt:Hide()
        end
        -- Meme nettoyage que dans Frames.lua : le gabarit moderne ajoute des
        -- surfaces que 3.3.5 n'avait pas. Sans effet sur le client ancien.
        BagsEnh_StripModernButton(btn)
        btn.beBorder = BagsEnh_CreateIconBorder(btn, icon or btn)
        local ilvl = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        ilvl:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
        ilvl:SetShadowColor(0, 0, 0, 1); ilvl:SetShadowOffset(1, -1); ilvl:Hide()
        btn.beIlvl = ilvl
        -- 🔴 Infobulle par le LIEN de l'objet, et surtout pas par l'emplacement.
        --
        -- Les trois surfaces de l'addon ne s'y prenaient pas pareil, et une
        -- seule était muette :
        --   sacs       HookScript, le gestionnaire natif reste actif   OK
        --   Warehouse  handler propre + SetHyperlink                   OK
        --   banque     rien, tout reposait sur le natif                KO
        --
        -- 🔴 Et `SetBagItem` est ASYNCHRONE sur ce client : l'infobulle n'est
        -- pas remplie à l'appel, elle l'est quand les données reviennent. Une
        -- première version tentait le natif puis se rabattait sur le lien si
        -- `NumLines() == 0` ; le repli s'affichait bien, puis la réponse tardive
        -- du natif l'ÉCRASAIT avec du vide. D'où « le texte apparaît puis
        -- disparaît, le cadre reste ».
        --
        -- Le test de repli était juste, mais posé trop tôt : il mesurait une
        -- infobulle qui n'avait pas fini de se remplir. La correction n'est pas
        -- d'ajouter une garde, c'est de ne pas appeler ce dont on n'a pas besoin.
        --
        -- `SetHyperlink` suffit, et le Warehouse le prouve sur ce même client
        -- depuis le début. Bénéfice de bord : ça marcherait aussi hors de portée
        -- du banquier, là où aucune API d'emplacement ne répond.
        local function ShowTip(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.beLink)
            GameTooltip:Show()
        end

        btn:SetScript("OnEnter", function(self)
            if not self.beLink then return end
            ShowTip(self)
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- 🔴 Et on la REPOSE tant que la souris est dessus.
        --
        -- `BagsEnh_RefreshBank` commence par ReleaseAll() : tous les boutons
        -- repassent par le pool. Or `PLAYERBANKSLOTS_CHANGED` déclenche ce
        -- rafraîchissement spontanément, le serveur l'émettant de lui-même.
        --
        -- Le bouton survolé est donc libéré sous la souris, l'infobulle perd
        -- son propriétaire, et le conteneur par défaut du tooltip la reprend en
        -- la réancrant sur UIParent — ce qui la réinitialise. D'où « le texte
        -- tient quelques secondes puis disparaît » : le délai n'est pas un
        -- délai, c'est l'attente du prochain événement de banque.
        --
        -- Ce n'est pas un contournement : c'est exactement ce que fait le
        -- gestionnaire natif, et pour cette raison précise. C'est même pourquoi
        -- les sacs n'ont jamais eu le problème — ils l'ont conservé.
        -- 🔴 La condition porte sur AFFICHÉE **et** à nous, pas seulement à nous.
        --
        -- Quand ReleaseAll() libère le bouton sous la souris, WoW déclenche son
        -- OnLeave — donc `GameTooltip:Hide()`. Le bouton revient ensuite,
        -- recyclé à la même place, et son OnUpdate reprend : mais l'infobulle,
        -- bien que CACHÉE, nous appartient toujours. Tester la seule propriété
        -- concluait « rien à faire » et laissait l'écran vide.
        btn:SetScript("OnUpdate", function(self)
            if not self.beLink then return end
            if not self:IsMouseOver() then return end
            if GameTooltip:IsShown() and GameTooltip:GetOwner() == self then return end
            ShowTip(self)
        end)

    else
        btn:SetParent(bankParents[container])
    end
    BagsEnh_SetButtonBag(btn, container)
    cActive[#cActive + 1] = btn
    return btn
end

local function AcquireReadButton()
    local btn = table.remove(rPool)
    if not btn then
        btn = CreateFrame("Button", nil, bankFrame.content)
        btn:SetSize(37, 37)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn); bg:SetTexture("Interface\\Buttons\\WHITE8X8"); bg:SetVertexColor(0, 0, 0, 0.35)
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); icon:SetAllPoints(btn)
        btn.icon = icon
        btn.beBorder = BagsEnh_CreateIconBorder(btn, icon)
        btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        btn.count:SetPoint("BOTTOMRIGHT", -2, 2)
        local ilvl = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        ilvl:SetPoint("TOPRIGHT", -1, -1)
        ilvl:SetShadowColor(0, 0, 0, 1); ilvl:SetShadowOffset(1, -1); ilvl:Hide()
        btn.beIlvl = ilvl
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        btn:SetScript("OnEnter", function(self)
            if not self.tab then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if GameTooltip.SetGuildBankItem then GameTooltip:SetGuildBankItem(self.tab, self.slot) end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- Interaction (phase 2): left = pick up / deposit onto slot,
        -- right = auto-withdraw to bags, shift/ctrl = native modified click
        -- (chat link / dress-up). SetCurrentGuildBankTab first so cross-tab
        -- moves target the right tab.
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnClick", function(self, button)
            if not self.tab then return end
            local link = GetGuildBankItemLink(self.tab, self.slot)
            if link and HandleModifiedItemClick and HandleModifiedItemClick(link) then return end
            if SetCurrentGuildBankTab then SetCurrentGuildBankTab(self.tab) end
            if button == "RightButton" then
                if AutoStoreGuildBankItem then AutoStoreGuildBankItem(self.tab, self.slot) end
            else
                if PickupGuildBankItem then PickupGuildBankItem(self.tab, self.slot) end
            end
        end)
    else
        btn:SetParent(bankFrame.content)
    end
    rActive[#rActive + 1] = btn
    return btn
end

local function ReleaseAll()
    for _, b in ipairs(cActive) do b:Hide(); table.insert(cPool, b) end
    cActive = {}
    for _, b in ipairs(rActive) do b:Hide(); table.insert(rPool, b) end
    rActive = {}
    for _, h in ipairs(headerActive) do h:Hide(); table.insert(headerPool, h) end
    headerActive = {}
    for _, h in ipairs(subHeaderActive) do h:Hide(); table.insert(subHeaderPool, h) end
    subHeaderActive = {}
end

-- Sub-header (material / slot line) for the shared grouping engine. Bouton
-- plutôt que simple FontString : il porte le retrait groupé de la SOUS-section,
-- comme l'en-tête de catégorie le fait pour la section entière.
local function AcquireSubHeader()
    local h = table.remove(subHeaderPool)
    if not h then
        h = CreateFrame("Button", nil, bankFrame.content)
        h:SetHeight(SUBHEADER_H)
        h:RegisterForClicks("LeftButtonUp")
        h.label = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        h.label:SetPoint("LEFT", 0, 0)
        h.label:SetJustifyH("LEFT")
        h:SetScript("OnClick", function(self)
            if not self.catKey then return end
            if not (BagsEnh_ActionModifierDown and BagsEnh_ActionModifierDown()) then return end
            if IsGuildStyle() then
                if BagsEnh_SectionWithdrawGuild then
                    BagsEnh_SectionWithdrawGuild(self.catKey, self.desc)
                end
                return
            end
            if BagsEnh_SectionWithdraw then
                BagsEnh_SectionWithdraw(self.catKey, self.desc)
            end
        end)
    end
    h:Show()
    subHeaderActive[#subHeaderActive + 1] = h
    return h
end

-- Bouton (et non Frame) : l'en-tête porte l'action groupée de RETRAIT, le
-- symétrique du dépôt déclenché depuis les sacs. La banque n'ayant pas de
-- repli de section, le modificateur est la seule action attachée ici.
local function AcquireHeader()
    local h = table.remove(headerPool)
    if not h then
        h = CreateFrame("Button", nil, bankFrame.content)
        h:SetHeight(HEADER_H)
        h:RegisterForClicks("LeftButtonUp")
        h.dot = h:CreateTexture(nil, "OVERLAY")
        h.dot:SetTexture("Interface\\Buttons\\WHITE8X8"); h.dot:SetSize(3, 12); h.dot:SetPoint("LEFT", 0, 0)
        h.label = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h.label:SetPoint("LEFT", 9, 0); h.label:SetJustifyH("LEFT")
        h:SetScript("OnClick", function(self)
            if not self.catKey then return end
            if not (BagsEnh_ActionModifierDown and BagsEnh_ActionModifierDown()) then return end
            -- Guilde/royaume : déplacement par une autre API, comme le compactage.
            if IsGuildStyle() then
                if BagsEnh_SectionWithdrawGuild then
                    BagsEnh_SectionWithdrawGuild(self.catKey, self.desc)
                end
                return
            end
            if BagsEnh_SectionWithdraw then BagsEnh_SectionWithdraw(self.catKey, self.desc) end
        end)
    end
    h:Show()
    headerActive[#headerActive + 1] = h
    return h
end

-- ============================================================
-- Collect items per bank type -> raw list {link, texture, count, quality, id}
-- ============================================================
local function CollectCharacter()
    local items, used, total, unresolved = {}, 0, 0, false
    for _, c in ipairs(BankContainers()) do
        local n = BagsEnh_GetContainerNumSlots(c) or 0
        total = total + n
        for slot = 1, n do
            local texture, count, _, quality, _, _, link = BagsEnh_GetContainerItemInfo(c, slot)
            if texture then
                used = used + 1
                items[#items + 1] = { link = link, texture = texture, count = count,
                    quality = quality, container = c, slot = slot }
            end
        end
    end
    return items, used, total, unresolved
end

local function CollectGuildStyle()
    local items, used = {}, 0
    local nTabs = GetNumGuildBankTabs() or 0
    local maxSlots = MAX_GUILDBANK_SLOTS_PER_TAB or 98
    for tab = 1, nTabs do
        for slot = 1, maxSlots do
            local link = GetGuildBankItemLink(tab, slot)
            if link then
                local texture, count = GetGuildBankItemInfo(tab, slot)
                local _, _, quality = GetItemInfo(link)
                used = used + 1
                items[#items + 1] = { link = link, texture = texture, count = count or 1,
                    quality = quality, tab = tab, slot = slot }
            end
        end
    end
    return items, used, used, false
end

-- ============================================================
-- Render
-- ============================================================
local function Matches(link)
    local q = BagsEnh_bankSearch
    if not q or q == "" then return true end
    if not link then return false end
    local name = GetItemInfo(link)
    return name and name:lower():find(q, 1, true) ~= nil
end

function BagsEnh_RefreshBank()
    if not bankFrame or not bankFrame:IsShown() then return end
    local ld = BagsEnh_L()
    ReleaseAll()

    -- Explicit branch: and/or would truncate the collectors' multiple returns.
    local raw, used, total
    if IsGuildStyle() then
        raw, used, total = CollectGuildStyle()
    else
        raw, used, total = CollectCharacter()
    end
    local unresolved = false

    -- Group by category
    local groups = {}
    for _, it in ipairs(raw) do
        local cat, resolved, subCat, equipLoc = BagsEnh_Categorize(it.link)
        if not resolved then unresolved = true end
        it.cat, it.subCat, it.equipLoc = cat, subCat, equipLoc
        groups[cat] = groups[cat] or {}
        table.insert(groups[cat], it)
    end

    local iconSize = BagsEnhDB.iconSize or 37
    local spacing = BagsEnhDB.spacing or 4
    local xStep, yStep = iconSize + spacing, iconSize + spacing
    local SECTION_GAP = 12
    local showIlvl = BagsEnhDB.showItemLevel

    local viewW = bankFrame.scroll:GetWidth()
    if not viewW or viewW < 1 then viewW = bankFrame:GetWidth() - PADDING * 2 end
    bankFrame.content:SetWidth(viewW)
    local perRow = math.max(1, math.floor((viewW + spacing) / xStep))

    local function StyleCommon(btn, it, dim)
        local qc = it.quality and it.quality > 1 and BagsEnh_QUALITY_COLORS[it.quality]
        if qc then btn.beBorder:SetVertexColor(qc[1], qc[2], qc[3], 0.9); btn.beBorder:Show()
        else btn.beBorder:Hide() end
        if showIlvl and it.equipLoc and BagsEnh_EQUIPLOC_ORDER[it.equipLoc] then
            local _, _, _, iLevel = GetItemInfo(it.link)
            if iLevel and iLevel >= 1 then
                if qc then btn.beIlvl:SetTextColor(qc[1], qc[2], qc[3]) else btn.beIlvl:SetTextColor(1, 1, 1) end
                btn.beIlvl:SetText(iLevel); btn.beIlvl:Show()
            else btn.beIlvl:Hide() end
        else btn.beIlvl:Hide() end
        btn:SetAlpha(dim and 0.25 or 1)
    end

    local function PlaceButton(it, col, y)
        local dim = not Matches(it.link)
        local btn
        if IsGuildStyle() then
            btn = AcquireReadButton()
            btn.tab, btn.slot = it.tab, it.slot
            btn.icon:SetTexture(it.texture)
            btn.icon:SetDesaturated(dim)
            if it.count and it.count > 1 then btn.count:SetText(it.count); btn.count:Show() else btn.count:Hide() end
        else
            btn = AcquireContainerButton(it.container)
            btn:SetID(it.slot)
            -- Le lien porte toute l'infobulle. Posé au rendu, où l'objet est
            -- connu ; le conteneur ne sert plus à rien depuis qu'on n'appelle
            -- plus SetBagItem.
            btn.beLink = it.link
            SetItemButtonTexture(btn, it.texture)
            SetItemButtonCount(btn, it.count)
            local icon = _G[btn:GetName() .. "IconTexture"]
            if icon then icon:SetDesaturated(dim) end
        end
        btn:SetSize(iconSize, iconSize)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", bankFrame.content, "TOPLEFT", col * xStep, -y)
        StyleCommon(btn, it, dim)
        btn:Show()
    end

    local y = 0
    for _, cat in ipairs(BagsEnh_GetCategoryOrder()) do
        local items = groups[cat]
        if cat == "hidden" and not BagsEnhDB.showHidden then items = nil end
        if items and #items > 0 then
            local header = AcquireHeader()
            header.catKey = cat          -- cible de l'action groupée de retrait
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", bankFrame.content, "TOPLEFT", 0, -y)
            header:SetWidth(viewW)
            local cr, cg, cb = BagsEnh_CategoryColor(cat)
            header.dot:SetVertexColor(cr, cg, cb)
            header.label:SetText(("|cff%s%s|r |cff777777(%d)|r"):format(
                BagsEnh_ColorHex(cr, cg, cb), BagsEnh_CategoryLabel(cat), #items))
            y = y + HEADER_H

            -- Same grouping engine as the bags (material -> slot sub-headers,
            -- honouring the Display panel modes).
            local grouping = BagsEnh_GroupingFor(cat)
            if grouping then
                y = BagsEnh_LayoutGrouped(items, grouping, {
                    perRow = perRow, yStep = yStep, subH = SUBHEADER_H,
                    place = function(it, col, yy) PlaceButton(it, col, yy) end,
                    -- `desc` (4e arg) décrit la sous-section : { sub = matériau }
                    -- et/ou { slot = emplacement }. Il était ignoré ici ; il
                    -- devient la cible du retrait groupé.
                    header = function(text, indent, yy, desc)
                        local sh = AcquireSubHeader()
                        sh.catKey, sh.desc = cat, desc
                        sh:ClearAllPoints()
                        sh:SetPoint("TOPLEFT", bankFrame.content, "TOPLEFT", indent, -yy)
                        sh:SetWidth(math.max(1, viewW - indent))
                        sh.label:SetText(text)
                    end,
                }, y)
            else
                table.sort(items, BagsEnh_CmpMaterialFirst)
                local col = 0
                for _, it in ipairs(items) do
                    PlaceButton(it, col, y)
                    col = col + 1
                    if col >= perRow then col = 0; y = y + yStep end
                end
                if col > 0 then y = y + yStep end
            end
            y = y + SECTION_GAP
        end
    end

    bankFrame.content:SetHeight(math.max(y, 10))
    local viewH = bankFrame:GetHeight() - 30 - 24
    local maxScroll = math.max(0, y - viewH)
    bankFrame.scroll.maxScroll = maxScroll
    if bankFrame.scroll:GetVerticalScroll() > maxScroll then bankFrame.scroll:SetVerticalScroll(maxScroll) end

    if IsGuildStyle() then
        bankFrame.slots:SetText(ld.BANK_ITEMS:format(used))
    else
        -- Banque perso : total et used sont réels → on affiche aussi les
        -- emplacements libres (demande retour joueur).
        bankFrame.slots:SetText(ld.BANK_SLOTS_FREE:format(used, total, total - used))
    end

    if unresolved and C_Timer and C_Timer.After then
        bankFrame.retries = (bankFrame.retries or 0) + 1
        if bankFrame.retries <= 5 then C_Timer.After(0.2, BagsEnh_RefreshBank) end
    else
        bankFrame.retries = 0
    end
end

-- Deposit whatever the cursor holds into the first free slot of the current
-- bank (dropping onto the window, since the merged view shows no empty slots).
local function BankDeposit()
    if not CursorHasItem() then return end
    if IsGuildStyle() then
        local nTabs = GetNumGuildBankTabs() or 0
        local maxSlots = MAX_GUILDBANK_SLOTS_PER_TAB or 98
        for tab = 1, nTabs do
            local _, _, _, canDeposit = GetGuildBankTabInfo(tab)
            local allow = canDeposit or bankMode == "personal" or bankMode == "realm"
            if allow then
                for slot = 1, maxSlots do
                    if not GetGuildBankItemLink(tab, slot) then
                        if SetCurrentGuildBankTab then SetCurrentGuildBankTab(tab) end
                        PickupGuildBankItem(tab, slot)
                        return
                    end
                end
            end
        end
    else
        for _, c in ipairs(BankContainers()) do
            for slot = 1, BagsEnh_GetContainerNumSlots(c) or 0 do
                if not BagsEnh_GetContainerItemInfo(c, slot) then
                    BagsEnh_PickupContainerItem(c, slot)
                    return
                end
            end
        end
    end
end

-- ============================================================
-- Frame
-- ============================================================
local function TitleForMode()
    local ld = BagsEnh_L()
    if bankMode == "guild" then return ld.BANK_TITLE_GUILD
    elseif bankMode == "personal" then return ld.BANK_TITLE_PERSONAL
    elseif bankMode == "realm" then return ld.BANK_TITLE_REALM
    else return ld.BANK_TITLE end
end

local function CloseSession()
    if bankMode == "character" then
        if CloseBankFrame then CloseBankFrame() end
    else
        if CloseGuildBankFrame then CloseGuildBankFrame() end
    end
end

local function CreateBankFrame()
    if bankFrame then return bankFrame end
    local ld = BagsEnh_L()
    local ac = BagsEnh_ACCENT or { 0.10, 0.80, 1.00 }

    bankFrame = CreateFrame("Frame", "BagsEnhBankFrame", UIParent)
    bankFrame:SetSize(BagsEnhDB.bankWidth or 460, BagsEnhDB.bankHeight or 500)
    bankFrame:SetPoint("CENTER", BagsEnhDB.bankPosX or 260, BagsEnhDB.bankPosY or 0)
    bankFrame:SetScale(BagsEnhDB.scale or 1.0)
    BagsEnh_Backdrop(bankFrame):SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bankFrame:SetBackdropColor(0.055, 0.075, 0.09, 0.94)
    bankFrame:SetBackdropBorderColor(ac[1], ac[2], ac[3], 0.55)
    bankFrame:SetMovable(true); bankFrame:EnableMouse(true)
    bankFrame:SetResizable(true)
    if bankFrame.SetMinResize then bankFrame:SetMinResize(240, 220) end
    bankFrame:RegisterForDrag("LeftButton")
    bankFrame:SetScript("OnDragStart", bankFrame.StartMoving)
    bankFrame:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local cx, cy = s:GetCenter(); local px, py = UIParent:GetCenter()
        BagsEnhDB.bankPosX, BagsEnhDB.bankPosY = cx - px, cy - py
        s:ClearAllPoints(); s:SetPoint("CENTER", BagsEnhDB.bankPosX, BagsEnhDB.bankPosY)
    end)
    bankFrame:SetFrameStrata("HIGH")
    bankFrame:Hide()

    local tbar = bankFrame:CreateTexture(nil, "BORDER")
    tbar:SetTexture("Interface\\Buttons\\WHITE8X8"); tbar:SetVertexColor(1, 1, 1, 0.045)
    tbar:SetPoint("TOPLEFT", 1, -1); tbar:SetPoint("TOPRIGHT", -1, -1); tbar:SetHeight(26)
    local tdiv = bankFrame:CreateTexture(nil, "BORDER")
    tdiv:SetTexture("Interface\\Buttons\\WHITE8X8"); tdiv:SetVertexColor(ac[1], ac[2], ac[3], 0.35)
    tdiv:SetPoint("TOPLEFT", 1, -27); tdiv:SetPoint("TOPRIGHT", -1, -27); tdiv:SetHeight(1)

    bankFrame.title = bankFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bankFrame.title:SetPoint("LEFT", bankFrame, "TOPLEFT", PADDING, -14)

    local close = CreateFrame("Button", nil, bankFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() bankFrame:Hide() end)

    -- Search
    local search = CreateFrame("EditBox", "BagsEnhBankSearch", bankFrame, "InputBoxTemplate")
    search:SetSize(150, 18)
    search:SetPoint("TOPRIGHT", -32, -6)
    search:SetAutoFocus(false); search:SetTextInsets(4, 4, 0, 0)
    search:SetFontObject("GameFontHighlightSmall")
    local ph = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 6, 0); ph:SetText(ld.SEARCH_PLACEHOLDER)
    search.placeholder = ph
    search:SetScript("OnTextChanged", function(self)
        local t = self:GetText()
        self.placeholder:SetShown(t == "")
        BagsEnh_bankSearch = t:lower()
        BagsEnh_RefreshBank()
    end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    bankFrame.search = search

    bankFrame.slots = bankFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bankFrame.slots:SetPoint("BOTTOMLEFT", PADDING, PADDING - 2)

    -- Compacter les piles partielles (F7) — banque du personnage uniquement
    -- (les banques guilde/royaume passent par une autre API de déplacement).
    bankFrame.compact = CreateFrame("Button", nil, bankFrame, "UIPanelButtonTemplate")
    bankFrame.compact:SetSize(84, 20)
    bankFrame.compact:SetPoint("BOTTOMRIGHT", -24, PADDING - 4)
    bankFrame.compact:SetText(ld.MERGE_BTN)
    bankFrame.compact:SetScript("OnClick", function()
        if IsGuildStyle() then
            BagsEnh_Print(ld.MERGE_BANK_GUILD)
            return
        end
        if BagsEnh_MergeBankStacks then BagsEnh_MergeBankStacks() end
    end)

    local scroll = CreateFrame("ScrollFrame", "BagsEnhBankScroll", bankFrame)
    scroll:SetPoint("TOPLEFT", PADDING, -30); scroll:SetPoint("BOTTOMRIGHT", -PADDING, 24)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxS = self.maxScroll or 0
        self:SetVerticalScroll(math.max(0, math.min(maxS, self:GetVerticalScroll() - delta * 40)))
    end)
    bankFrame.scroll = scroll

    bankFrame.content = CreateFrame("Frame", nil, scroll)
    bankFrame.content:SetSize(400, 10)
    scroll:SetScrollChild(bankFrame.content)

    for _, c in ipairs(BankContainers()) do
        local p = CreateFrame("Frame", "BagsEnhBankBag" .. (c < 0 and "M" or c), bankFrame.content)
        p:SetID(c); p:SetAllPoints(bankFrame.content)
        bankParents[c] = p
    end

    -- Resize handle (bottom-right) — more width = more columns, like the bags
    local grip = CreateFrame("Button", nil, bankFrame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() bankFrame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        bankFrame:StopMovingOrSizing()
        BagsEnhDB.bankWidth = bankFrame:GetWidth()
        BagsEnhDB.bankHeight = bankFrame:GetHeight()
        BagsEnh_RefreshBank()
    end)
    bankFrame:SetScript("OnSizeChanged", function()
        if bankFrame:IsShown() then BagsEnh_RefreshBank() end
    end)

    -- Drop an item onto the window to deposit it (no empty slots are shown, so
    -- this is how you put things in).
    bankFrame:SetScript("OnReceiveDrag", function() BankDeposit() end)
    bankFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and CursorHasItem() then BankDeposit() end
    end)

    -- Closing our window ends the bank session (unless the session already ended)
    bankFrame:SetScript("OnHide", function()
        if bankOpen then bankOpen = false; CloseSession() end
    end)
    return bankFrame
end

local function OpenWith(mode)
    CreateBankFrame()
    bankMode = mode
    bankOpen = true
    bankFrame.retries = 0
    bankFrame.title:SetText("|cff00ccff" .. TitleForMode() .. "|r")
    bankFrame:Show()
    BagsEnh_RefreshBank()
end

-- ============================================================
-- Public entry points (wired from Core events)
-- ============================================================
function BagsEnh_ShowBank()          -- character bank (BANKFRAME_OPENED)
    HideNative(BankFrame)
    OpenWith("character")
end

function BagsEnh_ShowGuildBank()     -- guild / personal / realm (GUILDBANKFRAME_OPENED)
    local mode = "guild"
    if GuildBankFrame and GuildBankFrame.IsPersonalBank then mode = "personal"
    elseif GuildBankFrame and GuildBankFrame.IsRealmBank then mode = "realm" end
    -- Guild-style banks are interactive now (left = move, right = withdraw,
    -- drop = deposit), so the native frame can be stowed too.
    HideNative(GuildBankFrame)
    -- Pull every tab from the server so the merged view is complete
    local n = GetNumGuildBankTabs() or 0
    local initial = GetCurrentGuildBankTab and GetCurrentGuildBankTab() or 1
    for tab = 1, n do QueryGuildBankTab(tab) end
    if n > 0 and GetCurrentGuildBankTab then QueryGuildBankTab(initial) end
    OpenWith(mode)
end

function BagsEnh_HideBank()          -- from a *_CLOSED event: session already ended
    if bankFrame then bankOpen = false; bankFrame:Hide() end
end

function BagsEnh_IsBankShown()
    return bankFrame and bankFrame:IsShown()
end
