-- ============================================================
-- WoW Forever (nom de code "camelot") — vue par categories
-- greffee sur le sac unique DU JEU. Aucune frame remplacee.
--
-- Le jeu pose sa grille (UpdateItemLayout), puis on repositionne
-- SES boutons par section, sous nos en-tetes. Rien ne bouge dans
-- les sacs : c'est une vue. Clic, infobulle, glisser-deposer et
-- vente restent ceux du jeu, puisque les boutons sont les siens.
--
-- Le classement et les sous-sections sont ceux de BagsEnh
-- (BagsEnh_Categorize, BagsEnh_LayoutGrouped) : un seul moteur pour
-- les trois clients, seule la pose des boutons est propre a Forever.
--
-- Regles de la greffe :
--   - aucun champ ecrit dans une frame du jeu : SetPoint et
--     SetHeight seulement, sur des frames non protegees
--   - aucune methode du jeu qui ECRIT n'est appelee d'ici
--     (UpdateItemLayout, UpdateFrameSize...) : executee depuis un
--     addon, elle marquerait tout ce qu'elle touche. On passe apres
--     elles (HookScript, evenements), on ne les declenche jamais.
--   - aucune cle posee sur la fenetre du jeu, pas meme un crochet
-- ============================================================

local SPACING = 5              -- ITEM_SPACING_X/Y, locaux a containerframe.lua
local HEADER_H = 16            -- en-tete de categorie
local SUBHEADER_H = 14         -- sous-en-tete (materiau, emplacement)
local TOP_X, TOP_Y = 10, 65    -- l'ancre du jeu en mode manette, sous la recherche.
                               -- y compte vers le BAS, comme BagsEnh_LayoutGrouped.

local sac          -- ContainerFrameCombinedBags, la fenetre du jeu
local calque       -- notre frame, enfant du sac : porte les en-tetes
local textes = {}  -- en-tetes et sous-en-tetes, reutilises d'une passe a l'autre
local nbTextes = 0
local hauteur      -- derniere hauteur posee par la vue, nil hors vue

local function VueActive()
    return BagsEnhDB and BagsEnhDB.foreverVue
end

local function Texte(x, y, contenu, r, g, b)
    nbTextes = nbTextes + 1
    local fs = textes[nbTextes]
    if not fs then
        fs = calque:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetJustifyH("LEFT")
        textes[nbTextes] = fs
    end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", sac, "TOPLEFT", x, -y)
    fs:SetText(contenu)
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:Show()
end

-- Un objet au format qu'attend le moteur de BagsEnh (CmpMaterialFirst,
-- LayoutGrouped), plus le bouton du jeu qui le porte. nil = case vide.
local function Lire(bouton)
    local info = C_Container.GetContainerItemInfo(bouton:GetBagID(), bouton:GetID())
    if not info then return nil end
    local cat, _, subCat, equipLoc = BagsEnh_Categorize(info.hyperlink)
    return cat, { bouton = bouton, link = info.hyperlink, quality = info.quality,
                  subCat = subCat, equipLoc = equipLoc }
end

-- L'ordre de BagsEnh, puis ce qu'il ne connait pas d'avance (sous-types
-- promus, categories creees par l'utilisateur), trie pour rester stable.
local function Ordre(groupes)
    local ordre, vu, reste = {}, {}, {}
    for _, c in ipairs(BagsEnh_GetCategoryOrder()) do
        if groupes[c] then
            ordre[#ordre + 1] = c
            vu[c] = true
        end
    end
    for c in pairs(groupes) do
        if not vu[c] then reste[#reste + 1] = c end
    end
    table.sort(reste, function(a, b) return tostring(a) < tostring(b) end)
    for _, c in ipairs(reste) do ordre[#ordre + 1] = c end
    return ordre
end

local function Disposer()
    nbTextes = 0
    if not VueActive() then
        calque:Hide()
        hauteur = nil
        return
    end

    local groupes, libres, taille = {}, {}, nil
    for _, bouton in sac:EnumerateValidItems() do
        taille = taille or bouton:GetWidth()
        local cat, item = Lire(bouton)
        if cat then
            groupes[cat] = groupes[cat] or {}
            table.insert(groupes[cat], item)
        else
            table.insert(libres, { bouton = bouton })
        end
    end
    if not taille then return end

    local colonnes = sac:GetColumns()
    local pas = taille + SPACING
    -- Le meme moteur que les sacs de BagsEnh : seul le placement change,
    -- ici ce sont les boutons du jeu qu'on pose.
    local o = {
        perRow = colonnes, yStep = pas, subH = SUBHEADER_H,
        place = function(item, col, y)
            item.bouton:ClearAllPoints()
            item.bouton:SetPoint("TOPLEFT", sac, "TOPLEFT", TOP_X + col * pas, -y)
        end,
        header = function(text, indent, y)
            Texte(TOP_X + indent, y, text)
        end,
    }
    local function Grille(items, y)
        local col = 0
        for _, item in ipairs(items) do
            o.place(item, col, y)
            col = col + 1
            if col >= colonnes then col = 0; y = y + pas end
        end
        if col > 0 then y = y + pas end
        return y
    end

    local y = TOP_Y
    for _, cat in ipairs(Ordre(groupes)) do
        local items = groupes[cat]
        Texte(TOP_X, y, BagsEnh_CategoryLabel(cat) .. " (" .. #items .. ")", BagsEnh_CategoryColor(cat))
        y = y + HEADER_H
        local mode = BagsEnh_GroupingFor(cat)
        if mode then
            y = BagsEnh_LayoutGrouped(items, mode, o, y)
        else
            table.sort(items, BagsEnh_CmpMaterialFirst)
            y = Grille(items, y)
        end
    end
    if #libres > 0 then
        Texte(TOP_X, y, BagsEnh_L().SECTION_FREE .. " (" .. #libres .. ")", 0.6, 0.6, 0.6)
        y = y + HEADER_H
        y = Grille(libres, y)
    end

    for i = nbTextes + 1, #textes do textes[i]:Hide() end
    calque:Show()

    -- Meme calcul que CalculateHeight du jeu, avec nos en-tetes en plus.
    local contenu = (y - TOP_Y) - SPACING
    hauteur = contenu + sac:GetPaddingHeight() + sac:CalculateExtraHeight()
    sac:SetHeight(hauteur)
end

-- Toute remise en page du jeu (ouverture, cases ajoutees, monnaies
-- suivies) se termine par UpdateContainerFrameAnchors, APRES la taille
-- et la grille. On repasse derriere a la frame suivante : quel que soit
-- l'ordre des gestionnaires, le jeu a fini sa grille.
--
-- 23/09 : le premier essai accrochait les methodes du sac par
-- hooksecurefunc — ouvrir le sac plantait (ContainerFrame.lua:2778,
-- UpdateFrameSize nil). Cause NON isolee. HookScript et les evenements
-- n'ecrivent aucune cle sur la fenetre du jeu : c'est ce que la greffe
-- aurait du faire d'emblee.
local planifie = false

local function Replanifier()
    if planifie or not (sac and sac:IsShown()) then return end
    planifie = true
    C_Timer.After(0, function()
        planifie = false
        if sac:IsShown() then Disposer() end
    end)
end

local function Sonde()
    print("|cff00ccffBagsEnh|r sonde Forever :")
    print("  GetItemInfo global :", GetItemInfo)
    print("  C_Item.GetItemInfo :", C_Item and C_Item.GetItemInfo)
    print("  C_Item.GetItemInfoInstant :", C_Item and C_Item.GetItemInfoInstant)
    print("  GetAuctionItemClasses :", GetAuctionItemClasses)
    print("  C_Container.GetContainerItemInfo :", C_Container and C_Container.GetContainerItemInfo)
    print("  combinedBags :", GetCVar("combinedBags"))
    print("  sac combine :", ContainerFrameCombinedBags)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("BAG_CONTAINER_UPDATE")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= "BagsEnh" then return end
        self:UnregisterEvent("ADDON_LOADED")
        BagsEnh_InitializeDB()

        sac = ContainerFrameCombinedBags
        if not sac then
            print("|cff00ccffBagsEnh|r : sac combine introuvable, greffe inactive.")
            return
        end
        calque = CreateFrame("Frame", nil, sac)
        calque:SetAllPoints()
        calque:Hide()
        sac:HookScript("OnShow", Replanifier)
        EventRegistry:RegisterCallback("TokenFrame.OnTokenWatchChanged", Replanifier, f)

    else
        -- BAG_UPDATE_DELAYED : le contenu a change, le jeu ne refait pas
        -- sa grille pour si peu — c'est a nous de le suivre.
        -- BAG_CONTAINER_UPDATE : un sac pose ou retire, le jeu refait
        -- sa grille ; on repasse derriere.
        -- GET_ITEM_INFO_RECEIVED : un objet pas encore connu du client
        -- etait range dans Divers faute d'infos (non memorise) ; il
        -- rejoint sa categorie des qu'elles arrivent.
        Replanifier()
    end
end)

SLASH_BAGSENH1 = "/be"
SlashCmdList["BAGSENH"] = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "vue" then
        BagsEnhDB.foreverVue = not BagsEnhDB.foreverVue
        if BagsEnhDB.foreverVue then
            print("|cff00ccffBagsEnh|r : vue par categories |cff00ff00activee|r.")
            Replanifier()
        else
            -- Retablir la grille native demanderait d'appeler
            -- UpdateItemLayout d'ici : interdit, voir l'en-tete.
            -- A la reouverture, Disposer masque nos en-tetes.
            print("|cff00ccffBagsEnh|r : vue par categories |cffff5555desactivee|r — referme et rouvre ton sac.")
        end
    elseif msg == "sonde" then
        Sonde()
    else
        print("|cff00ccffBagsEnh|r (Forever) : /be vue — basculer la vue par categories · /be sonde — relever l'API")
    end
end
