-- ============================================================
-- Display panel — what shows and how gear is sub-grouped.
-- Content toggles (item level, unlearned-appearance section) live here,
-- plus the equipment / appearance grouping mode, so everyone can trade
-- density for readability to taste.
-- ============================================================

local function ReRender()
    if BagsEnhFrame and BagsEnhFrame:IsShown() then BagsEnh_Refresh() end
end

local function MakeCheck(parent, key, label, x, y, onChange)
    local cb = CreateFrame("CheckButton", "BagsEnhDisp" .. key, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    _G[cb:GetName() .. "Text"]:SetText(label)
    cb:SetChecked(BagsEnhDB[key])
    cb:SetScript("OnClick", function(self)
        BagsEnhDB[key] = self:GetChecked() and true or false
        if onChange then onChange() end
    end)
    return cb
end

function BagsEnh_CreateDisplayPanel()
    local ld = BagsEnh_L()
    local P = CreateFrame("Frame", "BagsEnhDisplayPanel", UIParent)
    P.name = ld.DISP_PANEL_TITLE
    P.parent = "BagsEnh"

    -- Grouping options (shared list for both dropdowns)
    local GROUP_OPTS = {
        { key = "material_slot", label = ld.GROUP_MATERIAL_SLOT },
        { key = "material",      label = ld.GROUP_MATERIAL },
        { key = "slot",          label = ld.GROUP_SLOT },
        { key = "none",          label = ld.GROUP_NONE },
    }
    local function LabelFor(key)
        for _, o in ipairs(GROUP_OPTS) do
            if o.key == key then return o.label end
        end
        return key
    end

    local title = P:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(ld.DISP_PANEL_TITLE)

    -- ============================================================
    -- Content
    -- ============================================================
    local s1 = P:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s1:SetPoint("TOPLEFT", 16, -46)
    s1:SetText("|cff00ccff" .. ld.DISP_CONTENT .. "|r")

    local cbIlvl = MakeCheck(P, "showItemLevel", ld.OPT_SHOW_ILVL, 16, -66, ReRender)
    local cbUncollected = MakeCheck(P, "groupUncollected", ld.OPT_GROUP_UNCOLLECTED, 16, -92, function()
        BagsEnh_InvalidateCategoryCache()
        ReRender()
    end)
    local cbHideBank = MakeCheck(P, "hideNativeBank", ld.OPT_HIDE_NATIVE_BANK, 16, -118)

    -- ============================================================
    -- Grouping
    -- ============================================================
    local s2 = P:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s2:SetPoint("TOPLEFT", 16, -154)
    s2:SetText("|cff00ccff" .. ld.DISP_GROUPING .. "|r")

    local hint = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -174)
    hint:SetWidth(400)
    hint:SetJustifyH("LEFT")
    hint:SetText(ld.DISP_GROUPING_HINT)

    local refreshers = {}
    local function MakeGroupingDD(dbKey, labelText, y)
        local lbl = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", 20, y)
        lbl:SetWidth(150)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(labelText)

        local dd = CreateFrame("Frame", "BagsEnhDispDD_" .. dbKey, P, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", 168, y + 4)
        UIDropDownMenu_SetWidth(dd, 150)
        local function Init()
            local info = UIDropDownMenu_CreateInfo()
            for _, o in ipairs(GROUP_OPTS) do
                info.text = o.label
                info.checked = (BagsEnhDB[dbKey] == o.key)
                info.func = function()
                    BagsEnhDB[dbKey] = o.key
                    UIDropDownMenu_SetText(dd, o.label)
                    CloseDropDownMenus()
                    ReRender()
                end
                UIDropDownMenu_AddButton(info)
            end
        end
        UIDropDownMenu_Initialize(dd, Init)
        UIDropDownMenu_SetText(dd, LabelFor(BagsEnhDB[dbKey]))
        refreshers[#refreshers + 1] = function()
            UIDropDownMenu_SetText(dd, LabelFor(BagsEnhDB[dbKey]))
        end
    end

    MakeGroupingDD("equipGrouping", ld.OPT_EQUIP_GROUPING, -200)
    MakeGroupingDD("uncollectedGrouping", ld.OPT_UNCOLLECTED_GROUPING, -234)

    -- ============================================================
    -- Promote trade goods to their own top-level categories
    -- ============================================================
    local s3 = P:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s3:SetPoint("TOPLEFT", 16, -274)
    s3:SetText("|cff00ccff" .. ld.DISP_PROMOTE .. "|r")

    local phint = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    phint:SetPoint("TOPLEFT", 16, -294)
    phint:SetWidth(450)
    phint:SetJustifyH("LEFT")
    phint:SetText(ld.DISP_PROMOTE_HINT)

    -- The subtype list comes from the client at runtime, so the checkboxes are
    -- built lazily (once the auction classes are available).
    local promoChecks, promoBuilt = {}, false
    local function BuildPromoChecks()
        if promoBuilt then return end
        local subs = BagsEnh_ProfSubtypes()
        if #subs == 0 then return end
        promoBuilt = true
        local cols = 3
        for i, sub in ipairs(subs) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local cb = CreateFrame("CheckButton", "BagsEnhProm" .. sub.index, P, "InterfaceOptionsCheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 16 + col * 150, -320 - row * 26)
            _G[cb:GetName() .. "Text"]:SetText(sub.name)
            cb.profIndex = sub.index
            cb:SetScript("OnClick", function(self)
                BagsEnhDB.promotedProf = BagsEnhDB.promotedProf or {}
                BagsEnhDB.promotedProf[self.profIndex] = self:GetChecked() and true or nil
                BagsEnh_InvalidateCategoryCache()
                if BagsEnhFrame and BagsEnhFrame:IsShown() then BagsEnh_Refresh() end
                if BagsEnh_IsBankShown and BagsEnh_IsBankShown() then BagsEnh_RefreshBank() end
            end)
            promoChecks[#promoChecks + 1] = cb
        end
    end

    P:SetScript("OnShow", function()
        cbIlvl:SetChecked(BagsEnhDB.showItemLevel)
        cbUncollected:SetChecked(BagsEnhDB.groupUncollected)
        cbHideBank:SetChecked(BagsEnhDB.hideNativeBank)
        for _, r in ipairs(refreshers) do r() end
        BuildPromoChecks()
        for _, cb in ipairs(promoChecks) do
            cb:SetChecked(BagsEnhDB.promotedProf and BagsEnhDB.promotedProf[cb.profIndex])
        end
    end)

    InterfaceOptions_AddCategory(P)
end
