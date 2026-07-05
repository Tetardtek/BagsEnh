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
local headerPool = {}
local activeHeaders = {}

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
        end
        btn.beBorder = BagsEnh_CreateIconBorder(btn, icon or btn)
    else
        btn:SetParent(bagParents[bag])
    end
    activeButtons[#activeButtons + 1] = btn
    return btn
end

local function AcquireHeader(small)
    local h = table.remove(headerPool)
    if not h then
        h = mainFrame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetJustifyH("LEFT")
    end
    h:SetFontObject(small and "GameFontHighlightSmall" or "GameFontNormal")
    h:Show()
    activeHeaders[#activeHeaders + 1] = h
    return h
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
end

-- ============================================================
-- Main frame
-- ============================================================
function BagsEnh_CreateMainFrame()
    if mainFrame then return mainFrame end
    local ld = BagsEnh_L()

    mainFrame = CreateFrame("Frame", "BagsEnhFrame", UIParent)
    mainFrame:SetSize(480, 420)
    mainFrame:SetPoint("CENTER", BagsEnhDB.posX or 0, BagsEnhDB.posY or 0)
    mainFrame:SetScale(BagsEnhDB.scale or 1.0)
    mainFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
    })
    mainFrame:SetBackdropColor(0, 0, 0, 0.85)
    mainFrame:SetMovable(true)
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

    -- Footer: slots + money
    mainFrame.slots = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.slots:SetPoint("BOTTOMLEFT", PADDING, PADDING - 2)
    mainFrame.money = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mainFrame.money:SetPoint("BOTTOMRIGHT", -PADDING, PADDING - 2)

    -- Content area (sections are laid out inside)
    mainFrame.content = CreateFrame("Frame", nil, mainFrame)
    mainFrame.content:SetPoint("TOPLEFT", PADDING, -30)
    mainFrame.content:SetPoint("BOTTOMRIGHT", -PADDING, 26)

    -- Hidden per-bag parents: native item button behavior needs
    -- GetParent():GetID() == bag and button:GetID() == slot
    for _, bag in ipairs(BAGS) do
        local p = CreateFrame("Frame", "BagsEnhBag" .. bag, mainFrame.content)
        p:SetID(bag)
        p:SetAllPoints(mainFrame.content)
        bagParents[bag] = p
    end

    mainFrame:SetScript("OnShow", function() BagsEnh_Refresh() end)

    return mainFrame
end

-- ============================================================
-- Layout
-- ============================================================
function BagsEnh_Refresh()
    if not mainFrame or not mainFrame:IsShown() then return end
    local ld = BagsEnh_L()

    ReleaseAll()

    -- Collect items grouped by category
    local groups = {}
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
                groups[cat] = groups[cat] or {}
                table.insert(groups[cat], {
                    bag = bag, slot = slot, texture = texture,
                    count = count, quality = quality, link = link,
                    subCat = subCat, equipLoc = equipLoc,
                })
            end
        end
    end

    -- Render sections in canonical order
    local columns = BagsEnhDB.columns or 12
    local xStep = BUTTON_SIZE + 4
    local yStep = BUTTON_SIZE + 4
    local SUBHEADER_H = 15
    local yOff = 0
    local col = 0

    local function NewLine()
        if col > 0 then
            col = 0
            yOff = yOff + yStep
        end
    end

    local function PlaceButton(item)
        local btn = AcquireButton(item.bag)
        btn:SetID(item.slot)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", mainFrame.content, "TOPLEFT", col * xStep, -yOff)

        SetItemButtonTexture(btn, item.texture)
        SetItemButtonCount(btn, item.count)

        local qc = item.quality and item.quality > 1 and BagsEnh_QUALITY_COLORS[item.quality]
        if qc then
            btn.beBorder:SetVertexColor(qc[1], qc[2], qc[3], 0.9)
            btn.beBorder:Show()
        else
            btn.beBorder:Hide()
        end

        btn:Show()
        col = col + 1
        if col >= columns then
            col = 0
            yOff = yOff + yStep
        end
    end

    for _, cat in ipairs(BagsEnh_CATEGORY_ORDER) do
        local items = groups[cat]
        if items and #items > 0 then
            local header = AcquireHeader()
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", mainFrame.content, "TOPLEFT", 0, -yOff)
            header:SetText(("|cffffd100%s|r |cff888888(%d)|r"):format(ld[BagsEnh_CATEGORY_LABELS[cat]] or cat, #items))
            yOff = yOff + HEADER_H

            if cat == "equipment" then
                -- Sub-categories: weapon type / armor material,
                -- sorted by equip slot inside each group
                table.sort(items, function(a, b)
                    local sa, sb = a.subCat or "?", b.subCat or "?"
                    if sa ~= sb then return sa < sb end
                    local ea = BagsEnh_EQUIPLOC_ORDER[a.equipLoc or ""] or 99
                    local eb = BagsEnh_EQUIPLOC_ORDER[b.equipLoc or ""] or 99
                    if ea ~= eb then return ea < eb end
                    return (a.quality or 0) > (b.quality or 0)
                end)

                local lastSub
                for _, item in ipairs(items) do
                    local sub = item.subCat or "?"
                    if sub ~= lastSub then
                        lastSub = sub
                        NewLine()
                        local sh = AcquireHeader(true)
                        sh:ClearAllPoints()
                        sh:SetPoint("TOPLEFT", mainFrame.content, "TOPLEFT", 4, -yOff)
                        sh:SetText("|cffaaaaaa" .. sub .. "|r")
                        yOff = yOff + SUBHEADER_H
                    end
                    PlaceButton(item)
                end
            else
                for _, item in ipairs(items) do
                    PlaceButton(item)
                end
            end

            NewLine()
            yOff = yOff + 6
        end
    end

    -- Fit window height to content (min 200, max 90% screen)
    local height = 30 + yOff + 26
    local maxH = UIParent:GetHeight() * 0.9
    mainFrame:SetHeight(math.max(200, math.min(height, maxH)))
    mainFrame:SetWidth(PADDING * 2 + columns * xStep + 4)

    mainFrame.slots:SetText(ld.SLOTS:format(usedSlots, totalSlots))
    mainFrame.money:SetText(BagsEnh_FormatGold(GetMoney()))

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
