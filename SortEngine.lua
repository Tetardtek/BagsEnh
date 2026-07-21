-- ============================================================
-- Physical bag sort — actually moves items so /played-clean bags.
-- Defensive state machine on OnUpdate: one pending swap at a time,
-- waits for each swap to resolve before the next, aborts in combat.
-- Uses only non-protected APIs (PickupContainerItem) — no taint risk.
-- ============================================================

local BAGS = {0, 1, 2, 3, 4}

local runner = CreateFrame("Frame")
local state = {
    running = false,
    plan = nil,       -- ordered list of target {bag, slot} => desired itemKey
    step = 0,
    waiting = false,  -- a swap is in flight, waiting for locks to clear
    waitStart = 0,
}

-- Sort key: category order → subCat → equip slot → quality desc → name
local function ItemSortKey(link)
    local cat, _, subCat, equipLoc = BagsEnh_Categorize(link)
    local catIdx = 99
    for i, c in ipairs(BagsEnh_GetCategoryOrder()) do
        if c == cat then catIdx = i break end
    end
    local name, _, quality = GetItemInfo(link)
    local equipIdx = BagsEnh_EQUIPLOC_ORDER[equipLoc or ""] or 50
    return {
        catIdx = catIdx,
        subCat = subCat or "",
        equipIdx = equipIdx,
        quality = -(quality or 0),   -- higher quality first
        name = name or "",
    }
end

local function KeyLess(a, b)
    if a.catIdx ~= b.catIdx then return a.catIdx < b.catIdx end
    if a.subCat ~= b.subCat then return a.subCat < b.subCat end
    if a.equipIdx ~= b.equipIdx then return a.equipIdx < b.equipIdx end
    if a.quality ~= b.quality then return a.quality < b.quality end
    return a.name < b.name
end

-- Flat list of all usable slots (bag,slot) in a stable order
local function AllSlots()
    local slots = {}
    for _, bag in ipairs(BAGS) do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            slots[#slots + 1] = {bag = bag, slot = slot}
        end
    end
    return slots
end

local function AnyLocked()
    for _, bag in ipairs(BAGS) do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local _, _, locked = GetContainerItemInfo(bag, slot)
            if locked then return true end
        end
    end
    return false
end

-- Builds the desired order: items sorted, laid into the flat slot list.
-- Returns a map [flatIndex] = desired item link.
local function BuildTargetOrder()
    local items = {}
    for _, bag in ipairs(BAGS) do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local link = GetContainerItemLink(bag, slot)
            if link then
                items[#items + 1] = {link = link, key = ItemSortKey(link)}
            end
        end
    end
    table.sort(items, function(a, b) return KeyLess(a.key, b.key) end)
    -- Fill last-to-first: the item that would land at the end is placed first
    -- (top-left in OneBag). Reversing the finished order keeps the category
    -- grouping intact while flipping the direction items are laid down.
    local n = #items
    for i = 1, math.floor(n / 2) do
        items[i], items[n - i + 1] = items[n - i + 1], items[i]
    end
    return items
end

-- Finds the (bag,slot) currently holding the link we want at target index,
-- searching from a starting flat position onward. Returns bag,slot or nil.
local function FindItemFrom(slots, fromIdx, wantLink)
    for i = fromIdx, #slots do
        local s = slots[i]
        if GetContainerItemLink(s.bag, s.slot) == wantLink then
            return i
        end
    end
    return nil
end

local function Finish(msg)
    state.running = false
    state.plan = nil
    state.waiting = false
    runner:SetScript("OnUpdate", nil)
    ClearCursor()
    if msg then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBagsEnh:|r " .. msg)
    end
    if BagsEnh_MarkDirty then BagsEnh_MarkDirty() end
end

-- Selection-sort by swaps: for each target position, bring the right item in.
-- Because stacks of the same link are interchangeable, matching by link is safe.
local function Tick()
    if InCombatLockdown and InCombatLockdown() then
        Finish(BagsEnh_L().SORT_ABORT_COMBAT)
        return
    end

    if state.waiting then
        if AnyLocked() then
            -- still resolving; bail out if it hangs too long
            state.waitTicks = (state.waitTicks or 0) + 1
            if state.waitTicks > 200 then
                Finish(BagsEnh_L().SORT_ABORT_STUCK)
            end
            return
        end
        state.waiting = false
        state.waitTicks = 0
        state.step = state.step + 1
    end

    local slots = state.slots
    local targets = state.plan
    if state.step > #targets or state.step > #slots then
        Finish(BagsEnh_L().SORT_DONE)
        return
    end

    local idx = state.step
    local dest = slots[idx]
    local wantLink = targets[idx] and targets[idx].link
    if not wantLink then
        Finish(BagsEnh_L().SORT_DONE)
        return
    end

    -- Already correct? advance
    if GetContainerItemLink(dest.bag, dest.slot) == wantLink then
        state.step = state.step + 1
        return
    end

    -- Find the wanted item somewhere at or after this position, swap it in
    local srcIdx = FindItemFrom(slots, idx, wantLink)
    if not srcIdx then
        -- desired link not found further down (already placed above): skip
        state.step = state.step + 1
        return
    end
    local src = slots[srcIdx]

    PickupContainerItem(src.bag, src.slot)
    PickupContainerItem(dest.bag, dest.slot)
    state.waiting = true
    state.waitTicks = 0
end

function BagsEnh_SortBags()
    if state.running then return end
    if InCombatLockdown and InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBagsEnh:|r " .. BagsEnh_L().SORT_ABORT_COMBAT)
        return
    end
    if AnyLocked() then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBagsEnh:|r " .. BagsEnh_L().SORT_BUSY)
        return
    end

    state.running = true
    state.slots = AllSlots()
    state.plan = BuildTargetOrder()
    state.step = 1
    state.waiting = false
    state.waitTicks = 0
    runner:SetScript("OnUpdate", Tick)
end
