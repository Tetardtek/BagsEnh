-- ============================================================
-- Unified bag window — sections by category, pooled item buttons.
-- Buttons use ContainerFrameItemButtonTemplate parented to hidden
-- per-bag frames (SetID) so click/tooltip/split behave natively.
-- ============================================================

local BAGS = {0, 1, 2, 3, 4}
local BUTTON_SIZE = 37
local PADDING = 10
local HEADER_H = 18

local mainFrame
local bagParents = {}      -- [bag] = hidden parent frame carrying the bag ID
local buttonPool = {}      -- released buttons
local activeButtons = {}   -- buttons currently shown
local headerPool = {}      -- sub-headers (font strings)
local activeHeaders = {}
local catHeaderPool = {}   -- category headers (clickable buttons)
local activeCatHeaders = {}

-- ============================================================
-- Alt-click item menu — move to category / hide / reset
-- ============================================================
local menuFrame
local function ShowItemMenu(btn)
    local bag, slot = btn:GetParent():GetID(), btn:GetID()
    local link = GetContainerItemLink(bag, slot)
    local itemID = BagsEnh_ItemIDFromLink(link)
    if not itemID then return end
    local ld = BagsEnh_L()
    local overrides = BagsEnhDB.itemOverrides or {}

    menuFrame = menuFrame or CreateFrame("Frame", "BagsEnhItemMenu", UIParent, "UIDropDownMenuTemplate")
    local name = GetItemInfo(link)
    local menu = {
        { text = name or "?", isTitle = true, notCheckable = true },
    }
    for _, cat in ipairs(BagsEnh_GetCategoryOrder()) do
        if cat ~= "new" and cat ~= "hidden" then
            menu[#menu + 1] = {
                text = ld.MENU_MOVE_TO:format(BagsEnh_CategoryLabel(cat)),
                checked = (overrides[itemID] == cat),
                func = function() BagsEnh_SetItemOverride(itemID, cat) end,
            }
        end
    end
    menu[#menu + 1] = {
        text = ld.MENU_HIDE,
        checked = (overrides[itemID] == "hidden"),
        func = function() BagsEnh_SetItemOverride(itemID, "hidden") end,
    }
    menu[#menu + 1] = {
        text = ld.MENU_RESET,
        notCheckable = true,
        func = function() BagsEnh_SetItemOverride(itemID, nil) end,
    }
    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU")
end

-- ============================================================
-- Pools
-- ============================================================
local buttonCounter = 0
local function AcquireButton(bag)
    local btn = table.remove(buttonPool)
    if not btn then
        buttonCounter = buttonCounter + 1
        btn = CreateFrame("Button", "BagsEnhItem" .. buttonCounter, bagParents[bag], "ContainerFrameItemButtonTemplate")
        btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        local icon = _G[btn:GetName() .. "IconTexture"]
        if icon then
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            icon:SetAllPoints(btn)  -- icon follows button size (icon-size slider)
        end
        -- The slot frame (NormalTexture) has a fixed native size; anchor it
        -- to the button so it shrinks too — otherwise it overlaps neighbours
        -- when icons are made smaller.
        local nt = btn:GetNormalTexture()
        if nt then
            nt:ClearAllPoints()
            nt:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
            nt:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -3)
        end
        btn.beBorder = BagsEnh_CreateIconBorder(btn, icon or btn)

        -- Item level (top-right, small) — shown for gear only. Drawn above the
        -- icon with a thin shadow so it stays readable on bright textures.
        local ilvl = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        ilvl:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
        ilvl:SetJustifyH("RIGHT")
        ilvl:SetShadowColor(0, 0, 0, 1)
        ilvl:SetShadowOffset(1, -1)
        ilvl:Hide()
        btn.beIlvl = ilvl

        -- Bag highlight tint — lit when the matching bag is hovered in the
        -- equipped-bags popup, so you can see which slots belong to it.
        local bagHL = btn:CreateTexture(nil, "OVERLAY")
        bagHL:SetTexture("Interface\\Buttons\\WHITE8X8")
        bagHL:SetBlendMode("ADD")
        bagHL:SetAllPoints(btn)
        bagHL:SetVertexColor(1, 0.85, 0.2, 0.35)
        bagHL:Hide()
        btn.beBagHL = bagHL

        -- "New item" glow (inter-Enh bridge / autonomous detection)
        local glow = btn:CreateTexture(nil, "OVERLAY")
        glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        glow:SetBlendMode("ADD")
        glow:SetPoint("CENTER", btn, "CENTER", 0, 0)
        glow:SetVertexColor(1, 1, 0.5)
        glow:Hide()
        btn.beGlow = glow

        -- Hovering a new item marks it seen (clears its glow, no full refresh)
        btn:HookScript("OnEnter", function(self)
            if self.beItemID and BagsEnh_newItems and BagsEnh_newItems[self.beItemID] then
                BagsEnh_MarkSeen(self.beItemID)
                self.beGlow:Hide()
            end
        end)

        -- The native OnClick is left untouched: replacing it taints the
        -- button and blocks protected item use on the Ascension client.
        -- The category menu lives on a separate corner badge that only
        -- opens a menu (no protected call), so its taint is harmless.
        local badge = CreateFrame("Button", nil, btn)
        badge:SetSize(13, 13)
        badge:SetPoint("TOPLEFT", 0, 0)
        badge:SetFrameLevel(btn:GetFrameLevel() + 2)
        local bt = badge:CreateTexture(nil, "OVERLAY")
        bt:SetAllPoints()
        bt:SetTexture("Interface\\Buttons\\WHITE8X8")
        bt:SetVertexColor(0, 0, 0, 0.6)
        local bl = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bl:SetPoint("CENTER", 0, 0)
        bl:SetText("|cff8cd0ff+|r")
        badge:SetScript("OnClick", function(self)
            ShowItemMenu(self:GetParent())
        end)
        badge:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(BagsEnh_L().TIP_MENU_BADGE, 0.55, 0.82, 1)
            GameTooltip:Show()
        end)
        badge:SetScript("OnLeave", function() GameTooltip:Hide() end)
        badge:Hide()
        btn.beBadge = badge

        -- Badge only visible while hovering the item (stays up when the
        -- cursor moves onto the badge itself)
        btn:HookScript("OnEnter", function(self) self.beBadge:Show() end)
        btn:HookScript("OnLeave", function(self)
            if not self.beBadge:IsMouseOver() then self.beBadge:Hide() end
        end)
        badge:HookScript("OnLeave", function(self)
            if not self:GetParent():IsMouseOver() then self:Hide() end
        end)
    else
        btn:SetParent(bagParents[bag])
    end
    activeButtons[#activeButtons + 1] = btn
    return btn
end

-- Sub-header (weapon type / material / profession line) — plain text
local function AcquireHeader()
    local h = table.remove(headerPool)
    if not h then
        h = mainFrame.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        h:SetJustifyH("LEFT")
    end
    h:Show()
    activeHeaders[#activeHeaders + 1] = h
    return h
end

-- Category header — clickable button that toggles collapse for its category
local function AcquireCatHeader(catKey)
    local b = table.remove(catHeaderPool)
    if not b then
        b = CreateFrame("Button", nil, mainFrame.content)
        b:SetHeight(HEADER_H)
        b:RegisterForClicks("LeftButtonUp")
        b.arrow = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.arrow:SetPoint("LEFT", 0, 0)
        b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.label:SetPoint("LEFT", 14, 0)
        b.label:SetJustifyH("LEFT")
        b:SetScript("OnClick", function(self)
            BagsEnhDB.collapsed = BagsEnhDB.collapsed or {}
            BagsEnhDB.collapsed[self.catKey] = not BagsEnhDB.collapsed[self.catKey]
            BagsEnh_Refresh()
        end)
    end
    b.catKey = catKey
    b:Show()
    activeCatHeaders[#activeCatHeaders + 1] = b
    return b
end

local function ReleaseAll()
    for _, btn in ipairs(activeButtons) do
        btn:Hide()
        table.insert(buttonPool, btn)
    end
    activeButtons = {}
    for _, h in ipairs(activeHeaders) do
        h:Hide()
        table.insert(headerPool, h)
    end
    activeHeaders = {}
    for _, b in ipairs(activeCatHeaders) do
        b:Hide()
        table.insert(catHeaderPool, b)
    end
    activeCatHeaders = {}
end

-- Lights up every visible slot belonging to bagID (nil clears all). Buttons
-- carry their bag as their parent's ID, so both views resolve it the same way.
function BagsEnh_HighlightBag(bagID)
    for _, btn in ipairs(activeButtons) do
        if btn.beBagHL then
            if bagID and btn:GetParent():GetID() == bagID then
                btn.beBagHL:Show()
            else
                btn.beBagHL:Hide()
            end
        end
    end
end

-- ============================================================
-- Main frame
-- ============================================================
function BagsEnh_CreateMainFrame()
    if mainFrame then return mainFrame end
    local ld = BagsEnh_L()

    mainFrame = CreateFrame("Frame", "BagsEnhFrame", UIParent)
    mainFrame:SetSize(BagsEnhDB.width or 400, BagsEnhDB.height or 480)
    mainFrame:SetPoint("CENTER", BagsEnhDB.posX or 0, BagsEnhDB.posY or 0)
    mainFrame:SetScale(BagsEnhDB.scale or 1.0)
    mainFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
    })
    mainFrame:SetBackdropColor(0, 0, 0, 0.85)
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    if mainFrame.SetMinResize then mainFrame:SetMinResize(240, 200) end
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local cx, cy = s:GetCenter()
        local px, py = UIParent:GetCenter()
        BagsEnhDB.posX, BagsEnhDB.posY = cx - px, cy - py
        s:ClearAllPoints()
        s:SetPoint("CENTER", BagsEnhDB.posX, BagsEnhDB.posY)
    end)
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:Hide()

    -- ESC closes the window
    table.insert(UISpecialFrames, "BagsEnhFrame")

    -- Title
    mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainFrame.title:SetPoint("TOPLEFT", PADDING, -PADDING)
    mainFrame.title:SetText("|cff00ccff" .. ld.TITLE .. "|r")

    -- Close button
    local close = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    -- Equipped-bags button (left, next to the title) — opens the bag-slots popup
    local bagsBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    bagsBtn:SetSize(56, 18)
    bagsBtn:SetPoint("TOPLEFT", 68, -PADDING + 1)
    bagsBtn:SetText(ld.BAGS_BUTTON)
    bagsBtn:SetScript("OnClick", function()
        if not BagsEnh_ToggleBagSlots then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555BagsEnh:|r BagSlots module not loaded")
            return
        end
        -- Surface any runtime error (Ascension hides Lua errors by default)
        local ok, err = pcall(BagsEnh_ToggleBagSlots)
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555BagsEnh bags error:|r " .. tostring(err))
        end
    end)
    mainFrame.bagsBtn = bagsBtn

    -- View toggle (Categories <-> OneBag), left of the search box
    local viewBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    viewBtn:SetSize(76, 18)
    viewBtn:SetPoint("TOPRIGHT", -174, -PADDING)
    viewBtn:SetScript("OnClick", function()
        BagsEnhDB.viewMode = (BagsEnhDB.viewMode == "onebag") and "category" or "onebag"
        BagsEnh_Refresh()
    end)
    viewBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(BagsEnh_L().TIP_VIEW, 0.55, 0.82, 1)
        GameTooltip:Show()
    end)
    viewBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    mainFrame.viewBtn = viewBtn

    -- Sort button (physical sort) — only meaningful in OneBag, where the real
    -- slots (and the result of the sort) are visible. Hidden in category view.
    local sortBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    sortBtn:SetSize(64, 18)
    sortBtn:SetPoint("TOPRIGHT", -254, -PADDING)
    sortBtn:SetText(ld.SORT)
    sortBtn:SetScript("OnClick", function() BagsEnh_SortBags() end)
    mainFrame.sortBtn = sortBtn

    -- Search box (top-right, left of the close button)
    local search = CreateFrame("EditBox", "BagsEnhSearch", mainFrame, "InputBoxTemplate")
    search:SetSize(140, 18)
    search:SetPoint("TOPRIGHT", -28, -PADDING)
    search:SetAutoFocus(false)
    search:SetTextInsets(4, 4, 0, 0)
    search:SetFontObject("GameFontHighlightSmall")
    local sPlaceholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sPlaceholder:SetPoint("LEFT", 6, 0)
    sPlaceholder:SetText(ld.SEARCH_PLACEHOLDER)
    search.placeholder = sPlaceholder
    search:SetScript("OnTextChanged", function(self)
        local txt = self:GetText()
        self.placeholder:SetShown(txt == "")
        BagsEnh_searchText = txt:lower()
        BagsEnh_Refresh()
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    mainFrame.search = search

    -- Footer: slots + money + hidden toggle
    mainFrame.slots = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.slots:SetPoint("BOTTOMLEFT", PADDING, PADDING - 2)
    mainFrame.money = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.money:SetPoint("BOTTOMRIGHT", -PADDING, PADDING - 2)

    mainFrame.hiddenBtn = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
    mainFrame.hiddenBtn:SetSize(130, 18)
    mainFrame.hiddenBtn:SetPoint("BOTTOM", 0, 5)
    mainFrame.hiddenBtn:SetScript("OnClick", function()
        BagsEnhDB.showHidden = not BagsEnhDB.showHidden
        BagsEnh_Refresh()
    end)
    mainFrame.hiddenBtn:Hide()

    -- Scroll viewport: content can be taller than the window; the wheel
    -- scrolls it so nothing ever spills behind the footer.
    local scroll = CreateFrame("ScrollFrame", "BagsEnhScroll", mainFrame)
    scroll:SetPoint("TOPLEFT", PADDING, -30)
    scroll:SetPoint("BOTTOMRIGHT", -PADDING, 26)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxS = self.maxScroll or 0
        local new = math.max(0, math.min(maxS, self:GetVerticalScroll() - delta * 40))
        self:SetVerticalScroll(new)
    end)
    mainFrame.scroll = scroll

    -- Content area (sections are laid out inside), scrolled by the viewport
    mainFrame.content = CreateFrame("Frame", nil, scroll)
    mainFrame.content:SetSize(400, 10)
    scroll:SetScrollChild(mainFrame.content)

    -- Resize handle (bottom-right) — free window sizing, more width = more columns
    local grip = CreateFrame("Button", nil, mainFrame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() mainFrame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        mainFrame:StopMovingOrSizing()
        BagsEnhDB.width = mainFrame:GetWidth()
        BagsEnhDB.height = mainFrame:GetHeight()
        BagsEnh_Refresh()
    end)
    -- Live reflow while dragging the grip
    mainFrame:SetScript("OnSizeChanged", function()
        if mainFrame:IsShown() then BagsEnh_Refresh() end
    end)

    -- Hidden per-bag parents: native item button behavior needs
    -- GetParent():GetID() == bag and button:GetID() == slot
    for _, bag in ipairs(BAGS) do
        local p = CreateFrame("Frame", "BagsEnhBag" .. bag, mainFrame.content)
        p:SetID(bag)
        p:SetAllPoints(mainFrame.content)
        bagParents[bag] = p
    end

    mainFrame:SetScript("OnShow", function() BagsEnh_Refresh() end)
    -- Closing the bags = you've seen the new items; clear the glow
    mainFrame:SetScript("OnHide", function()
        if BagsEnh_newItems then BagsEnh_newItems = {} end
    end)

    return mainFrame
end

-- ============================================================
-- Layout
-- ============================================================
function BagsEnh_Refresh()
    if not mainFrame or not mainFrame:IsShown() then return end
    local ld = BagsEnh_L()

    ReleaseAll()

    -- Collect items grouped by category (category view) and as a flat
    -- slot list including empty slots (OneBag view).
    local groups = {}
    local allSlots = {}         -- every slot in bag order, item = nil when empty
    local usedSlots, totalSlots = 0, 0
    local unresolved = false
    for _, bag in ipairs(BAGS) do
        local numSlots = GetContainerNumSlots(bag) or 0
        totalSlots = totalSlots + numSlots
        for slot = 1, numSlots do
            local texture, count, locked, quality, _, _, link = GetContainerItemInfo(bag, slot)
            if texture then
                usedSlots = usedSlots + 1
                local cat, resolved, subCat, equipLoc = BagsEnh_Categorize(link)
                if not resolved then unresolved = true end
                local item = {
                    bag = bag, slot = slot, texture = texture,
                    count = count, quality = quality, link = link,
                    subCat = subCat, equipLoc = equipLoc,
                }
                groups[cat] = groups[cat] or {}
                table.insert(groups[cat], item)
                allSlots[#allSlots + 1] = { bag = bag, slot = slot, item = item }
            else
                allSlots[#allSlots + 1] = { bag = bag, slot = slot, item = nil }
            end
        end
    end

    -- Layout metrics
    local perRow = BagsEnhDB.columns or 8          -- items per row inside a section
    local iconSize = BagsEnhDB.iconSize or 37
    local spacing = BagsEnhDB.spacing or 4
    local xStep = iconSize + spacing
    local yStep = iconSize + spacing
    local SUBHEADER_H = 15
    local SECTION_GAP = 12

    -- Content width follows the viewport (window width minus chrome)
    local viewW = mainFrame.scroll:GetWidth()
    if not viewW or viewW < 1 then viewW = mainFrame:GetWidth() - PADDING * 2 end
    mainFrame.content:SetWidth(viewW)

    -- One "section column" is perRow icons wide. The number of columns
    -- flows from the window width, so resizing wider = more columns.
    local sectionW = perRow * xStep
    local avail = viewW
    if avail < sectionW then avail = sectionW end
    local nbCols = math.max(1, math.floor((avail + SECTION_GAP) / (sectionW + SECTION_GAP)))

    local colH = {}
    for i = 1, nbCols do colH[i] = 0 end
    local function ShortestCol()
        local best = 1
        for i = 2, nbCols do
            if colH[i] < colH[best] then best = i end
        end
        return best
    end

    local query = BagsEnh_searchText
    local function Matches(item)
        if not query or query == "" then return true end
        if not item.link then return false end
        local name = GetItemInfo(item.link)
        return name and name:lower():find(query, 1, true) ~= nil
    end

    local showIlvl = BagsEnhDB.showItemLevel

    -- Item level shown only on real gear (equipLoc listed in EQUIPLOC_ORDER),
    -- coloured by quality. Meaningless on consumables/mats, so hidden there.
    local function SetItemLevel(btn, item)
        if not showIlvl or not item.equipLoc or not BagsEnh_EQUIPLOC_ORDER[item.equipLoc] then
            btn.beIlvl:Hide()
            return
        end
        local _, _, _, iLevel = GetItemInfo(item.link)
        if not iLevel or iLevel < 1 then
            btn.beIlvl:Hide()
            return
        end
        local qc = item.quality and BagsEnh_QUALITY_COLORS[item.quality]
        if qc then
            btn.beIlvl:SetTextColor(qc[1], qc[2], qc[3])
        else
            btn.beIlvl:SetTextColor(1, 1, 1)
        end
        btn.beIlvl:SetText(iLevel)
        btn.beIlvl:Show()
    end

    -- Renders a filled slot into an already-positioned button.
    local function RenderItem(btn, item)
        btn:SetID(item.slot)
        SetItemButtonTexture(btn, item.texture)
        SetItemButtonCount(btn, item.count)

        -- New-item glow
        local itemID = BagsEnh_ItemIDFromLink(item.link)
        btn.beItemID = itemID
        if itemID and BagsEnh_newItems and BagsEnh_newItems[itemID] then
            btn.beGlow:SetSize(iconSize * 1.5, iconSize * 1.5)
            btn.beGlow:Show()
        else
            btn.beGlow:Hide()
        end

        local qc = item.quality and item.quality > 1 and BagsEnh_QUALITY_COLORS[item.quality]
        if qc then
            btn.beBorder:SetVertexColor(qc[1], qc[2], qc[3], 0.9)
            btn.beBorder:Show()
        else
            btn.beBorder:Hide()
        end

        SetItemLevel(btn, item)
        btn.beBagHL:Hide()

        local dim = not Matches(item)
        local icon = _G[btn:GetName() .. "IconTexture"]
        if icon then icon:SetDesaturated(dim) end
        btn:SetAlpha(dim and 0.25 or 1)
    end

    -- Renders an empty slot (OneBag only): native button with texture cleared,
    -- so the slot frame shows and item drops land in the real bag slot.
    local function RenderEmpty(btn, slot)
        btn:SetID(slot)
        SetItemButtonTexture(btn, nil)
        SetItemButtonCount(btn, 0)
        btn.beItemID = nil
        btn.beGlow:Hide()
        btn.beBorder:Hide()
        btn.beIlvl:Hide()
        btn.beBagHL:Hide()
        local icon = _G[btn:GetName() .. "IconTexture"]
        if icon then icon:SetDesaturated(false) end
        btn:SetAlpha((query and query ~= "") and 0.25 or 1)
    end

    local function PlaceButton(item, x0, col, y)
        local btn = AcquireButton(item.bag)
        btn:SetSize(iconSize, iconSize)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", mainFrame.content, "TOPLEFT", x0 + col * xStep, -y)
        RenderItem(btn, item)
        btn:Show()
    end

    local totalH = 0
    local onebag = BagsEnhDB.viewMode == "onebag"

    if onebag then
    -- OneBag: every slot (filled + empty) in bag order, one continuous grid
    -- filling the window width. Empty slots are shown so free space is visible
    -- and items can be dropped straight into a real bag slot.
    local cols = math.max(1, math.floor((viewW + spacing) / xStep))
    local i = 0
    for _, s in ipairs(allSlots) do
        local col = i % cols
        local row = math.floor(i / cols)
        local btn = AcquireButton(s.bag)
        btn:SetSize(iconSize, iconSize)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", mainFrame.content, "TOPLEFT", col * xStep, -(row * yStep))
        if s.item then
            RenderItem(btn, s.item)
        else
            RenderEmpty(btn, s.slot)
        end
        btn:Show()
        i = i + 1
    end
    local rows = math.ceil(i / cols)
    totalH = rows * yStep

    else
    -- Render each section into the currently shortest column (balanced flow)
    for _, cat in ipairs(BagsEnh_GetCategoryOrder()) do
        local items = groups[cat]
        if cat == "hidden" and not BagsEnhDB.showHidden then
            items = nil
        end
        if items and #items > 0 then
            local collapsed = BagsEnhDB.collapsed and BagsEnhDB.collapsed[cat]
            local colIdx = ShortestCol()
            local x0 = (colIdx - 1) * (sectionW + SECTION_GAP)
            local y = colH[colIdx]

            local header = AcquireCatHeader(cat)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", mainFrame.content, "TOPLEFT", x0, -y)
            header:SetWidth(sectionW)
            header.arrow:SetText(collapsed and "|cffffd100>|r" or "|cffffd100v|r")
            header.label:SetText(("|cffffd100%s|r |cff888888(%d)|r"):format(BagsEnh_CategoryLabel(cat), #items))
            y = y + HEADER_H

            if collapsed then
                -- header only
            elseif cat == "equipment" or cat == "profession" then
                table.sort(items, function(a, b)
                    local sa, sb = a.subCat or "?", b.subCat or "?"
                    if sa ~= sb then return sa < sb end
                    local ea = BagsEnh_EQUIPLOC_ORDER[a.equipLoc or ""] or 99
                    local eb = BagsEnh_EQUIPLOC_ORDER[b.equipLoc or ""] or 99
                    if ea ~= eb then return ea < eb end
                    if (a.quality or 0) ~= (b.quality or 0) then
                        return (a.quality or 0) > (b.quality or 0)
                    end
                    return (a.link or "") < (b.link or "")
                end)
                local lastSub, col = nil, 0
                for _, item in ipairs(items) do
                    local sub = item.subCat or "?"
                    if sub ~= lastSub then
                        if col > 0 then y = y + yStep; col = 0 end
                        lastSub = sub
                        local sh = AcquireHeader()
                        sh:ClearAllPoints()
                        sh:SetPoint("TOPLEFT", mainFrame.content, "TOPLEFT", x0 + 4, -y)
                        sh:SetText("|cffaaaaaa" .. sub .. "|r")
                        y = y + SUBHEADER_H
                    end
                    PlaceButton(item, x0, col, y)
                    col = col + 1
                    if col >= perRow then col = 0; y = y + yStep end
                end
                if col > 0 then y = y + yStep end
            else
                local col = 0
                for _, item in ipairs(items) do
                    PlaceButton(item, x0, col, y)
                    col = col + 1
                    if col >= perRow then col = 0; y = y + yStep end
                end
                if col > 0 then y = y + yStep end
            end

            colH[colIdx] = y + SECTION_GAP
        end
    end

    -- Tallest column drives the scrollable content height
    for i = 1, nbCols do
        if colH[i] > totalH then totalH = colH[i] end
    end
    end -- viewMode branch

    mainFrame.content:SetHeight(math.max(totalH, 10))

    -- Window size is user-controlled (resize handle); content scrolls inside
    local chromeTop, chromeBottom = 30, 26
    local viewH = mainFrame:GetHeight() - chromeTop - chromeBottom
    local maxScroll = math.max(0, totalH - viewH)
    mainFrame.scroll.maxScroll = maxScroll
    if mainFrame.scroll:GetVerticalScroll() > maxScroll then
        mainFrame.scroll:SetVerticalScroll(maxScroll)
    end

    mainFrame.slots:SetText(ld.SLOTS:format(usedSlots, totalSlots))
    mainFrame.money:SetText(BagsEnh_FormatGold(GetMoney()))

    -- View toggle label reflects the current mode; Sort only shown in OneBag
    -- (category view has no free slots to sort into — misleading there).
    mainFrame.viewBtn:SetText(onebag and ld.VIEW_ONEBAG or ld.VIEW_CATEGORY)
    if onebag then mainFrame.sortBtn:Show() else mainFrame.sortBtn:Hide() end

    -- Hidden items toggle (footer, only when relevant) — category view only,
    -- OneBag shows every real slot regardless of overrides.
    local hiddenCount = groups.hidden and #groups.hidden or 0
    if not onebag and (hiddenCount > 0 or BagsEnhDB.showHidden) then
        mainFrame.hiddenBtn:SetText(BagsEnhDB.showHidden
            and ld.BTN_HIDE_HIDDEN
            or ld.BTN_SHOW_HIDDEN:format(hiddenCount))
        mainFrame.hiddenBtn:Show()
    else
        mainFrame.hiddenBtn:Hide()
    end

    -- Some items weren't in the client cache yet: retry a few times
    if unresolved then
        mainFrame.retries = (mainFrame.retries or 0) + 1
        if mainFrame.retries <= 5 and BagsEnh_MarkDirty then
            BagsEnh_MarkDirty()
        end
    else
        mainFrame.retries = 0
    end
end

-- Applies live settings (scale) to the window and re-renders
function BagsEnh_ApplySettings()
    if not mainFrame then return end
    mainFrame:SetScale(BagsEnhDB.scale or 1.0)
    if mainFrame:IsShown() then BagsEnh_Refresh() end
end

function BagsEnh_Show()
    BagsEnh_CreateMainFrame()
    mainFrame:Show()
end

function BagsEnh_Hide()
    if mainFrame then mainFrame:Hide() end
end

function BagsEnh_Toggle()
    BagsEnh_CreateMainFrame()
    if mainFrame:IsShown() then mainFrame:Hide() else mainFrame:Show() end
end

function BagsEnh_IsShown()
    return mainFrame and mainFrame:IsShown()
end
