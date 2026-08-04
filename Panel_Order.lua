-- ============================================================
-- Section Order panel — reorder categories with up/down buttons.
-- "New" stays first and "Hidden" stays last (not listed here).
-- ============================================================

function BagsEnh_CreateOrderPanel()
    local ld = BagsEnh_L()
    local P = CreateFrame("Frame", "BagsEnhOrderPanel", UIParent)
    P.name = ld.ORDER_PANEL_TITLE
    P.parent = "BagsEnh"

    local title = P:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ld.ORDER_PANEL_TITLE)

    local hint = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -40)
    hint:SetText(ld.ORDER_PANEL_HINT)

    local rows = {}
    local function Refresh()
        for _, r in ipairs(rows) do r:Hide() end
        local order = BagsEnh_GetOrderableCategories()
        for i, cat in ipairs(order) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, P)
                row:SetSize(320, 24)
                row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.label:SetPoint("LEFT", 60, 0)
                row.label:SetJustifyH("LEFT")

                row.up = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.up:SetSize(24, 22)
                row.up:SetPoint("LEFT", 0, 0)
                row.up:SetText("|cffffd100^|r")

                row.down = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.down:SetSize(24, 22)
                row.down:SetPoint("LEFT", 28, 0)
                row.down:SetText("|cffffd100v|r")
                rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 16, -70 - (i - 1) * 26)
            row.label:SetText(BagsEnh_CategoryLabel(cat))

            row.up:SetScript("OnClick", function() BagsEnh_MoveCategory(cat, -1); Refresh() end)
            row.down:SetScript("OnClick", function() BagsEnh_MoveCategory(cat, 1); Refresh() end)
            if i == 1 then row.up:Disable() else row.up:Enable() end
            if i == #order then row.down:Disable() else row.down:Enable() end
            row:Show()
        end
    end

    local btnReset = CreateFrame("Button", nil, P, "UIPanelButtonTemplate")
    btnReset:SetSize(140, 22)
    btnReset:SetPoint("BOTTOMLEFT", 16, 16)
    btnReset:SetText(ld.ORDER_RESET)
    btnReset:SetScript("OnClick", function()
        BagsEnhDB.categoryOrder = nil
        if BagsEnh_MarkDirty then BagsEnh_MarkDirty() end
        if BagsEnhFrame and BagsEnhFrame:IsShown() then BagsEnh_Refresh() end
        Refresh()
    end)

    P:SetScript("OnShow", Refresh)
    BagsEnh_AddOptionsCategory(P)
end
