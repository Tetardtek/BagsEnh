-- ============================================================
-- Options panel — Interface > AddOns > BagsEnh
-- General settings + profiles (save/load/export/import).
-- ============================================================

local function MakeCheck(parent, key, label, x, y, onChange)
    local cb = CreateFrame("CheckButton", "BagsEnhOpt" .. key, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    _G[cb:GetName() .. "Text"]:SetText(label)
    cb:SetChecked(BagsEnhDB[key])
    cb:SetScript("OnClick", function(self)
        BagsEnhDB[key] = self:GetChecked() and true or false
        if onChange then onChange() end
    end)
    return cb
end

local function MakeSlider(parent, key, label, x, y, min, max, step, isFloat, onChange)
    local s = CreateFrame("Slider", "BagsEnhOpt" .. key, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y)
    s:SetWidth(200)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    _G[s:GetName() .. "Low"]:SetText(isFloat and string.format("%.1f", min) or min)
    _G[s:GetName() .. "High"]:SetText(isFloat and string.format("%.1f", max) or max)
    _G[s:GetName() .. "Text"]:SetText(label)
    local val = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("TOP", s, "BOTTOM", 0, -2)
    s:SetValue(BagsEnhDB[key] or min)
    val:SetText(isFloat and string.format("%.2f", BagsEnhDB[key] or min) or (BagsEnhDB[key] or min))
    s:SetScript("OnValueChanged", function(self, value)
        local snapped = math.floor(value / step + 0.5) * step
        if isFloat then snapped = tonumber(string.format("%.2f", snapped)) end
        if snapped ~= value then self:SetValue(snapped); return end
        val:SetText(isFloat and string.format("%.2f", snapped) or snapped)
        BagsEnhDB[key] = snapped
        if onChange then onChange() end
    end)
    return s
end

-- Import/export popup
StaticPopupDialogs["BAGSENH_EXPORT"] = {
    text = "%s", button1 = OKAY, hasEditBox = true, editBoxWidth = 260,
    timeout = 0, whileDead = true, hideOnEscape = true,
    OnShow = function(self)
        local eb = self.editBox or _G[self:GetName() .. "EditBox"]
        eb:SetText(self.data or "")
        eb:HighlightText()
        eb:SetFocus()
    end,
}
StaticPopupDialogs["BAGSENH_IMPORT"] = {
    text = "%s", button1 = ACCEPT, button2 = CANCEL, hasEditBox = true, editBoxWidth = 260,
    timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(self)
        local eb = self.editBox or _G[self:GetName() .. "EditBox"]
        local str = eb:GetText()
        local ld = BagsEnh_L()
        local name = "Import"
        local i = 1
        while BagsEnhDB.profiles and BagsEnhDB.profiles[name] do
            i = i + 1; name = "Import " .. i
        end
        if BagsEnh_ImportProfile(str, name) then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBagsEnh:|r " .. ld.PROF_IMPORTED:format(name))
            if BagsEnh_RefreshProfileDD then BagsEnh_RefreshProfileDD() end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBagsEnh:|r " .. ld.PROF_IMPORT_ERR)
        end
    end,
}
StaticPopupDialogs["BAGSENH_SAVEAS"] = {
    text = "%s", button1 = OKAY, button2 = CANCEL, hasEditBox = true, editBoxWidth = 200,
    timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(self)
        local eb = self.editBox or _G[self:GetName() .. "EditBox"]
        local name = eb:GetText()
        if name and name ~= "" then
            BagsEnh_SaveProfile(name)
            BagsEnhDB.currentProfile = name
            if BagsEnh_RefreshProfileDD then BagsEnh_RefreshProfileDD() end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBagsEnh:|r " .. BagsEnh_L().PROF_SAVED:format(name))
        end
    end,
}

function BagsEnh_CreateOptionsPanel()
    local ld = BagsEnh_L()
    local P = CreateFrame("Frame", "BagsEnhOptionsPanel", UIParent)
    P.name = "BagsEnh"

    local title = P:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BagsEnh")

    -- General
    local cbUnified = MakeCheck(P, "enabled", ld.OPT_UNIFIED, 16, -50, function()
        BagsEnh_SetUnified(BagsEnhDB.enabled)
    end)

    local slScale = MakeSlider(P, "scale", ld.OPT_SCALE, 20, -95, 0.5, 2.0, 0.05, true, BagsEnh_ApplySettings)
    local function ReRender()
        if BagsEnhFrame and BagsEnhFrame:IsShown() then BagsEnh_Refresh() end
    end
    local slCols = MakeSlider(P, "columns", ld.OPT_COLUMNS, 20, -150, 6, 20, 1, false, ReRender)
    local slIcon = MakeSlider(P, "iconSize", ld.OPT_ICON_SIZE, 240, -150, 24, 48, 1, false, ReRender)
    local slSpacing = MakeSlider(P, "spacing", ld.OPT_SPACING, 20, -205, 0, 16, 1, false, ReRender)

    local cbIlvl = MakeCheck(P, "showItemLevel", ld.OPT_SHOW_ILVL, 240, -195, ReRender)
    local cbUncollected = MakeCheck(P, "groupUncollected", ld.OPT_GROUP_UNCOLLECTED, 240, -225, function()
        BagsEnh_InvalidateCategoryCache()
        ReRender()
    end)

    local btnReset = CreateFrame("Button", nil, P, "UIPanelButtonTemplate")
    btnReset:SetSize(160, 22)
    btnReset:SetPoint("TOPLEFT", 16, -260)
    btnReset:SetText(ld.OPT_RESET_POS)
    btnReset:SetScript("OnClick", function()
        BagsEnhDB.posX, BagsEnhDB.posY = 0, 0
        if BagsEnhFrame then
            BagsEnhFrame:ClearAllPoints()
            BagsEnhFrame:SetPoint("CENTER", 0, 0)
        end
    end)

    -- Separator
    local sep = P:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 16, -292)
    sep:SetPoint("TOPRIGHT", -16, -292)
    sep:SetTexture(0.4, 0.4, 0.4, 0.6)

    -- Profiles section
    local pTitle = P:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pTitle:SetPoint("TOPLEFT", 16, -304)
    pTitle:SetText(ld.PROF_SECTION)

    local dd = CreateFrame("Frame", "BagsEnhProfileDD", P, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", 0, -324)
    UIDropDownMenu_SetWidth(dd, 160)

    local function OnPick(name)
        BagsEnhDB.currentProfile = name
        UIDropDownMenu_SetText(dd, name)
    end
    local function InitDD()
        local info = UIDropDownMenu_CreateInfo()
        for _, n in ipairs(BagsEnh_ListProfiles()) do
            info.text = n
            info.func = function() OnPick(n) end
            info.checked = (BagsEnhDB.currentProfile == n)
            UIDropDownMenu_AddButton(info)
        end
    end
    UIDropDownMenu_Initialize(dd, InitDD)
    UIDropDownMenu_SetText(dd, BagsEnhDB.currentProfile or ld.PROF_NONE)

    function BagsEnh_RefreshProfileDD()
        UIDropDownMenu_Initialize(dd, InitDD)
        UIDropDownMenu_SetText(dd, BagsEnhDB.currentProfile or ld.PROF_NONE)
    end

    local function CurrentName() return BagsEnhDB.currentProfile end

    local function Btn(label, x, y, w, fn)
        local b = CreateFrame("Button", nil, P, "UIPanelButtonTemplate")
        b:SetSize(w, 22)
        b:SetPoint("TOPLEFT", x, y)
        b:SetText(label)
        b:SetScript("OnClick", fn)
        return b
    end

    Btn(ld.PROF_LOAD, 16, -357, 90, function()
        local n = CurrentName()
        if n and BagsEnh_LoadProfile(n) then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBagsEnh:|r " .. ld.PROF_LOADED:format(n))
        end
    end)
    Btn(ld.PROF_SAVE, 110, -357, 90, function()
        local n = CurrentName()
        if n then
            BagsEnh_SaveProfile(n)
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBagsEnh:|r " .. ld.PROF_SAVED:format(n))
        else
            StaticPopup_Show("BAGSENH_SAVEAS", ld.PROF_NAME_PROMPT)
        end
    end)
    Btn(ld.PROF_SAVEAS, 204, -357, 90, function()
        StaticPopup_Show("BAGSENH_SAVEAS", ld.PROF_NAME_PROMPT)
    end)
    Btn(ld.PROF_DELETE, 16, -385, 90, function()
        local n = CurrentName()
        if n then
            BagsEnh_DeleteProfile(n)
            BagsEnhDB.currentProfile = nil
            BagsEnh_RefreshProfileDD()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffBagsEnh:|r " .. ld.PROF_DELETED:format(n))
        end
    end)
    Btn(ld.PROF_EXPORT, 110, -385, 90, function()
        local n = CurrentName()
        local str = n and BagsEnh_ExportProfile(n)
        if str then StaticPopup_Show("BAGSENH_EXPORT", ld.PROF_EXPORT_HINT, nil, str) end
    end)
    Btn(ld.PROF_IMPORT, 204, -385, 90, function()
        StaticPopup_Show("BAGSENH_IMPORT", ld.PROF_IMPORT_HINT)
    end)

    P:SetScript("OnShow", function()
        cbUnified:SetChecked(BagsEnhDB.enabled)
        slScale:SetValue(BagsEnhDB.scale or 1.0)
        slCols:SetValue(BagsEnhDB.columns or 12)
        slIcon:SetValue(BagsEnhDB.iconSize or 37)
        cbIlvl:SetChecked(BagsEnhDB.showItemLevel)
        cbUncollected:SetChecked(BagsEnhDB.groupUncollected)
        BagsEnh_RefreshProfileDD()
    end)

    InterfaceOptions_AddCategory(P)
end
