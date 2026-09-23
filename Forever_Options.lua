-- ============================================================
-- WoW Forever — reglages dans Options > Add-ons, avec les CONTROLES DU JEU.
--
-- Principe de la suite Enh (Kevin, 23/09) : transparent, ou au pixel pres
-- dans la DA du jeu. Les panneaux de 3.3.5 et Era (Panel_Categories,
-- Panel_Order) sont des canevas dessines a la main : boutons, listes et
-- barres d'une autre epoque. Ici, tout est en « liste verticale » du
-- systeme Settings : cases, listes deroulantes, curseurs et boutons sont
-- ceux de Blizzard, alignes comme les siens (guide officiel :
-- Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua).
--
-- Les LISTES qui changent (tes categories, tes regles, l'ordre) :
--   la liste verticale est figee a l'enregistrement, et modifier sa table
--   d'initialiseurs depuis un addon serait ecrire dans une table du jeu.
--   On enregistre donc a l'avance un reservoir de lignes, chacune affichee
--   ou non par AddShownPredicate. Pour redessiner, on change la valeur
--   d'un reglage invisible (BAGSENH_REV) : le panneau repasse alors par
--   son propre chemin securise (OnSettingValueChanged -> RepairDisplay).
--   Deux reservoirs alternent a chaque revision : une ligne deja affichee
--   ne relit pas ses donnees, une ligne nouvellement affichee si.
-- ============================================================

local POOL = 30          -- lignes par liste ; au-dela, rien ne s'affiche

local rev = 0
local racine             -- categorie racine, pour /be options
local sources = {}       -- listes a rafraichir : { fill = fn, pools = {...} }

local function L() return BagsEnh_L() end

-- Rebatit le contenu de chaque liste, puis fait redessiner le panneau.
function BagsEnh_ForeverOptionsRefresh()
    for _, src in ipairs(sources) do
        local lignes = src.fill()
        src.lignes = lignes
        for _, pool in ipairs(src.pools) do
            for i, init in ipairs(pool) do
                local d = init:GetData()
                local l = lignes[i]
                d.name = l and l.name or ""
                d.buttonText = l and l.button or ""
            end
        end
    end
    rev = rev + 1
    if Settings.GetSetting("BAGSENH_REV") then
        Settings.SetValue("BAGSENH_REV", rev)
    end
end

-- Deux reservoirs de POOL lignes-boutons ; la ligne i du reservoir p est
-- visible si la revision a la parite p et qu'il existe une ligne i.
local function Liste(layout, fill)
    local src = { fill = fill, lignes = fill(), pools = {} }
    for p = 0, 1 do
        local pool = {}
        for i = 1, POOL do
            local init = CreateSettingsButtonInitializer("", "", function(bouton)
                local l = src.lignes[i]
                if l and l.click then l.click(bouton) end
            end, nil, false)
            local d = init:GetData()
            local l = src.lignes[i]
            d.name = l and l.name or ""
            d.buttonText = l and l.button or ""
            init:AddShownPredicate(function()
                return rev % 2 == p and src.lignes[i] ~= nil
            end)
            layout:AddInitializer(init)
            pool[i] = init
        end
        src.pools[p + 1] = pool
    end
    table.insert(sources, src)
end

local function Ligne(layout, name, button, click)
    layout:AddInitializer(CreateSettingsButtonInitializer(name, button, click, nil, false))
end

local function Titre(layout, name, tooltip)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(name, tooltip))
end

-- ── Fenetres de saisie : celles du jeu (StaticPopup) ────────────────────

local function Saisie(cle, texte, surOk)
    StaticPopupDialogs[cle] = {
        text = texte, button1 = OKAY, button2 = CANCEL,
        hasEditBox = true, editBoxWidth = 220,
        timeout = 0, whileDead = true, hideOnEscape = true,
        OnShow = function(dialog, data)
            local eb = dialog:GetEditBox()
            eb:SetText((data and data.valeur) or "")
            eb:HighlightText()
        end,
        OnAccept = function(dialog, data)
            local v = strtrim(dialog:GetEditBox():GetText() or "")
            if v ~= "" then surOk(v, data) end
        end,
        EditBoxOnEnterPressed = function(eb)
            local dialog = eb:GetParent()
            local v = strtrim(eb:GetText() or "")
            if v ~= "" then surOk(v, dialog.data) end
            dialog:Hide()
        end,
        EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
    }
end

-- Categories vers lesquelles on peut ranger (menu, regles).
local function Cibles()
    local t = {}
    for _, cat in ipairs(BagsEnh_GetCategoryOrder()) do
        if cat ~= "new" and cat ~= "hidden" and cat ~= "uncollected" then
            t[#t + 1] = cat
        end
    end
    return t
end

-- ── Construction ────────────────────────────────────────────────────────

local function Construire()
    local ld = L()
    local layout
    racine, layout = Settings.RegisterVerticalLayoutCategory("BagsEnh")

    -- Reglage invisible : sa seule raison d'etre est de faire redessiner.
    Settings.RegisterProxySetting(racine, "BAGSENH_REV", Settings.VarType.Number,
        "BagsEnh", 0, function() return rev end, function(v) rev = v end)

    -- Vue — active par defaut, seul un « non » explicite l'eteint.
    local vue = Settings.RegisterProxySetting(racine, "BAGSENH_VUE", Settings.VarType.Boolean,
        ld.FOREVER_VIEW, true,
        function() return BagsEnhDB.foreverVue ~= false end,
        function(v) BagsEnhDB.foreverVue = v; BagsEnh_MarkDirty() end)
    Settings.CreateCheckbox(racine, vue, ld.FOREVER_HINT)

    -- Vente et depot groupes : meme reglages que 3.3.5 et Era.
    Titre(layout, ld.FOREVER_SECTION_GROUP, ld.FOREVER_HEADER_TIP)
    local mod = Settings.RegisterProxySetting(racine, "BAGSENH_MOD", Settings.VarType.String,
        ld.OPT_ACTION_MOD, "ctrl",
        function() return BagsEnhDB.actionModifier or "ctrl" end,
        function(v) BagsEnhDB.actionModifier = v end)
    Settings.CreateDropdown(racine, mod, function()
        local c = Settings.CreateControlTextContainer()
        c:Add("ctrl", ld.MOD_CTRL)
        c:Add("alt", ld.MOD_ALT)
        c:Add("shift", ld.MOD_SHIFT)
        return c:GetData()
    end, ld.FOREVER_HEADER_TIP)

    local qual = Settings.RegisterProxySetting(racine, "BAGSENH_SELL_Q", Settings.VarType.Number,
        ld.OPT_SELL_MAX_QUALITY, 2,
        function() return BagsEnhDB.sellMaxQuality or 2 end,
        function(v) BagsEnhDB.sellMaxQuality = v end)
    Settings.CreateDropdown(racine, qual, function()
        local c = Settings.CreateControlTextContainer()
        for q = 0, 5 do
            local col = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
            local nom = _G["ITEM_QUALITY" .. q .. "_DESC"] or tostring(q)
            c:Add(q, col and col.hex .. nom .. "|r" or nom)
        end
        return c:GetData()
    end, ld.OPT_SELL_LIMITS_HINT)

    local ilvl = Settings.RegisterProxySetting(racine, "BAGSENH_SELL_ILVL", Settings.VarType.Number,
        ld.FOREVER_ILVL, 0,
        function() return BagsEnhDB.sellMaxILvl or 0 end,
        function(v) BagsEnhDB.sellMaxILvl = v end)
    local opts = Settings.CreateSliderOptions(0, 100, 1)
    opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v)
        return v == 0 and ld.FOREVER_NO_LIMIT or tostring(v)
    end)
    Settings.CreateSlider(racine, ilvl, opts, ld.OPT_SELL_LIMITS_HINT)

    -- ── Categories perso ───────────────────────────────────────────────
    local cats, lcats = Settings.RegisterVerticalLayoutSubcategory(racine, ld.CAT_PANEL_TITLE)

    Saisie("BAGSENH_F_NEW", ld.CAT_CREATE_LABEL, function(v)
        BagsEnh_AddUserCategory(v)
    end)
    Saisie("BAGSENH_F_RENAME", ld.CAT_RENAME_PROMPT, function(v, data)
        if data then BagsEnh_RenameUserCategory(data.cle, v) end
    end)
    Saisie("BAGSENH_F_RULE", ld.CAT_PATTERN, function(v)
        -- Le fragment d'abord, la categorie ensuite, dans le menu du jeu.
        MenuUtil.CreateContextMenu(UIParent, function(_, racineMenu)
            racineMenu:CreateTitle("« " .. v .. " »")
            for _, cat in ipairs(Cibles()) do
                racineMenu:CreateButton(BagsEnh_CategoryLabel(cat), function()
                    BagsEnh_AddCustomRule(v, cat)
                end)
            end
        end)
    end)

    Titre(lcats, ld.CAT_YOURS, ld.CAT_PANEL_HINT_FOREVER)
    Ligne(lcats, ld.FOREVER_NEW_CAT, ld.CAT_CREATE .. "…", function()
        StaticPopup_Show("BAGSENH_F_NEW")
    end)
    Liste(lcats, function()
        local t = {}
        for _, cle in ipairs(BagsEnh_UserCategoryKeys()) do
            t[#t + 1] = {
                name = BagsEnh_CategoryLabel(cle),
                button = ld.FOREVER_EDIT,
                click = function(bouton)
                    MenuUtil.CreateContextMenu(bouton, function(_, m)
                        m:CreateTitle(BagsEnh_CategoryLabel(cle))
                        m:CreateButton(ld.CAT_RENAME, function()
                            StaticPopup_Show("BAGSENH_F_RENAME", nil, nil,
                                { cle = cle, valeur = BagsEnh_CategoryLabel(cle) })
                        end)
                        m:CreateButton(ld.FOREVER_DELETE, function() BagsEnh_RemoveUserCategory(cle) end)
                    end)
                end,
            }
        end
        return t
    end)

    Titre(lcats, ld.CAT_RULES_SECTION, ld.CAT_RULES_HINT)
    Ligne(lcats, ld.FOREVER_NEW_RULE, ld.CAT_ADD .. "…", function()
        StaticPopup_Show("BAGSENH_F_RULE")
    end)
    Liste(lcats, function()
        local motifs = {}
        for m in pairs(BagsEnhDB.customRules or {}) do motifs[#motifs + 1] = m end
        table.sort(motifs)
        local t = {}
        for _, m in ipairs(motifs) do
            t[#t + 1] = {
                -- Pas de fleche : « → » n'existe pas dans la police du jeu
                -- (carre a l'ecran, 23/09).
                name = "« " .. m .. " » : " .. BagsEnh_CategoryLabel(BagsEnhDB.customRules[m]),
                button = ld.FOREVER_DELETE,
                click = function() BagsEnh_RemoveCustomRule(m) end,
            }
        end
        return t
    end)

    -- ── Ordre des sections ─────────────────────────────────────────────
    local ordre, lordre = Settings.RegisterVerticalLayoutSubcategory(racine, ld.ORDER_PANEL_TITLE)
    Ligne(lordre, ld.FOREVER_ALL_SECTIONS, ld.ORDER_RESET, function()
        BagsEnhDB.categoryOrder = nil
        BagsEnh_MarkDirty()
    end)
    Liste(lordre, function()
        local liste = BagsEnh_GetOrderableCategories()
        local t = {}
        for i, cat in ipairs(liste) do
            local function Vers(cible)
                local pos = i
                while pos ~= cible do
                    local pas = cible < pos and -1 or 1
                    BagsEnh_MoveCategory(cat, pas)
                    pos = pos + pas
                end
                BagsEnh_MarkDirty()
            end
            t[#t + 1] = {
                name = i .. ".  " .. BagsEnh_CategoryLabel(cat),
                button = ld.FOREVER_MOVE,
                click = function(bouton)
                    MenuUtil.CreateContextMenu(bouton, function(_, m)
                        m:CreateTitle(BagsEnh_CategoryLabel(cat))
                        if i > 1 then
                            m:CreateButton(ld.FOREVER_MOVE_UP, function() Vers(i - 1) end)
                            m:CreateButton(ld.FOREVER_MOVE_TOP, function() Vers(1) end)
                        end
                        if i < #liste then
                            m:CreateButton(ld.FOREVER_MOVE_DOWN, function() Vers(i + 1) end)
                            m:CreateButton(ld.FOREVER_MOVE_BOTTOM, function() Vers(#liste) end)
                        end
                    end)
                end,
            }
        end
        return t
    end)

    Settings.RegisterAddOnCategory(racine)
end

function BagsEnh_ForeverOptionsBuild()
    Construire()
end

function BagsEnh_ForeverOptionsOpen()
    if racine then Settings.OpenToCategory(racine:GetID()) end
end
