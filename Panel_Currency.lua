-- ============================================================
-- Currency panel — footer display, cross-character total, and the list of
-- tracked currencies (watched game currencies + pinned items). Each row can be
-- marked "account-wide" (shown once instead of summed); pinned items can be
-- removed here (or via their + badge).
-- ============================================================

local function ReRender()
    if BagsEnhFrame and BagsEnhFrame:IsShown() then BagsEnh_Refresh() end
end

local function MakeCheck(parent, key, label, x, y)
    local cb = CreateFrame("CheckButton", "BagsEnhCur" .. key, parent, BagsEnh_CheckTemplate())
    cb:SetPoint("TOPLEFT", x, y)
    _G[cb:GetName() .. "Text"]:SetText(label)
    cb:SetScript("OnClick", function(self)
        BagsEnhDB[key] = self:GetChecked() and true or false
        ReRender()
    end)
    return cb
end

function BagsEnh_CreateCurrencyPanel()
    local ld = BagsEnh_L()
    local P = CreateFrame("Frame", "BagsEnhCurrencyPanel", UIParent)
    P.name = ld.CUR_PANEL_TITLE
    P.parent = "BagsEnh"

    local title = P:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ld.CUR_PANEL_TITLE)

    local cbFooter = MakeCheck(P, "showCurrencies", ld.CUR_SHOW_FOOTER, 16, -48)
    local cbTotal = MakeCheck(P, "currencyTotal", ld.CUR_SHOW_TOTAL, 16, -74)
    local cbOther = MakeCheck(P, "currencyOtherChars", ld.CUR_OTHER_CHARS, 16, -100)

    local s = P:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s:SetPoint("TOPLEFT", 16, -138)
    s:SetText("|cff00ccff" .. ld.CUR_TRACKED .. "|r")

    local hint = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -158)
    hint:SetWidth(450); hint:SetJustifyH("LEFT")
    hint:SetText(ld.CUR_TRACKED_HINT)

    local scroll = CreateFrame("ScrollFrame", "BagsEnhCurScroll", P, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -196)
    scroll:SetPoint("BOTTOMRIGHT", -34, 16)
    local child = CreateFrame("Frame", "BagsEnhCurScrollChild", scroll)
    child:SetSize(400, 10)
    scroll:SetScrollChild(child)

    local rows = {}
    local function RefreshList()
        for _, r in ipairs(rows) do r:Hide() end
        local list = BagsEnh_CurrencyList and BagsEnh_CurrencyList() or {}
        local y = 0
        for i, cur in ipairs(list) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, child)
                row:SetSize(400, 24)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(16, 16); row.icon:SetPoint("LEFT", 2, 0); row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.name:SetPoint("LEFT", 24, 0); row.name:SetWidth(180); row.name:SetJustifyH("LEFT")
                row.shared = CreateFrame("CheckButton", "BagsEnhCurShared" .. i, row, BagsEnh_CheckTemplate())
                row.shared:SetPoint("LEFT", 214, 0)
                _G[row.shared:GetName() .. "Text"]:SetText(ld.CUR_SHARED_COL)
                row.del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.del:SetSize(20, 20); row.del:SetPoint("LEFT", 348, 0); row.del:SetText("X")
                rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row.icon:SetTexture(cur.icon)
            row.name:SetText(cur.name)
            row.shared.curKey = cur.key
            row.shared:SetChecked(BagsEnh_CurShared(cur.key))
            row.shared:SetScript("OnClick", function(self)
                BagsEnhDB.currencyShared = BagsEnhDB.currencyShared or {}
                BagsEnhDB.currencyShared[self.curKey] = self:GetChecked() and true or nil
                ReRender()
            end)
            if cur.kind == "item" then
                row.del:Show()
                row.del.itemID = cur.itemID
                row.del:SetScript("OnClick", function(self)
                    BagsEnh_TogglePinItem(self.itemID)
                    RefreshList()
                end)
            else
                row.del:Hide()
            end
            row:Show()
            y = y + 26
        end
        child:SetHeight(math.max(y, 10))
        if #list == 0 then
            child.empty = child.empty or child:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            child.empty:SetPoint("TOPLEFT", 4, -4); child.empty:SetWidth(400); child.empty:SetJustifyH("LEFT")
            child.empty:SetText(ld.CUR_NONE); child.empty:Show()
        elseif child.empty then
            child.empty:Hide()
        end
    end

    P:SetScript("OnShow", function()
        cbFooter:SetChecked(BagsEnhDB.showCurrencies ~= false)
        cbTotal:SetChecked(BagsEnhDB.currencyTotal ~= false)
        cbOther:SetChecked(BagsEnhDB.currencyOtherChars ~= false)
        RefreshList()
    end)

    BagsEnh_AddOptionsCategory(P)
end
