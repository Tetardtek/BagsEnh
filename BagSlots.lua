-- ============================================================
-- Equipped-bags popup — swap bags in their inventory slots, see which
-- slots each bag owns (hover highlight in the grid), and empty a bag into
-- the others. The "empty" mover reuses the SortEngine pattern: one pending
-- move at a time on OnUpdate, waits for locks, aborts in combat.
-- Bag swap uses PickupBagFromSlot/PutItemInBag — non-protected in 3.3.5.
-- ============================================================

local BAG_IDS = {0, 1, 2, 3, 4}

-- ============================================================
-- Empty-bag mover
-- ============================================================
local mover = CreateFrame("Frame")
local mstate = { running = false }

local function AnyLocked()
    for _, bag in ipairs(BAG_IDS) do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local _, _, locked = GetContainerItemInfo(bag, slot)
            if locked then return true end
        end
    end
    return false
end

-- First occupied slot in a bag, or nil when the bag is empty.
local function NextItemInBag(bag)
    for slot = 1, GetContainerNumSlots(bag) or 0 do
        if GetContainerItemInfo(bag, slot) then return slot end
    end
    return nil
end

-- An empty slot in some other bag that can legally hold `link`
-- (general bags take anything; specialised bags only their family).
local function FindFreeSlot(link, excludeBag)
    local fam = (GetItemFamily and GetItemFamily(link)) or 0
    for _, bag in ipairs(BAG_IDS) do
        if bag ~= excludeBag then
            local free, bagFam = GetContainerNumFreeSlots(bag)
            bagFam = bagFam or 0
            if free and free > 0
               and (bagFam == 0 or (fam ~= 0 and bit.band(fam, bagFam) ~= 0)) then
                for slot = 1, GetContainerNumSlots(bag) or 0 do
                    if not GetContainerItemInfo(bag, slot) then
                        return bag, slot
                    end
                end
            end
        end
    end
    return nil
end

local function MoverFinish(msg)
    mstate.running = false
    mover:SetScript("OnUpdate", nil)
    ClearCursor()
    if msg then
        BagsEnh_Print(msg)
    end
    if BagsEnh_MarkDirty then BagsEnh_MarkDirty() end
    if BagsEnh_RefreshBagSlots then BagsEnh_RefreshBagSlots() end
end

local function MoverTick()
    local ld = BagsEnh_L()
    if InCombatLockdown and InCombatLockdown() then
        MoverFinish(ld.SORT_ABORT_COMBAT); return
    end

    if mstate.waiting then
        if AnyLocked() then
            mstate.waitTicks = (mstate.waitTicks or 0) + 1
            if mstate.waitTicks > 200 then MoverFinish(ld.SORT_ABORT_STUCK) end
            return
        end
        mstate.waiting = false
        mstate.waitTicks = 0
    end

    -- Runaway guard: never dispatch more moves than there are slots overall.
    mstate.moves = (mstate.moves or 0) + 1
    if mstate.moves > 250 then MoverFinish(ld.SORT_ABORT_STUCK); return end

    local bag = mstate.bag
    local srcSlot = NextItemInBag(bag)
    if not srcSlot then
        MoverFinish(ld.EMPTY_DONE); return
    end

    local link = GetContainerItemLink(bag, srcSlot)
    local dBag, dSlot = FindFreeSlot(link, bag)
    if not dBag then
        MoverFinish(ld.EMPTY_NOSPACE); return
    end

    PickupContainerItem(bag, srcSlot)
    PickupContainerItem(dBag, dSlot)
    mstate.waiting = true
    mstate.waitTicks = 0
end

function BagsEnh_EmptyBag(bag)
    if mstate.running then return end
    local ld = BagsEnh_L()
    if InCombatLockdown and InCombatLockdown() then
        BagsEnh_Print(ld.SORT_ABORT_COMBAT); return
    end
    if AnyLocked() then
        BagsEnh_Print(ld.EMPTY_BUSY); return
    end
    if not NextItemInBag(bag) then
        return -- already empty, nothing to do
    end
    mstate.running = true
    mstate.bag = bag
    mstate.waiting = false
    mstate.waitTicks = 0
    mstate.moves = 0
    mover:SetScript("OnUpdate", MoverTick)
end

-- ============================================================
-- Popup
-- ============================================================
local popup
local rows = {}   -- [bag] = row frame (bag 0..4)

local function BuildRow(parent, bag, y)
    local ld = BagsEnh_L()
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(184, 40)
    row:SetPoint("TOPLEFT", 10, y)

    -- Built by hand (no ItemButtonTemplate) so it can't break on a client
    -- whose FrameXML templates differ — series ADN is zero UI dependency.
    local btn = CreateFrame("Button", "BagsEnhBagSlotBtn" .. bag, row)
    btn:SetSize(36, 36)
    btn:SetPoint("LEFT", 0, 0)
    btn.bag = bag
    btn.invSlot = (bag >= 1) and ContainerIDToInventoryID(bag) or nil
    btn:RegisterForClicks("LeftButtonUp")

    -- Empty bag-slot art shows through when no bag is equipped
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:Hide()
    btn.icon = icon
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    btn:SetScript("OnEnter", function(self)
        BagsEnh_HighlightBag(self.bag)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.bag == 0 then
            GameTooltip:SetText(BagsEnh_L().BAGSLOT_BACKPACK)
        elseif self.invSlot and GetInventoryItemTexture("player", self.invSlot) then
            GameTooltip:SetInventoryItem("player", self.invSlot)
        else
            GameTooltip:SetText(BagsEnh_L().BAGSLOT_EMPTY_SLOT)
        end
        GameTooltip:AddLine(BagsEnh_L().TIP_BAGSLOT, 0.55, 0.82, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        BagsEnh_HighlightBag(nil)
        GameTooltip:Hide()
    end)

    -- Bag swap: pick up / drop the bag in its inventory slot (bags 1-4 only,
    -- the backpack can't be swapped).
    if bag >= 1 then
        btn:SetScript("OnClick", function(self)
            if InCombatLockdown and InCombatLockdown() then return end
            if CursorHasItem() then
                PutItemInBag(self.invSlot)
            else
                PickupBagFromSlot(self.invSlot)
            end
        end)
    end
    row.btn = btn

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", btn, "TOPRIGHT", 6, -1)
    row.name:SetWidth(138)
    row.name:SetJustifyH("LEFT")

    row.free = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.free:SetPoint("TOPLEFT", btn, "TOPRIGHT", 6, -16)

    if bag >= 1 then
        local emptyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        emptyBtn:SetSize(50, 16)
        emptyBtn:SetPoint("BOTTOMRIGHT", 0, 1)
        emptyBtn:SetText(ld.BAGSLOT_EMPTY_BTN)
        emptyBtn:SetScript("OnClick", function() BagsEnh_EmptyBag(bag) end)
        emptyBtn:SetScript("OnEnter", function(self)
            BagsEnh_HighlightBag(bag)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(BagsEnh_L().TIP_BAGSLOT_EMPTY, 0.55, 0.82, 1, true)
            GameTooltip:Show()
        end)
        emptyBtn:SetScript("OnLeave", function()
            BagsEnh_HighlightBag(nil)
            GameTooltip:Hide()
        end)
        row.emptyBtn = emptyBtn
    end

    return row
end

function BagsEnh_RefreshBagSlots()
    if not popup or not popup:IsShown() then return end
    local ld = BagsEnh_L()
    for bag = 0, 4 do
        local row = rows[bag]
        if row then
            local total = GetContainerNumSlots(bag) or 0
            local free = GetContainerNumFreeSlots(bag) or 0
            if bag == 0 then
                row.btn.icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
                row.btn.icon:Show()
                row.name:SetText(ld.BAGSLOT_BACKPACK)
            else
                local tex = GetInventoryItemTexture("player", row.btn.invSlot)
                if tex then
                    row.btn.icon:SetTexture(tex)
                    row.btn.icon:Show()
                else
                    row.btn.icon:Hide()
                end
                local link = GetInventoryItemLink("player", row.btn.invSlot)
                local nm = link and GetItemInfo(link)
                row.name:SetText(nm or ld.BAGSLOT_EMPTY_SLOT)
                if row.emptyBtn then
                    if total > 0 and (total - free) > 0 then
                        row.emptyBtn:Enable()
                    else
                        row.emptyBtn:Disable()
                    end
                end
            end
            row.free:SetText(ld.BAGSLOT_FREE:format(free, total))
        end
    end
end

local function CreatePopup()
    if popup then return popup end
    local parent = BagsEnhFrame or UIParent
    popup = CreateFrame("Frame", "BagsEnhBagSlots", parent)
    popup:SetSize(204, 28 + 5 * 42 + 6)
    popup:SetPoint("TOPLEFT", parent, "TOPRIGHT", 4, 0)
    local ac = BagsEnh_ACCENT or { 0.10, 0.80, 1.00 }
    popup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    popup:SetBackdropColor(0.055, 0.075, 0.09, 0.96)
    popup:SetBackdropBorderColor(ac[1], ac[2], ac[3], 0.55)
    popup:SetFrameStrata("HIGH")
    popup:EnableMouse(true)

    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("|cff00ccff" .. BagsEnh_L().BAGSLOTS_TITLE .. "|r")
    local tdiv = popup:CreateTexture(nil, "BORDER")
    tdiv:SetTexture("Interface\\Buttons\\WHITE8X8")
    tdiv:SetVertexColor(ac[1], ac[2], ac[3], 0.30)
    tdiv:SetPoint("TOPLEFT", 1, -24)
    tdiv:SetPoint("TOPRIGHT", -1, -24)
    tdiv:SetHeight(1)

    local y = -26
    for bag = 0, 4 do
        rows[bag] = BuildRow(popup, bag, y)
        y = y - 42
    end

    popup:RegisterEvent("BAG_UPDATE")
    popup:RegisterEvent("UNIT_INVENTORY_CHANGED")
    popup:SetScript("OnEvent", function() BagsEnh_RefreshBagSlots() end)
    popup:SetScript("OnShow", BagsEnh_RefreshBagSlots)
    popup:SetScript("OnHide", function() BagsEnh_HighlightBag(nil) end)
    popup:Hide()
    return popup
end

function BagsEnh_ToggleBagSlots()
    CreatePopup()
    if popup:IsShown() then popup:Hide() else popup:Show() end
end

-- Hidden with the main window (child of it), and closed explicitly here too.
