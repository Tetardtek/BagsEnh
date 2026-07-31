-- ============================================================
-- Warehouse — read-only viewer over the cross-character cache (v2 phase 3).
-- Spawnable: each call to BagsEnh_OpenWarehouse() makes an independent window
-- (own frame + pools), so several can be open at once. Pick a character and a
-- container (bags / bank) to browse whatever that character last saw. No NPC
-- needed; no interaction (it's cached data, not live).
-- ============================================================

local PADDING = 10
local HEADER_H = 18
local SUBHEADER_H = 15
local TOPCHROME = 58      -- title bar (26) + control row (~30)
local BOTCHROME = 24
local viewerN = 0

-- ============================================================
-- Per-instance pools
-- ============================================================
local function AcquireItem(v)
    local btn = table.remove(v.pool)
    if not btn then
        btn = CreateFrame("Button", nil, v.content)
        btn:SetSize(37, 37)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn); bg:SetTexture("Interface\\Buttons\\WHITE8X8"); bg:SetVertexColor(0, 0, 0, 0.35)
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); icon:SetAllPoints(btn); btn.icon = icon
        btn.beBorder = BagsEnh_CreateIconBorder(btn, icon)
        btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        btn.count:SetPoint("BOTTOMRIGHT", -2, 2)
        local ilvl = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        ilvl:SetPoint("TOPRIGHT", -1, -1); ilvl:SetShadowColor(0, 0, 0, 1); ilvl:SetShadowOffset(1, -1); ilvl:Hide()
        btn.beIlvl = ilvl
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        btn:SetScript("OnEnter", function(self)
            if not self.beLink then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.beLink)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        btn:SetParent(v.content)
    end
    v.active[#v.active + 1] = btn
    return btn
end

local function AcquireHeader(v)
    local h = table.remove(v.hpool)
    if not h then
        h = CreateFrame("Frame", nil, v.content)
        h:SetHeight(HEADER_H)
        h.dot = h:CreateTexture(nil, "OVERLAY")
        h.dot:SetTexture("Interface\\Buttons\\WHITE8X8"); h.dot:SetSize(3, 12); h.dot:SetPoint("LEFT", 0, 0)
        h.label = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h.label:SetPoint("LEFT", 9, 0); h.label:SetJustifyH("LEFT")
    end
    h:Show()
    v.hactive[#v.hactive + 1] = h
    return h
end

local function AcquireSubHeader(v)
    local h = table.remove(v.spool)
    if not h then
        h = v.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        h:SetJustifyH("LEFT")
    end
    h:Show()
    v.sactive[#v.sactive + 1] = h
    return h
end

local function ReleaseAll(v)
    for _, b in ipairs(v.active) do b:Hide(); table.insert(v.pool, b) end
    v.active = {}
    for _, h in ipairs(v.hactive) do h:Hide(); table.insert(v.hpool, h) end
    v.hactive = {}
    for _, h in ipairs(v.sactive) do h:Hide(); table.insert(v.spool, h) end
    v.sactive = {}
end

local function Matches(v, link)
    local q = v.search
    if not q or q == "" then return true end
    if not link then return false end
    local name = GetItemInfo(link)
    return name and name:lower():find(q, 1, true) ~= nil
end

-- ============================================================
-- Render (single column, read-only, sourced from the cache)
-- ============================================================
local function Refresh(v)
    if not v.frame:IsShown() then return end
    local ld = BagsEnh_L()
    ReleaseAll(v)

    local c = BagsEnh_GetCache(v.char)
    local rawItems
    if v.container == "realmbank" then          -- store partagé par serveur (F4)
        local rb = BagsEnh_GetRealmBank(BagsEnh_RealmOf(v.char))
        rawItems = rb and rb.items or {}
    else
        rawItems = c and c[v.container] or {}
    end
    local unresolved = false

    local groups, count = {}, 0
    for _, it in ipairs(rawItems) do
        local cat, resolved, subCat, equipLoc = BagsEnh_Categorize(it.link)
        if not resolved then unresolved = true end
        local _, _, quality, _, _, _, _, _, _, texture = GetItemInfo(it.link)
        groups[cat] = groups[cat] or {}
        table.insert(groups[cat], {
            link = it.link, count = it.count, quality = quality,
            texture = texture, subCat = subCat, equipLoc = equipLoc,
        })
        count = count + 1
    end

    local iconSize = BagsEnhDB.iconSize or 37
    local spacing = BagsEnhDB.spacing or 4
    local xStep, yStep = iconSize + spacing, iconSize + spacing
    local SECTION_GAP = 12
    local showIlvl = BagsEnhDB.showItemLevel

    local viewW = v.scroll:GetWidth()
    if not viewW or viewW < 1 then viewW = v.frame:GetWidth() - PADDING * 2 end
    v.content:SetWidth(viewW)
    local perRow = math.max(1, math.floor((viewW + spacing) / xStep))

    local function PlaceButton(it, col, y)
        local dim = not Matches(v, it.link)
        local btn = AcquireItem(v)
        btn.beLink = it.link
        btn:SetSize(iconSize, iconSize)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", v.content, "TOPLEFT", col * xStep, -y)
        btn.icon:SetTexture(it.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        btn.icon:SetDesaturated(dim)
        if it.count and it.count > 1 then btn.count:SetText(it.count); btn.count:Show() else btn.count:Hide() end
        local qc = it.quality and it.quality > 1 and BagsEnh_QUALITY_COLORS[it.quality]
        if qc then btn.beBorder:SetVertexColor(qc[1], qc[2], qc[3], 0.9); btn.beBorder:Show() else btn.beBorder:Hide() end
        if showIlvl and it.equipLoc and BagsEnh_EQUIPLOC_ORDER[it.equipLoc] then
            local _, _, _, iLevel = GetItemInfo(it.link)
            if iLevel and iLevel >= 1 then
                if qc then btn.beIlvl:SetTextColor(qc[1], qc[2], qc[3]) else btn.beIlvl:SetTextColor(1, 1, 1) end
                btn.beIlvl:SetText(iLevel); btn.beIlvl:Show()
            else btn.beIlvl:Hide() end
        else btn.beIlvl:Hide() end
        btn:SetAlpha(dim and 0.25 or 1)
        btn:Show()
    end

    local y = 0
    for _, cat in ipairs(BagsEnh_GetCategoryOrder()) do
        local items = groups[cat]
        if cat == "hidden" and not BagsEnhDB.showHidden then items = nil end
        if items and #items > 0 then
            local header = AcquireHeader(v)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", v.content, "TOPLEFT", 0, -y)
            header:SetWidth(viewW)
            local cr, cg, cb = BagsEnh_CategoryColor(cat)
            header.dot:SetVertexColor(cr, cg, cb)
            header.label:SetText(("|cff%s%s|r |cff777777(%d)|r"):format(
                BagsEnh_ColorHex(cr, cg, cb), BagsEnh_CategoryLabel(cat), #items))
            y = y + HEADER_H

            local grouping = BagsEnh_GroupingFor(cat)
            if grouping then
                y = BagsEnh_LayoutGrouped(items, grouping, {
                    perRow = perRow, yStep = yStep, subH = SUBHEADER_H,
                    place = function(it, col, yy) PlaceButton(it, col, yy) end,
                    header = function(text, indent, yy)
                        local sh = AcquireSubHeader(v)
                        sh:ClearAllPoints()
                        sh:SetPoint("TOPLEFT", v.content, "TOPLEFT", indent, -yy)
                        sh:SetText(text)
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

    v.content:SetHeight(math.max(y, 10))
    local viewH = v.frame:GetHeight() - TOPCHROME - BOTCHROME
    local maxScroll = math.max(0, y - viewH)
    v.scroll.maxScroll = maxScroll
    if v.scroll:GetVerticalScroll() > maxScroll then v.scroll:SetVerticalScroll(maxScroll) end

    -- Footer: item count · money · last seen
    local foot = ld.WH_FOOTER or "%d items"
    local money = c and c.money and BagsEnh_FormatGold(c.money) or ""
    local seen = ""
    if c and c.lastSeen then seen = "  |cff666666" .. date("%d/%m %H:%M", c.lastSeen) .. "|r" end
    v.foot:SetText(foot:format(count) .. "   " .. money .. seen)

    if unresolved and C_Timer and C_Timer.After then
        v.retries = (v.retries or 0) + 1
        if v.retries <= 5 then C_Timer.After(0.25, function() Refresh(v) end) end
    else
        v.retries = 0
    end
end

-- ============================================================
-- Character / container pickers
-- ============================================================
local CONTAINER_ORDER = { "bags", "bank", "personalbank", "realmbank", "guildbank" }

local function ContainerLabel(k)
    local ld = BagsEnh_L()
    local m = {
        bags = ld.WH_BAGS, bank = ld.WH_BANK,
        personalbank = ld.BANK_TITLE_PERSONAL, realmbank = ld.BANK_TITLE_REALM,
        guildbank = ld.BANK_TITLE_GUILD,
    }
    return m[k] or k
end

-- Containers actually present in a character's cache, in display order.
local function AvailableContainers(charKey)
    local e = BagsEnh_GetCache(charKey)
    local list = {}
    for _, k in ipairs(CONTAINER_ORDER) do
        if k == "realmbank" then
            -- Realm bank : store partagé par serveur → visible de TOUS les
            -- persos du realm, même ceux qui ne l'ont pas ouverte eux-mêmes.
            if BagsEnh_GetRealmBank(BagsEnh_RealmOf(charKey)) then
                list[#list + 1] = k
            end
        elseif e and e[k] then
            list[#list + 1] = k
        end
    end
    return list
end

local function EnsureValidContainer(v)
    local avail = AvailableContainers(v.char)
    for _, k in ipairs(avail) do
        if k == v.container then return end
    end
    v.container = avail[1] or "bank"
end

local function SetupContainerDD(v)
    local dd = v.contDD
    UIDropDownMenu_SetWidth(dd, 110)
    UIDropDownMenu_Initialize(dd, function()
        local info = UIDropDownMenu_CreateInfo()
        for _, k in ipairs(AvailableContainers(v.char)) do
            info.text = ContainerLabel(k)
            info.checked = (v.container == k)
            info.func = function()
                v.container = k
                UIDropDownMenu_SetText(dd, ContainerLabel(k))
                CloseDropDownMenus()
                Refresh(v)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(dd, ContainerLabel(v.container))
end

local function CharDisplay(key)
    return BagsEnh_CharColorName(key)
end

local function SetupCharDD(v)
    local dd = v.charDD
    UIDropDownMenu_SetWidth(dd, 150)
    UIDropDownMenu_Initialize(dd, function()
        local info = UIDropDownMenu_CreateInfo()
        for _, key in ipairs(BagsEnh_CachedChars()) do
            info.text = CharDisplay(key)
            info.checked = (v.char == key)
            info.func = function()
                v.char = key
                UIDropDownMenu_SetText(dd, CharDisplay(key))
                EnsureValidContainer(v)
                SetupContainerDD(v)
                CloseDropDownMenus()
                Refresh(v)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(dd, CharDisplay(v.char))
end

-- Suppression d'un perso du coffre + rafraîchissement du viewer courant.
local function DeleteCharFromViewer(v, key)
    if not (v and key) then return end
    BagsEnh_DeleteCachedChar(key)
    BagsEnh_Print(
        BagsEnh_L().WH_DELETED:format(BagsEnh_CharColorName(key)))
    if v.char == key then                       -- on visait le perso supprimé
        local rest = BagsEnh_CachedChars()
        v.char = rest[1] or BagsEnh_CharKey()
    end
    EnsureValidContainer(v)
    SetupCharDD(v)
    SetupContainerDD(v)
    Refresh(v)
end

-- Confirmation avant suppression (pop-up standard WoW).
if not StaticPopupDialogs["BAGSENH_WH_DELETE"] then
    StaticPopupDialogs["BAGSENH_WH_DELETE"] = {
        text = "%s", button1 = DELETE, button2 = CANCEL,
        timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
        OnAccept = function(self)
            if self.data then DeleteCharFromViewer(self.data.v, self.data.key) end
        end,
    }
end

-- ============================================================
-- Window factory
-- ============================================================
local function CreateViewer()
    local ld = BagsEnh_L()
    local ac = BagsEnh_ACCENT or { 0.10, 0.80, 1.00 }
    viewerN = viewerN + 1
    local v = {
        pool = {}, active = {}, hpool = {}, hactive = {}, spool = {}, sactive = {},
        char = BagsEnh_CharKey(), container = "bank", search = "",
    }

    local f = CreateFrame("Frame", "BagsEnhWarehouse" .. viewerN, UIParent)
    v.frame = f
    f:SetSize(BagsEnhDB.bankWidth or 460, BagsEnhDB.bankHeight or 500)
    f:SetPoint("CENTER", (viewerN * 30) % 200 - 100, -(viewerN * 24) % 160 + 40)
    f:SetScale(BagsEnhDB.scale or 1.0)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.055, 0.075, 0.09, 0.94)
    f:SetBackdropBorderColor(ac[1], ac[2], ac[3], 0.55)
    f:SetMovable(true); f:SetResizable(true); f:EnableMouse(true)
    if f.SetMinResize then f:SetMinResize(260, 240) end
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    table.insert(UISpecialFrames, f:GetName())

    -- Title bar + control row dividers
    local tbar = f:CreateTexture(nil, "BORDER")
    tbar:SetTexture("Interface\\Buttons\\WHITE8X8"); tbar:SetVertexColor(1, 1, 1, 0.045)
    tbar:SetPoint("TOPLEFT", 1, -1); tbar:SetPoint("TOPRIGHT", -1, -1); tbar:SetHeight(TOPCHROME - 4)
    local tdiv = f:CreateTexture(nil, "BORDER")
    tdiv:SetTexture("Interface\\Buttons\\WHITE8X8"); tdiv:SetVertexColor(ac[1], ac[2], ac[3], 0.35)
    tdiv:SetPoint("TOPLEFT", 1, -(TOPCHROME - 3)); tdiv:SetPoint("TOPRIGHT", -1, -(TOPCHROME - 3)); tdiv:SetHeight(1)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", f, "TOPLEFT", PADDING, -14)
    title:SetText("|cff00ccff" .. (ld.WAREHOUSE_TITLE or "Warehouse") .. "|r")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)

    -- Search (title-bar row, right)
    local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    search:SetSize(140, 18)
    search:SetPoint("TOPRIGHT", -32, -6)
    search:SetAutoFocus(false); search:SetTextInsets(4, 4, 0, 0); search:SetFontObject("GameFontHighlightSmall")
    local ph = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", 6, 0); ph:SetText(ld.SEARCH_PLACEHOLDER)
    search:SetScript("OnTextChanged", function(self)
        local t = self:GetText(); ph:SetShown(t == "")
        v.search = t:lower(); Refresh(v)
    end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)

    -- Control row: character + container dropdowns
    v.charDD = CreateFrame("Frame", "BagsEnhWH" .. viewerN .. "Char", f, "UIDropDownMenuTemplate")
    v.charDD:SetPoint("TOPLEFT", -4, -28)
    v.contDD = CreateFrame("Frame", "BagsEnhWH" .. viewerN .. "Cont", f, "UIDropDownMenuTemplate")
    v.contDD:SetPoint("LEFT", v.charDD, "RIGHT", 6, 0)
    EnsureValidContainer(v)
    SetupCharDD(v)
    SetupContainerDD(v)

    -- Suppression rapide du perso affiché (obsolète) — confirmation obligatoire.
    v.delBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    v.delBtn:SetSize(78, 20)
    v.delBtn:SetPoint("LEFT", v.contDD, "RIGHT", -6, 2)
    v.delBtn:SetText(ld.WH_DELETE)
    v.delBtn:SetScript("OnClick", function()
        if not v.char then return end
        local dlg = StaticPopup_Show("BAGSENH_WH_DELETE",
            ld.WH_DELETE_CONFIRM:format(BagsEnh_CharColorName(v.char)))
        if dlg then dlg.data = { v = v, key = v.char } end
    end)

    v.foot = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    v.foot:SetPoint("BOTTOMLEFT", PADDING, PADDING - 2)

    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", PADDING, -TOPCHROME)
    scroll:SetPoint("BOTTOMRIGHT", -PADDING, BOTCHROME)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxS = self.maxScroll or 0
        self:SetVerticalScroll(math.max(0, math.min(maxS, self:GetVerticalScroll() - delta * 40)))
    end)
    v.scroll = scroll
    v.content = CreateFrame("Frame", nil, scroll)
    v.content:SetSize(400, 10)
    scroll:SetScrollChild(v.content)

    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); Refresh(v) end)
    f:SetScript("OnSizeChanged", function() if f:IsShown() then Refresh(v) end end)

    f:SetScript("OnShow", function() Refresh(v) end)
    v.Refresh = function() Refresh(v) end
    return v
end

local openViewers = {}

function BagsEnh_OpenWarehouse()
    local v = CreateViewer()
    v.frame:Show()
    openViewers[#openViewers + 1] = v
    return v
end

-- Refresh every open viewer (e.g. after the current character's cache changed)
function BagsEnh_RefreshWarehouses()
    for _, v in ipairs(openViewers) do
        if v.frame:IsShown() then Refresh(v) end
    end
end
