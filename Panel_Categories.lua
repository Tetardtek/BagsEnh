-- ============================================================
-- Custom Categories panel — name-pattern rules.
-- "Skinning Knife" or just "Scroll" -> a category of your choice.
-- Shift-click an item into the field to auto-fill its name.
-- ============================================================

function BagsEnh_CreateCategoriesPanel()
    local ld = BagsEnh_L()
    local P = CreateFrame("Frame", "BagsEnhCategoriesPanel", UIParent)
    P.name = ld.CAT_PANEL_TITLE
    P.parent = "BagsEnh"

    local title = P:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ld.CAT_PANEL_TITLE)

    local hint = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -40)
    hint:SetText(ld.CAT_PANEL_HINT)

    -- Pattern input
    local patLabel = P:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    patLabel:SetPoint("TOPLEFT", 16, -70)
    patLabel:SetText(ld.CAT_PATTERN)

    local edit = CreateFrame("EditBox", "BagsEnhCatPattern", P, "InputBoxTemplate")
    edit:SetSize(180, 20)
    edit:SetPoint("TOPLEFT", 20, -90)
    edit:SetAutoFocus(false)
    -- Shift-click an item anywhere feeds its name here when focused
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)

    -- Category target dropdown
    local dd = CreateFrame("Frame", "BagsEnhCatTarget", P, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", 200, -86)
    UIDropDownMenu_SetWidth(dd, 120)
    local selectedCat = "misc"
    local function InitDD()
        local info = UIDropDownMenu_CreateInfo()
        for _, catKey in ipairs(BagsEnh_CATEGORY_ORDER) do
            if catKey ~= "new" and catKey ~= "hidden" then
                info.text = ld[BagsEnh_CATEGORY_LABELS[catKey]] or catKey
                info.func = function()
                    selectedCat = catKey
                    UIDropDownMenu_SetText(dd, info.text)
                end
                info.checked = (selectedCat == catKey)
                UIDropDownMenu_AddButton(info)
            end
        end
    end
    UIDropDownMenu_Initialize(dd, InitDD)
    UIDropDownMenu_SetText(dd, ld[BagsEnh_CATEGORY_LABELS[selectedCat]])

    -- Scrollable list of existing rules
    local scroll = CreateFrame("ScrollFrame", "BagsEnhCatScroll", P, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -130)
    scroll:SetPoint("BOTTOMRIGHT", -34, 16)
    local child = CreateFrame("Frame", "BagsEnhCatScrollChild", scroll)
    child:SetSize(scroll:GetWidth() or 400, 10)
    scroll:SetScrollChild(child)

    local rows = {}
    local function RefreshList()
        for _, r in ipairs(rows) do r:Hide() end
        local patterns = {}
        if BagsEnhDB.customRules then
            for p in pairs(BagsEnhDB.customRules) do patterns[#patterns + 1] = p end
        end
        table.sort(patterns)
        local y = 0
        for i, pat in ipairs(patterns) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, child)
                row:SetSize(360, 22)
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", 4, 0)
                row.text:SetJustifyH("LEFT")
                row.text:SetWidth(300)
                row.del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.del:SetSize(20, 20)
                row.del:SetPoint("RIGHT", 0, 0)
                row.del:SetText("X")
                rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            local catKey = BagsEnhDB.customRules[pat]
            local catName = ld[BagsEnh_CATEGORY_LABELS[catKey]] or catKey
            row.text:SetText(('"%s"  |cff888888->|r  |cffffd100%s|r'):format(pat, catName))
            row.del:SetScript("OnClick", function()
                BagsEnh_RemoveCustomRule(pat)
                RefreshList()
            end)
            row:Show()
            y = y + 24
        end
        child:SetHeight(math.max(y, 10))
        if #patterns == 0 then
            child.empty = child.empty or child:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            child.empty:SetPoint("TOPLEFT", 4, -4)
            child.empty:SetText(ld.CAT_NO_RULES)
            child.empty:Show()
        elseif child.empty then
            child.empty:Hide()
        end
    end

    -- Add button
    local add = CreateFrame("Button", nil, P, "UIPanelButtonTemplate")
    add:SetSize(80, 22)
    add:SetPoint("TOPLEFT", 330, -88)
    add:SetText(ld.CAT_ADD)
    add:SetScript("OnClick", function()
        local pat = edit:GetText()
        -- Strip an item link if one was shift-clicked in: keep the name only
        local linkName = pat:match("%[(.-)%]")
        if linkName then pat = linkName end
        if pat and pat ~= "" then
            BagsEnh_AddCustomRule(pat, selectedCat)
            edit:SetText("")
            edit:ClearFocus()
            RefreshList()
        end
    end)

    P:SetScript("OnShow", RefreshList)
    InterfaceOptions_AddCategory(P)
end
