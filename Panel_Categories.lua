-- ============================================================
-- Custom Categories panel.
--  1) Create / rename / delete your own categories. Once a category exists,
--     move items into it with the item's top-left "+" badge (or a name rule).
--  2) Auto-sort rules: a name fragment routes matching items to a category
--     (built-in or one of yours).
-- ============================================================

StaticPopupDialogs["BAGSENH_RENAME_CAT"] = {
    text = "%s", button1 = OKAY, button2 = CANCEL, hasEditBox = true, editBoxWidth = 200,
    timeout = 0, whileDead = true, hideOnEscape = true,
    OnShow = function(self)
        local eb = self.editBox or _G[self:GetName() .. "EditBox"]
        eb:SetText((self.data and self.data.name) or "")
        eb:HighlightText()
        eb:SetFocus()
    end,
    OnAccept = function(self)
        local eb = self.editBox or _G[self:GetName() .. "EditBox"]
        local name = eb:GetText()
        if self.data and name and name ~= "" then
            BagsEnh_RenameUserCategory(self.data.key, name)
            if BagsEnh_RefreshUserCats then BagsEnh_RefreshUserCats() end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        local name = self:GetText()
        if parent.data and name and name ~= "" then
            BagsEnh_RenameUserCategory(parent.data.key, name)
            if BagsEnh_RefreshUserCats then BagsEnh_RefreshUserCats() end
        end
        parent:Hide()
    end,
}

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
    hint:SetWidth(400)
    hint:SetJustifyH("LEFT")
    hint:SetText(ld.CAT_PANEL_HINT)

    -- ============================================================
    -- Section 1 — your categories
    -- ============================================================
    local s1 = P:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s1:SetPoint("TOPLEFT", 16, -70)
    s1:SetText("|cff00ccff" .. ld.CAT_YOURS .. "|r")

    local createLabel = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    createLabel:SetPoint("TOPLEFT", 16, -92)
    createLabel:SetText(ld.CAT_CREATE_LABEL)

    local createEdit = CreateFrame("EditBox", "BagsEnhCatCreate", P, "InputBoxTemplate")
    createEdit:SetSize(160, 20)
    createEdit:SetPoint("TOPLEFT", 20, -112)
    createEdit:SetAutoFocus(false)

    local create = CreateFrame("Button", nil, P, "UIPanelButtonTemplate")
    create:SetSize(72, 22)
    create:SetPoint("TOPLEFT", 190, -110)
    create:SetText(ld.CAT_CREATE)

    -- Scroll list of user categories
    local userScroll = CreateFrame("ScrollFrame", "BagsEnhUserCatScroll", P, "UIPanelScrollFrameTemplate")
    userScroll:SetPoint("TOPLEFT", 16, -140)
    userScroll:SetSize(360, 120)
    local userChild = CreateFrame("Frame", "BagsEnhUserCatChild", userScroll)
    userChild:SetSize(360, 10)
    userScroll:SetScrollChild(userChild)

    local userRows = {}
    local function RefreshUsers()
        for _, r in ipairs(userRows) do r:Hide() end
        local keys = BagsEnh_UserCategoryKeys()
        local y = 0
        for i, key in ipairs(keys) do
            local row = userRows[i]
            if not row then
                row = CreateFrame("Frame", nil, userChild)
                row:SetSize(340, 22)
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", 4, 0)
                row.text:SetJustifyH("LEFT")
                row.text:SetWidth(196)
                row.ren = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.ren:SetSize(70, 20)
                row.ren:SetPoint("LEFT", 208, 0)
                row.ren:SetText(ld.CAT_RENAME)
                row.del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.del:SetSize(20, 20)
                row.del:SetPoint("LEFT", 282, 0)
                row.del:SetText("X")
                userRows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row.text:SetText("|cffffd100" .. BagsEnh_CategoryLabel(key) .. "|r")
            row.ren:SetScript("OnClick", function()
                StaticPopup_Show("BAGSENH_RENAME_CAT", ld.CAT_RENAME_PROMPT, nil,
                    { key = key, name = BagsEnh_CategoryLabel(key) })
            end)
            row.del:SetScript("OnClick", function()
                BagsEnh_RemoveUserCategory(key)
                RefreshUsers()
            end)
            row:Show()
            y = y + 24
        end
        userChild:SetHeight(math.max(y, 10))
        if #keys == 0 then
            userChild.empty = userChild.empty
                or userChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            userChild.empty:SetPoint("TOPLEFT", 4, -4)
            userChild.empty:SetWidth(340)
            userChild.empty:SetJustifyH("LEFT")
            userChild.empty:SetText(ld.CAT_NONE_YET)
            userChild.empty:Show()
        elseif userChild.empty then
            userChild.empty:Hide()
        end
    end
    BagsEnh_RefreshUserCats = RefreshUsers

    create:SetScript("OnClick", function()
        local name = createEdit:GetText()
        if name and name ~= "" then
            BagsEnh_AddUserCategory(name)
            createEdit:SetText("")
            createEdit:ClearFocus()
            RefreshUsers()
        end
    end)
    createEdit:SetScript("OnEnterPressed", function(self)
        local name = self:GetText()
        if name and name ~= "" then
            BagsEnh_AddUserCategory(name)
            self:SetText("")
            RefreshUsers()
        end
        self:ClearFocus()
    end)
    createEdit:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)

    -- Separator
    local sep = P:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 16, -270)
    sep:SetPoint("TOPRIGHT", -30, -270)
    sep:SetTexture(0.4, 0.4, 0.4, 0.6)

    -- ============================================================
    -- Section 2 — auto-sort rules (name fragment -> category)
    -- ============================================================
    local s2 = P:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s2:SetPoint("TOPLEFT", 16, -282)
    s2:SetText("|cff00ccff" .. ld.CAT_RULES_SECTION .. "|r")

    local rulesHint = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    rulesHint:SetPoint("TOPLEFT", 16, -302)
    rulesHint:SetWidth(400)
    rulesHint:SetJustifyH("LEFT")
    rulesHint:SetText(ld.CAT_RULES_HINT)

    local patLabel = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    patLabel:SetPoint("TOPLEFT", 16, -326)
    patLabel:SetText(ld.CAT_PATTERN)

    local edit = CreateFrame("EditBox", "BagsEnhCatPattern", P, "InputBoxTemplate")
    edit:SetSize(160, 20)
    edit:SetPoint("TOPLEFT", 20, -346)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)

    -- Category target dropdown — built-in categories + your own
    local dd = CreateFrame("Frame", "BagsEnhCatTarget", P, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", 178, -342)
    UIDropDownMenu_SetWidth(dd, 120)
    local selectedCat = "misc"
    local function InitDD()
        local info = UIDropDownMenu_CreateInfo()
        for _, catKey in ipairs(BagsEnh_GetCategoryOrder()) do
            if catKey ~= "new" and catKey ~= "hidden" then
                info.text = BagsEnh_CategoryLabel(catKey)
                info.func = function()
                    selectedCat = catKey
                    UIDropDownMenu_SetText(dd, BagsEnh_CategoryLabel(catKey))
                    CloseDropDownMenus()
                end
                info.checked = (selectedCat == catKey)
                UIDropDownMenu_AddButton(info)
            end
        end
    end
    UIDropDownMenu_Initialize(dd, InitDD)
    UIDropDownMenu_SetText(dd, BagsEnh_CategoryLabel(selectedCat))

    local ruleScroll = CreateFrame("ScrollFrame", "BagsEnhCatScroll", P, "UIPanelScrollFrameTemplate")
    ruleScroll:SetPoint("TOPLEFT", 16, -374)
    ruleScroll:SetPoint("BOTTOMRIGHT", -34, 16)
    local child = CreateFrame("Frame", "BagsEnhCatScrollChild", ruleScroll)
    child:SetSize(360, 10)
    ruleScroll:SetScrollChild(child)

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
            row.text:SetText(('"%s"  |cff888888->|r  |cffffd100%s|r'):format(pat, BagsEnh_CategoryLabel(catKey)))
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

    local add = CreateFrame("Button", nil, P, "UIPanelButtonTemplate")
    add:SetSize(60, 22)
    add:SetPoint("TOPLEFT", 320, -344)
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

    P:SetScript("OnShow", function()
        RefreshUsers()
        RefreshList()
    end)
    BagsEnh_AddOptionsCategory(P)
end
