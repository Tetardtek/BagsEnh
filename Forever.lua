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
-- (BagsEnh_Categorize, tri CmpMaterialFirst) : un seul moteur pour
-- les trois clients. La pose des boutons, et l'enchainement des
-- sous-groupes, sont propres a Forever.
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

-- Lu par les panneaux partages : sur Forever, pas de fenetre BagsEnh ni
-- de badge +, le sac est celui du jeu.
BagsEnh_FOREVER = true

-- Sections propres a Ascension (et les monnaies epinglees, qui vivent dans
-- la fenetre BagsEnh) : aucun objet ne peut y tomber ici. Lu par
-- BagsEnh_GetOrderableCategories, donc absent du panneau d'ordre ET du menu.
BagsEnh_ABSENT_CATEGORIES = { special = true, worldforged = true, mystic = true, raidmats = true }

local SPACING = 5              -- ITEM_SPACING_X/Y, locaux a containerframe.lua
local HEADER_H = 16            -- en-tete de categorie
local SUBHEADER_H = 14         -- sous-en-tete (materiau, emplacement)
local TOP_X, TOP_Y = 10, 65    -- l'ancre du jeu en mode manette, sous la recherche.
                               -- y compte vers le BAS.

local sac          -- ContainerFrameCombinedBags, la fenetre du jeu
local calque       -- notre frame, enfant du sac : porte les en-tetes
local textes = {}  -- en-tetes et sous-en-tetes, reutilises d'une passe a l'autre
local nbTextes = 0
local hauteur      -- derniere hauteur posee par la vue, nil hors vue

-- Active par defaut : installer BagsEnh sur Forever, c'est vouloir la vue.
-- Seul un « non » explicite l'eteint.
--
-- Et c'est aussi une necessite : depuis le 17/09 (build 69913), la beta
-- ECRIT les SavedVariables mais ne les RELIT plus — mesure le 23/09 sur
-- BagsEnh et sur MapEnh (temoin), defaut connu et remonte a Blizzard.
-- Sans ce defaut, la vue disparaitrait a chaque /reload.
local function VueActive()
    return BagsEnhDB ~= nil and BagsEnhDB.foreverVue ~= false
end

-- largeur : nil = libre (en-tete de categorie) ; sinon le texte est coupe
-- a cette largeur, pour qu'un libelle ne deborde pas sur le sous-groupe voisin.
local function Texte(x, y, contenu, largeur, r, g, b)
    nbTextes = nbTextes + 1
    local fs = textes[nbTextes]
    if not fs then
        fs = calque:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        textes[nbTextes] = fs
    end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", sac, "TOPLEFT", x, -y)
    fs:SetWidth(largeur or 0)
    fs:SetText(contenu)
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:Show()
end

local mesure       -- FontString cachee : largeur d'un libelle avant de le poser
local function LargeurTexte(contenu)
    if not mesure then
        mesure = calque:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mesure:Hide()
    end
    mesure:SetText(contenu)
    return mesure:GetStringWidth()
end

-- Un objet au format qu'attend le moteur de BagsEnh (CmpMaterialFirst,
-- CmpSlotFirst), plus le bouton du jeu qui le porte. nil = case vide.
local function Lire(bouton)
    local info = C_Container.GetContainerItemInfo(bouton:GetBagID(), bouton:GetID())
    if not info then return nil end
    local cat, _, subCat, equipLoc = BagsEnh_Categorize(info.hyperlink)
    -- Un objet range a la main (menu) sort de Categorize avant le calcul du
    -- sous-type : sans ce repli, il s'affichait sous « ? ».
    if not subCat then
        local _, _, sousType, emplacement = C_Item.GetItemInfoInstant(info.itemID)
        subCat = (sousType ~= "" and sousType) or nil
        equipLoc = equipLoc or emplacement
    end
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

-- Cle de sous-groupe. Un seul niveau ici, meme en « material_slot » : la
-- fenetre du jeu est etroite (10 colonnes), deux niveaux d'en-tetes y
-- coutaient une ligne par objet. Le second niveau survit dans le TRI
-- (CmpMaterialFirst range deja par emplacement dans chaque materiau).
local function CleSousGroupe(item, mode)
    if mode == "slot" then
        local e = item.equipLoc
        return (e and e ~= "" and (_G[e] or e)) or "?"
    end
    return item.subCat or "?"
end

-- Sous-groupes ENCHAINES : chacun demarre a la colonne suivante s'il tient
-- dans le reste de la rangee, son libelle en petit au-dessus ; on ne passe
-- a la rangee qu'une fois pleine. Remplace BagsEnh_LayoutGrouped, qui ouvre
-- une rangee par sous-groupe — lisible dans la fenetre large de BagsEnh,
-- 6 rangees pour 3 objets dans celle du jeu (capture du 23/09).
--
-- Un sous-groupe reserve au moins la largeur de son libelle : « Nourriture
-- & boissons » au-dessus d'un seul objet deborderait sur son voisin.
--
-- Rend la liste des rangees : { etiquettes = {...}, poses = {...} }.
local function Enchainer(items, mode, colonnes, pas)
    table.sort(items, mode == "slot" and BagsEnh_CmpSlotFirst or BagsEnh_CmpMaterialFirst)

    local sousGroupes = {}
    for _, item in ipairs(items) do
        local cle = CleSousGroupe(item, mode)
        local g = sousGroupes[#sousGroupes]
        if not g or g.cle ~= cle then
            g = { cle = cle, items = {} }
            sousGroupes[#sousGroupes + 1] = g
        end
        table.insert(g.items, item)
    end

    local rangees = { { etiquettes = {}, poses = {} } }
    local col = 0
    local function Suivante()
        rangees[#rangees + 1] = { etiquettes = {}, poses = {} }
        col = 0
    end

    for _, g in ipairs(sousGroupes) do
        local texte = "|cffaaaaaa" .. g.cle .. "|r"
        local pourLibelle = math.ceil((LargeurTexte(texte) + 6) / pas)
        local besoin = math.min(colonnes, math.max(math.min(#g.items, colonnes), pourLibelle))
        -- Un sous-groupe plus long qu'une rangee debordera de toute facon :
        -- il demarre la ou on en est, pourvu que son libelle y tienne.
        local long = #g.items > colonnes and pourLibelle <= colonnes - col
        if col > 0 and not long and col + besoin > colonnes then Suivante() end

        local debut, rangeeDebut = col, #rangees
        besoin = math.min(besoin, colonnes - debut)
        table.insert(rangees[rangeeDebut].etiquettes, { col = debut, texte = texte, largeur = besoin })
        for _, item in ipairs(g.items) do
            if col >= colonnes then Suivante() end
            table.insert(rangees[#rangees].poses, { item = item, col = col })
            col = col + 1
        end
        -- Reste sur sa rangee de depart : on reserve la largeur du libelle.
        if #rangees == rangeeDebut then
            col = math.max(col, debut + besoin)
        end
        if col >= colonnes then Suivante() end
    end
    if #rangees[#rangees].poses == 0 then rangees[#rangees] = nil end
    return rangees
end

-- ── Ranger un objet : Ctrl (ou Alt) + clic droit ───────────────────────
--
-- Le clic modifie natif d'un objet de sac (OnModifiedClick) ne reagit
-- qu'a Maj, et a Ctrl sur le bouton GAUCHE (essayer). Ctrl + clic droit
-- n'y fait rien. On passe apres lui par HookScript, qui n'ecrit aucune
-- cle sur le bouton du jeu.
--
-- Ctrl d'abord : sous KDE Plasma 5, Alt + clic droit est capte par le
-- gestionnaire de fenetres (redimensionner) et n'atteint jamais le jeu.
-- Alt reste accepte, c'est le geste du menu de BagsEnh ailleurs.

-- Hors du menu : les sections fixes que la vue ne gere pas (nouveaux,
-- caches, apparences). Les sections absentes de Forever sont deja
-- filtrees par BagsEnh_GetOrderableCategories.
local EXCLUES = { new = true, hidden = true, uncollected = true }

local function MenuObjet(bouton)
    local link = C_Container.GetContainerItemLink(bouton:GetBagID(), bouton:GetID())
    local itemID = link and BagsEnh_ItemIDFromLink(link)
    if not itemID then return end
    local ld = BagsEnh_L()
    local function Actuelle()
        return BagsEnhDB.itemOverrides and BagsEnhDB.itemOverrides[itemID]
    end
    MenuUtil.CreateContextMenu(bouton, function(_, racine)
        racine:CreateTitle((C_Item.GetItemInfo(link)) or "?")
        for _, cat in ipairs(BagsEnh_GetCategoryOrder()) do
            if not EXCLUES[cat] then
                racine:CreateRadio(ld.MENU_MOVE_TO:format(BagsEnh_CategoryLabel(cat)),
                    function(c) return Actuelle() == c end,
                    function(c) BagsEnh_SetItemOverride(itemID, c) end,
                    cat)
            end
        end
        if Actuelle() then
            racine:CreateDivider()
            racine:CreateButton(ld.MENU_RESET, function() BagsEnh_SetItemOverride(itemID, nil) end)
        end
    end)
end

local function SurClic(bouton, clic)
    if clic == "RightButton" and (IsControlKeyDown() or IsAltKeyDown()) and VueActive() then
        MenuObjet(bouton)
    end
end

-- Les boutons viennent d'un pool du jeu : on accroche chacun la premiere
-- fois qu'on le voit. Table a cles faibles, pour ne rien retenir.
local accroches = setmetatable({}, { __mode = "k" })

local function Disposer()
    nbTextes = 0
    if not VueActive() then
        calque:Hide()
        hauteur = nil
        return
    end

    local groupes, libres, taille = {}, {}, nil
    for _, bouton in sac:EnumerateValidItems() do
        -- L'iterateur du jeu ne s'arrete pas sur un bouton nil : il en rend
        -- tant que la fenetre n'a pas cree ses boutons (mesure le 23/09).
        if bouton then
            taille = taille or bouton:GetWidth()
            if not accroches[bouton] then
                bouton:HookScript("OnClick", SurClic)
                accroches[bouton] = true
            end
            local cat, item = Lire(bouton)
            if cat then
                groupes[cat] = groupes[cat] or {}
                table.insert(groupes[cat], item)
            else
                table.insert(libres, { bouton = bouton })
            end
        end
    end
    if not taille then return end

    local colonnes = sac:GetColumns()
    local pas = taille + SPACING

    local function Placer(item, col, y)
        item.bouton:ClearAllPoints()
        item.bouton:SetPoint("TOPLEFT", sac, "TOPLEFT", TOP_X + col * pas, -y)
    end
    local function Grille(items, y)
        local col = 0
        for _, item in ipairs(items) do
            Placer(item, col, y)
            col = col + 1
            if col >= colonnes then col = 0; y = y + pas end
        end
        if col > 0 then y = y + pas end
        return y
    end

    local y = TOP_Y
    for _, cat in ipairs(Ordre(groupes)) do
        local items = groupes[cat]
        local r, g, b = BagsEnh_CategoryColor(cat)
        Texte(TOP_X, y, BagsEnh_CategoryLabel(cat) .. " (" .. #items .. ")", nil, r, g, b)
        y = y + HEADER_H
        local mode = BagsEnh_GroupingFor(cat)
        if mode then
            for _, rangee in ipairs(Enchainer(items, mode, colonnes, pas)) do
                -- Une rangee de continuation (sous-groupe trop long pour une
                -- ligne) n'a pas de libelle : elle ne paie pas sa bande.
                if #rangee.etiquettes > 0 then
                    for _, e in ipairs(rangee.etiquettes) do
                        Texte(TOP_X + e.col * pas, y, e.texte, e.largeur * pas - 4)
                    end
                    y = y + SUBHEADER_H
                end
                for _, p in ipairs(rangee.poses) do
                    Placer(p.item, p.col, y)
                end
                y = y + pas
            end
        else
            table.sort(items, BagsEnh_CmpMaterialFirst)
            y = Grille(items, y)
        end
    end
    if #libres > 0 then
        Texte(TOP_X, y, BagsEnh_L().SECTION_FREE .. " (" .. #libres .. ")", nil, 0.6, 0.6, 0.6)
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

local erreurs = {}       -- echecs au chargement, lus par /be sonde
local auChargement = "?" -- etat de BagsEnhDB a ADDON_LOADED, lu par /be sonde
local auLogin = "?"      -- et a PLAYER_LOGIN

local function Sonde()
    print("|cff00ccffBagsEnh|r sonde Forever :")
    print("  GetItemInfo global :", GetItemInfo)
    print("  C_Item.GetItemInfo :", C_Item and C_Item.GetItemInfo)
    print("  C_Item.GetItemInfoInstant :", C_Item and C_Item.GetItemInfoInstant)
    print("  GetAuctionItemClasses :", GetAuctionItemClasses)
    print("  C_Container.GetContainerItemInfo :", C_Container and C_Container.GetContainerItemInfo)
    print("  combinedBags :", GetCVar("combinedBags"))
    print("  sac combine :", ContainerFrameCombinedBags)
    print("  vue active :", VueActive() and "oui" or "non")
    print("  sauvegarde a ADDON_LOADED :", auChargement)
    print("  sauvegarde a PLAYER_LOGIN :", auLogin)
    print("  erreurs au chargement :", #erreurs)
    for _, e in ipairs(erreurs) do print("    " .. e) end
end

-- Tout ce qui change un classement (menu d'objet, panneaux, regles)
-- appelle BagsEnh_MarkDirty. Core.lua, qui la definit ailleurs, n'est pas
-- charge sur Forever : ici, marquer sale, c'est refaire la vue.
function BagsEnh_MarkDirty()
    Replanifier()
end

local categorieRacine   -- rendue par Settings, pour /be options

local function PanneauRacine()
    local ld = BagsEnh_L()
    local P = CreateFrame("Frame", "BagsEnhForeverPanel", UIParent)
    P.name = "BagsEnh"

    local titre = P:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    titre:SetPoint("TOPLEFT", 16, -16)
    titre:SetText("BagsEnh")

    local case = CreateFrame("CheckButton", nil, P, "UICheckButtonTemplate")
    case:SetPoint("TOPLEFT", 12, -44)
    local libelle = P:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    libelle:SetPoint("LEFT", case, "RIGHT", 4, 0)
    libelle:SetText(ld.FOREVER_VIEW)
    case:SetScript("OnClick", function(self)
        BagsEnhDB.foreverVue = self:GetChecked() and true or false
        Replanifier()
    end)

    local aide = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    aide:SetPoint("TOPLEFT", 16, -84)
    aide:SetWidth(520)
    aide:SetJustifyH("LEFT")
    aide:SetText(ld.FOREVER_HINT)

    P:SetScript("OnShow", function() case:SetChecked(VueActive() and true or false) end)
    categorieRacine = BagsEnh_AddOptionsCategory(P)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("BAG_CONTAINER_UPDATE")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= "BagsEnh" then return end
        self:UnregisterEvent("ADDON_LOADED")
        -- Etat de la sauvegarde telle que le client la remet, AVANT que
        -- InitializeDB ne complete quoi que ce soit. Garde dans /be sonde
        -- pour voir le jour ou la beta relira ses SavedVariables : on
        -- lira alors autre chose que « nil, 0 cles ».
        local n = 0
        if type(BagsEnhDB) == "table" then for _ in pairs(BagsEnhDB) do n = n + 1 end end
        auChargement = type(BagsEnhDB) .. ", " .. n .. " cles, foreverVue=" ..
            tostring(type(BagsEnhDB) == "table" and BagsEnhDB.foreverVue)
        BagsEnh_InitializeDB()

        sac = ContainerFrameCombinedBags
        if not sac then
            print("|cff00ccffBagsEnh|r : sac combine introuvable, greffe inactive.")
            return
        end
        calque = CreateFrame("Frame", nil, sac)
        calque:SetAllPoints()
        calque:Hide()
        -- La vue D'ABORD : c'est la fonction de l'addon. Le 23/09, les
        -- panneaux crees avant elle ont interrompu ce gestionnaire, et la
        -- vue ne s'est jamais posee — sans message visible.
        sac:HookScript("OnShow", Replanifier)
        EventRegistry:RegisterCallback("TokenFrame.OnTokenWatchChanged", Replanifier, f)

        -- Puis les reglages, chacun isole : un panneau qui echoue coute ce
        -- panneau, jamais la vue. L'erreur est gardee pour /be sonde — le
        -- client refuse /run tant que les scripts ne sont pas autorises.
        -- La racine d'abord : les deux autres s'y rattachent par son nom.
        for _, creer in ipairs({ PanneauRacine, BagsEnh_CreateCategoriesPanel, BagsEnh_CreateOrderPanel }) do
            local ok, err = pcall(creer)
            if not ok then table.insert(erreurs, tostring(err)) end
        end

    elseif event == "PLAYER_LOGIN" then
        local n = 0
        if type(BagsEnhDB) == "table" then for _ in pairs(BagsEnhDB) do n = n + 1 end end
        auLogin = type(BagsEnhDB) .. ", " .. n .. " cles, foreverVue=" ..
            tostring(type(BagsEnhDB) == "table" and BagsEnhDB.foreverVue)
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
        BagsEnhDB.foreverVue = not VueActive()
        if BagsEnhDB.foreverVue then
            print("|cff00ccffBagsEnh|r : vue par categories |cff00ff00activee|r.")
            -- La greffe vit sur le sac UNIQUE : en sacs separes, elle n'a rien
            -- a reorganiser. On le dit plutot que de laisser croire a une panne.
            if GetCVar("combinedBags") ~= "1" then
                print("|cff00ccffBagsEnh|r : " .. BagsEnh_L().FOREVER_NEED_COMBINED)
            end
            Replanifier()
        else
            -- Retablir la grille native demanderait d'appeler
            -- UpdateItemLayout d'ici : interdit, voir l'en-tete.
            -- A la reouverture, Disposer masque nos en-tetes.
            print("|cff00ccffBagsEnh|r : vue par categories |cffff5555desactivee|r — referme et rouvre ton sac.")
        end
    elseif msg == "options" then
        if categorieRacine and Settings and Settings.OpenToCategory then
            Settings.OpenToCategory(categorieRacine:GetID())
        end
    elseif msg == "objets" then
        -- Classe et sous-classe telles que le client les declare, et la
        -- categorie qui en sort. Un objet par nom (piles regroupees).
        -- Parcourt les SACS, pas la fenetre : tant qu'elle n'a pas ete
        -- ouverte, ses boutons n'existent pas.
        local vus = {}
        print("|cff00ccffBagsEnh|r objets du sac : nom | classe.sous-classe | categorie")
        for sacID = 0, Constants.InventoryConstants.NumBagSlots do
            for case = 1, C_Container.GetContainerNumSlots(sacID) do
                local info = C_Container.GetContainerItemInfo(sacID, case)
                if info and not vus[info.itemID] then
                    vus[info.itemID] = true
                    local _, _, _, _, _, classe, sousClasse = C_Item.GetItemInfoInstant(info.itemID)
                    print(("  %s | %s.%s | %s"):format(info.hyperlink, tostring(classe),
                        tostring(sousClasse), tostring((BagsEnh_Categorize(info.hyperlink)))))
                end
            end
        end
    elseif msg == "sonde" then
        Sonde()
    else
        print("|cff00ccffBagsEnh|r (Forever) : /be vue — basculer la vue par categories · /be options — les reglages · /be sonde — relever l'API")
    end
end
