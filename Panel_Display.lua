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

    -- Raccourci des actions groupées de section (F1) — colonne de droite de la
    -- zone Contenu pour ne pas bousculer la mise en page verticale.
    local amLbl = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    amLbl:SetPoint("TOPLEFT", 300, -60)
    amLbl:SetText(ld.OPT_ACTION_MOD)
    local MODS = { { key = "ctrl", label = ld.MOD_CTRL },
                   { key = "alt", label = ld.MOD_ALT },
                   { key = "shift", label = ld.MOD_SHIFT } }
    local function ModLabel(k)
        for _, o in ipairs(MODS) do if o.key == k then return o.label end end
        return k
    end
    local amDD = CreateFrame("Frame", "BagsEnhDispActionMod", P, "UIDropDownMenuTemplate")
    amDD:SetPoint("TOPLEFT", 290, -80)
    UIDropDownMenu_SetWidth(amDD, 110)
    UIDropDownMenu_Initialize(amDD, function()
        local info = UIDropDownMenu_CreateInfo()
        for _, o in ipairs(MODS) do
            info.text = o.label
            info.checked = ((BagsEnhDB.actionModifier or "ctrl") == o.key)
            info.func = function()
                BagsEnhDB.actionModifier = o.key
                UIDropDownMenu_SetText(amDD, o.label)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(amDD, ModLabel(BagsEnhDB.actionModifier or "ctrl"))
    refreshers[#refreshers + 1] = function()
        UIDropDownMenu_SetText(amDD, ModLabel(BagsEnhDB.actionModifier or "ctrl"))
    end

    -- Garde-fous de la vente groupée (F1) — même colonne, sous le raccourci.
    -- Les noms de rareté viennent du client (ITEM_QUALITYn_DESC) : déjà
    -- traduits et cohérents avec le reste de l'interface du jeu.
    local sqLbl = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sqLbl:SetPoint("TOPLEFT", 300, -116)
    sqLbl:SetText(ld.OPT_SELL_MAX_QUALITY)
    local function QualLabel(q)
        local name = _G["ITEM_QUALITY" .. q .. "_DESC"] or tostring(q)
        local c = BagsEnh_QUALITY_COLORS and BagsEnh_QUALITY_COLORS[q]
        if not c then return name end
        return ("|cff%s%s|r"):format(BagsEnh_ColorHex(c[1], c[2], c[3]), name)
    end
    local sqDD = CreateFrame("Frame", "BagsEnhDispSellQuality", P, "UIDropDownMenuTemplate")
    sqDD:SetPoint("TOPLEFT", 290, -136)
    UIDropDownMenu_SetWidth(sqDD, 110)
    UIDropDownMenu_Initialize(sqDD, function()
        local info = UIDropDownMenu_CreateInfo()
        for q = 0, 5 do
            info.text = QualLabel(q)
            info.checked = ((BagsEnhDB.sellMaxQuality or 2) == q)
            info.func = function()
                BagsEnhDB.sellMaxQuality = q
                UIDropDownMenu_SetText(sqDD, QualLabel(q))
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(sqDD, QualLabel(BagsEnhDB.sellMaxQuality or 2))
    refreshers[#refreshers + 1] = function()
        UIDropDownMenu_SetText(sqDD, QualLabel(BagsEnhDB.sellMaxQuality or 2))
    end

    -- Plafond de niveau d'objet : saisie libre plutôt qu'une liste de paliers,
    -- les seuils utiles dépendant du contenu joué. 0 désactive le plafond.
    -- Label et champ sur UNE ligne : sous -190 la colonne de droite percute le
    -- menu de groupement de gauche (x 168 + 150 de large + ~40 de chrome).
    local siLbl = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    siLbl:SetPoint("TOPLEFT", 300, -176)
    siLbl:SetWidth(118)
    siLbl:SetJustifyH("LEFT")
    siLbl:SetText(ld.OPT_SELL_MAX_ILVL)
    local siBox = CreateFrame("EditBox", "BagsEnhDispSellILvl", P, "InputBoxTemplate")
    siBox:SetPoint("TOPLEFT", 428, -172)
    siBox:SetSize(52, 20)
    siBox:SetAutoFocus(false)
    siBox:SetNumeric(true)
    siBox:SetMaxLetters(4)
    siBox:SetText(tostring(BagsEnhDB.sellMaxILvl or 0))
    -- Validé à Entrée ET à la perte du focus : sans le second, une valeur
    -- tapée puis abandonnée resterait affichée sans être enregistrée.
    local function CommitILvl(self)
        local v = tonumber(self:GetText()) or 0
        if v < 0 then v = 0 end
        BagsEnhDB.sellMaxILvl = v
        self:SetText(tostring(v))
        self:ClearFocus()
    end
    siBox:SetScript("OnEnterPressed", CommitILvl)
    siBox:SetScript("OnEditFocusLost", CommitILvl)
    refreshers[#refreshers + 1] = function()
        siBox:SetText(tostring(BagsEnhDB.sellMaxILvl or 0))
    end

    -- L'explication vit en infobulle : un bloc de texte à cet endroit
    -- déborderait sur le menu de groupement de la colonne de gauche.
    local function SellTip(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ld.OPT_SELL_LIMITS_HINT, 0.55, 0.82, 1, 1, true)
        GameTooltip:Show()
    end
    local function HideTip() GameTooltip:Hide() end

    -- Troisième garde-fou de vente, en colonne de GAUCHE : la colonne de droite
    -- ne peut pas descendre sous -190 sans percuter le menu de groupement.
    -- Placé JUSTE AVANT la section « Trade goods », qui a été décalée de 30 px :
    -- ses cases sont construites par une boucle (-350 - row * 26) et leur nombre
    -- dépend du client, donc rien ne peut être ancré « après » elles de façon
    -- fiable.
    local bfCB = CreateFrame("CheckButton", "BagsEnhDispSellProtectBF", P, "InterfaceOptionsCheckButtonTemplate")
    bfCB:SetPoint("TOPLEFT", 16, -270)
    _G[bfCB:GetName() .. "Text"]:SetText(ld.OPT_SELL_PROTECT_BF)
    bfCB:SetChecked(BagsEnhDB.sellProtectBloodforged ~= false)
    bfCB:SetScript("OnClick", function(self)
        BagsEnhDB.sellProtectBloodforged = self:GetChecked() and true or false
    end)
    bfCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ld.OPT_SELL_PROTECT_BF_TIP, 0.55, 0.82, 1, 1, true)
        GameTooltip:Show()
    end)
    bfCB:SetScript("OnLeave", HideTip)
    refreshers[#refreshers + 1] = function()
        bfCB:SetChecked(BagsEnhDB.sellProtectBloodforged ~= false)
    end

    for _, f in ipairs({ sqDD, siBox }) do
        f:EnableMouse(true)     -- un Frame de dropdown ne reçoit pas la souris sans ça
        f:SetScript("OnEnter", SellTip)
        f:SetScript("OnLeave", HideTip)
    end

    -- ============================================================
    -- Promote trade goods to their own top-level categories
    -- ============================================================
    local s3 = P:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    s3:SetPoint("TOPLEFT", 16, -304)
    s3:SetText("|cff00ccff" .. ld.DISP_PROMOTE .. "|r")

    local phint = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    phint:SetPoint("TOPLEFT", 16, -324)
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
            cb:SetPoint("TOPLEFT", 16 + col * 150, -350 - row * 26)
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
