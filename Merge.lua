-- ============================================================
-- Merge — consolide les piles partielles (F7).
-- Fusionne les stacks du même objet jusqu'au max pour libérer des slots
-- (« des stacks incomplètes se créent, surtout en banque »). Machine
-- défensive calquée sur SortEngine : UN déplacement à la fois, attente des
-- locks entre chaque, abandon en combat. APIs non protégées
-- (SplitContainerItem / PickupContainerItem) — aucun risque de taint.
-- ============================================================

local runner = CreateFrame("Frame")
local st = { running = false, waiting = false, waitTicks = 0, moves = 0,
             containers = nil, label = nil }


local function ItemIDAt(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    return link and tonumber(link:match("item:(%d+)"))
end

local function AnyLockedIn(containers)
    for _, bag in ipairs(containers) do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local _, _, locked = GetContainerItemInfo(bag, slot)
            if locked then return true end
        end
    end
    return false
end

-- Trouve UN déplacement de fusion utile (rescan à chaque tick → toujours basé
-- sur l'état courant), ou nil quand tout est déjà optimalement compacté.
-- Un item n'est fusionnable que si son nombre de piles dépasse le minimum
-- ceil(total / maxStack) : sinon on ne ferait que déplacer sans rien libérer.
local function FindMerge(containers)
    local groups = {}
    for _, bag in ipairs(containers) do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local id = ItemIDAt(bag, slot)
            if id then
                local _, count = GetContainerItemInfo(bag, slot)
                local maxStack = select(8, GetItemInfo(id)) or 1
                if maxStack > 1 and count then
                    local g = groups[id]
                    if not g then g = { max = maxStack }; groups[id] = g end
                    g[#g + 1] = { bag = bag, slot = slot, count = count }
                end
            end
        end
    end
    for _, g in pairs(groups) do
        if #g >= 2 then
            local total = 0
            for _, s in ipairs(g) do total = total + s.count end
            if #g > math.ceil(total / g.max) then   -- au moins une pile en trop
                table.sort(g, function(a, b) return a.count > b.count end)
                local dst
                for i = 1, #g do if g[i].count < g.max then dst = g[i]; break end end
                local src
                for i = #g, 1, -1 do
                    if g[i] ~= dst and g[i].count > 0 then src = g[i]; break end
                end
                if dst and src then
                    local amount = math.min(g.max - dst.count, src.count)
                    if amount > 0 then return dst, src, amount end
                end
            end
        end
    end
    return nil
end

local function Finish(msg)
    st.running = false; st.waiting = false; st.containers = nil
    runner:SetScript("OnUpdate", nil)
    ClearCursor()
    if msg then BagsEnh_Print(msg) end
    if BagsEnh_IsBankShown and BagsEnh_IsBankShown() and BagsEnh_RefreshBank then
        BagsEnh_RefreshBank()
    end
    if BagsEnh_MarkDirty then BagsEnh_MarkDirty() end
end

local function Tick()
    if InCombatLockdown and InCombatLockdown() then
        Finish(BagsEnh_L().SORT_ABORT_COMBAT); return
    end
    if st.waiting then
        if AnyLockedIn(st.containers) then
            st.waitTicks = st.waitTicks + 1
            if st.waitTicks > 200 then Finish(BagsEnh_L().SORT_ABORT_STUCK) end
            return
        end
        st.waiting = false; st.waitTicks = 0
    end
    if st.moves > 400 then Finish(BagsEnh_L().SORT_ABORT_STUCK); return end
    local dst, src, amount = FindMerge(st.containers)
    if not dst then Finish(st.label); return end
    SplitContainerItem(src.bag, src.slot, amount)
    PickupContainerItem(dst.bag, dst.slot)
    st.waiting = true; st.waitTicks = 0; st.moves = st.moves + 1
end

-- Compacte les piles des `containers` (liste d'IDs de conteneurs).
function BagsEnh_MergeStacks(containers, doneMsg)
    if st.running then return end
    if InCombatLockdown and InCombatLockdown() then
        BagsEnh_Print(BagsEnh_L().SORT_ABORT_COMBAT); return
    end
    if AnyLockedIn(containers) then BagsEnh_Print(BagsEnh_L().SORT_BUSY); return end
    if not FindMerge(containers) then BagsEnh_Print(BagsEnh_L().MERGE_NONE); return end
    st.running = true; st.waiting = false; st.waitTicks = 0; st.moves = 0
    st.containers = containers; st.label = doneMsg or BagsEnh_L().MERGE_DONE
    runner:SetScript("OnUpdate", Tick)
end

-- Compacte les sacs du personnage (0-4).
function BagsEnh_MergeBagStacks()
    BagsEnh_MergeStacks({ 0, 1, 2, 3, 4 }, BagsEnh_L().MERGE_DONE)
end

-- Compacte la banque du personnage (-1 = banque principale + sacs 5..11).
function BagsEnh_MergeBankStacks()
    BagsEnh_MergeStacks({ -1, 5, 6, 7, 8, 9, 10, 11 }, BagsEnh_L().MERGE_DONE)
end
