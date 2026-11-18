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
--
-- Et elle s'efface devant un addon qui REMPLACE le sac du jeu : la
-- fenetre qu'on greffe n'est alors plus celle qu'on voit. Releve a
-- PLAYER_LOGIN, quand tous les addons sont charges (tweaks-forever fait
-- de meme, audit du 23/09).
local REMPLACANTS = {
    "Baganator", "Bagnon", "Bagnonium", "BetterBags", "ArkInventory",
    "AdiBags", "Combuctor", "Inventorian", "LiteBag", "Sorted", "cargBags_Nivaya",
}
local remplacant   -- nom de l'addon qui a pris le sac, nil sinon

local function VueActive()
    return BagsEnhDB ~= nil and BagsEnhDB.foreverVue ~= false and not remplacant
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
        -- items : le sous-groupe ENTIER, meme s'il deborde sur les rangees
        -- suivantes — c'est ce que son libelle vend ou depose.
        table.insert(rangees[rangeeDebut].etiquettes,
            { col = debut, texte = texte, largeur = besoin, items = g.items })
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
        racine:CreateDivider()
        racine:CreateRadio(ld.MENU_HIDE,
            function() return Actuelle() == "hidden" end,
            function() BagsEnh_SetItemOverride(itemID, "hidden") end)
        if Actuelle() then
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

-- ── Objets masques ─────────────────────────────────────────────────────
--
-- Ceux qu'on porte en permanence sans les consulter (pierre de foyer...).
-- Un bouton du jeu ne se cache PAS par Hide() : son script OnHide partirait
-- depuis notre code, et le marquerait. On le pose hors de l'ecran — SetPoint
-- seulement, comme tout le reste de la greffe, aucun script declenche.
local HORS_ECRAN = -100000

local bascule      -- notre ligne « Voir masques (N) » / « Replier les masques »

local function Bascule(x, y, texte)
    if not bascule then
        bascule = CreateFrame("Button", nil, calque)
        bascule:SetNormalFontObject("GameFontHighlightSmall")
        bascule:SetHighlightFontObject("GameFontNormalSmall")
        bascule:SetScript("OnClick", function()
            BagsEnhDB.showHidden = not BagsEnhDB.showHidden
            -- Replanifier est declaree plus bas : BagsEnh_MarkDirty y mene.
            BagsEnh_MarkDirty()
        end)
    end
    bascule:SetText(texte)
    bascule:SetSize(bascule:GetFontString():GetStringWidth() + 4, HEADER_H)
    bascule:GetFontString():SetPoint("LEFT")
    bascule:ClearAllPoints()
    bascule:SetPoint("TOPLEFT", sac, "TOPLEFT", x, -y)
    bascule:Show()
end

-- ── En-tetes de categorie : vendre ou deposer la section ───────────────
--
-- Des boutons A NOUS (enfants du calque) : le Ctrl + clic declenche
-- BagsEnh_SectionAction (Actions.lua), le meme moteur que sur 3.3.5 et Era,
-- avec ses garde-fous de vente. Les boutons d'objets du jeu n'y sont pour rien.
local entetesCat = {}
local nbEntetesCat = 0

-- Repliee ? Cle BagsEnhDB.collapsed, la meme que la fenetre BagsEnh.
local function Repliee(cat)
    return BagsEnhDB.collapsed and BagsEnhDB.collapsed[cat] and true or false
end

-- largeur : toute la rangee. L'icone +/- est celle que Forever pose sur
-- ses propres en-tetes repliables (Competences, Reputation :
-- camelot/skillsframe.lua), a droite de la ligne, comme chez lui.
-- repliable : false pour « Masques », qui a deja sa bascule.
local function EnteteCategorie(x, y, texte, cat, largeur, repliable)
    nbEntetesCat = nbEntetesCat + 1
    local bt = entetesCat[nbEntetesCat]
    if not bt then
        bt = CreateFrame("Button", nil, calque)
        bt:SetNormalFontObject("GameFontNormalSmall")
        bt.icone = bt:CreateTexture(nil, "ARTWORK")
        bt.icone:SetPoint("RIGHT", -2, 0)
        bt:SetScript("OnClick", function(self)
            if BagsEnh_ActionModifierDown() then
                -- Les cases libres n'ont rien a vendre ni a deposer.
                if self.cat ~= "free" then BagsEnh_SectionAction(self.cat) end
            elseif self.repliable then
                BagsEnhDB.collapsed = BagsEnhDB.collapsed or {}
                BagsEnhDB.collapsed[self.cat] = not Repliee(self.cat) or nil
                BagsEnh_MarkDirty()
            end
        end)
        bt:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self:GetText())
            if self.repliable then
                GameTooltip:AddLine(BagsEnh_L().FOREVER_HEADER_COLLAPSE, 1, 1, 1, true)
            end
            if self.cat ~= "free" then
                GameTooltip:AddLine(BagsEnh_L().FOREVER_HEADER_TIP, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        bt:SetScript("OnLeave", function() GameTooltip:Hide() end)
        entetesCat[nbEntetesCat] = bt
    end
    bt.cat = cat
    bt.repliable = repliable
    bt:SetText(texte)
    if repliable then
        bt.icone:SetAtlas(Repliee(cat) and "common-button-list-plus" or "common-button-list-minus",
            TextureKitConstants.UseAtlasSize)
        bt.icone:Show()
    else
        bt.icone:Hide()
    end
    local fs = bt:GetFontString()
    -- L'or des titres de section du jeu (NORMAL_FONT_COLOR), pas une couleur
    -- par categorie : la vue doit se lire comme une fenetre de Blizzard
    -- (principe de la suite Enh, Kevin 23/09). Remis a chaque passe, le
    -- bouton venant d'un pool.
    fs:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
    fs:ClearAllPoints()
    fs:SetPoint("LEFT")
    bt:SetSize(largeur, HEADER_H)
    bt:ClearAllPoints()
    bt:SetPoint("TOPLEFT", sac, "TOPLEFT", x, -y)
    bt:Show()
end

-- ── Libelles de sous-groupe : vendre ou deposer le sous-groupe ─────────
--
-- Meme geste que sur l'en-tete (Ctrl + clic), restreint aux objets poses
-- sous ce libelle. Sur 3.3.5 et Era, les sous-en-tetes le font deja
-- (Frames.lua, beAct.desc) ; ici le libelle n'etait qu'un texte.
--
-- On passe au moteur les CASES affichees (desc.only), relues sur les boutons
-- du jeu au moment du clic — voir SectionSlots dans Actions.lua.
local etiquettes = {}
local nbEtiquettes = 0

local function EtiquetteSousGroupe(x, y, texte, largeur, cat, items)
    nbEtiquettes = nbEtiquettes + 1
    local bt = etiquettes[nbEtiquettes]
    if not bt then
        bt = CreateFrame("Button", nil, calque)
        bt:SetNormalFontObject("GameFontNormalSmall")
        bt:SetScript("OnClick", function(self)
            if not BagsEnh_ActionModifierDown() then return end
            local only = {}
            for _, item in ipairs(self.items) do
                only[item.bouton:GetBagID() .. ":" .. item.bouton:GetID()] = true
            end
            BagsEnh_SectionAction(self.cat, { only = only })
        end)
        bt:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            -- Le libelle entier : il est coupe a la largeur de son sous-groupe.
            GameTooltip:SetText(self:GetText())
            GameTooltip:AddLine(BagsEnh_L().FOREVER_HEADER_TIP, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        bt:SetScript("OnLeave", function() GameTooltip:Hide() end)
        etiquettes[nbEtiquettes] = bt
    end
    bt.cat = cat
    bt.items = items
    bt:SetText(texte)
    local fs = bt:GetFontString()
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT")
    fs:SetWidth(largeur)
    bt:SetSize(largeur, SUBHEADER_H)
    bt:ClearAllPoints()
    bt:SetPoint("TOPLEFT", sac, "TOPLEFT", x, -y)
    bt:Show()
end

local function Disposer()
    nbTextes = 0
    nbEntetesCat = 0
    nbEtiquettes = 0
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
                table.insert(libres, { bouton = bouton, sac = bouton:GetBagID() })
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

    -- Les masques sortent du rendu general : ils ont leur place a eux,
    -- apres toutes les categories, et seulement si on demande a les voir.
    local masques = groupes.hidden or {}
    groupes.hidden = nil
    -- Un objet ecarte (masque, section repliee) sort de l'ecran.
    local function Ecarter(items)
        for _, item in ipairs(items) do
            item.bouton:ClearAllPoints()
            item.bouton:SetPoint("TOPLEFT", sac, "TOPLEFT", HORS_ECRAN, 0)
        end
    end
    local largeur = colonnes * pas - SPACING
    local voirMasques = BagsEnhDB.showHidden and true or false
    if not voirMasques then Ecarter(masques) end

    local y = TOP_Y
    for _, cat in ipairs(Ordre(groupes)) do
        local items = groupes[cat]
        EnteteCategorie(TOP_X, y, BagsEnh_CategoryLabel(cat) .. " (" .. #items .. ")", cat, largeur, true)
        y = y + HEADER_H
        local mode = BagsEnh_GroupingFor(cat)
        if Repliee(cat) then
            Ecarter(items)
        elseif mode then
            for _, rangee in ipairs(Enchainer(items, mode, colonnes, pas)) do
                -- Une rangee de continuation (sous-groupe trop long pour une
                -- ligne) n'a pas de libelle : elle ne paie pas sa bande.
                if #rangee.etiquettes > 0 then
                    for _, e in ipairs(rangee.etiquettes) do
                        EtiquetteSousGroupe(TOP_X + e.col * pas, y, e.texte, e.largeur * pas - 4, cat, e.items)
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
    if #masques > 0 then
        local ld = BagsEnh_L()
        Bascule(TOP_X, y, voirMasques and ld.BTN_HIDE_HIDDEN or ld.BTN_SHOW_HIDDEN:format(#masques))
        y = y + HEADER_H
        if voirMasques then
            EnteteCategorie(TOP_X, y, BagsEnh_CategoryLabel("hidden") .. " (" .. #masques .. ")", "hidden", largeur, false)
            y = y + HEADER_H
            table.sort(masques, BagsEnh_CmpMaterialFirst)
            y = Grille(masques, y)
        end
    elseif bascule then
        bascule:Hide()
    end
    -- Cases libres : celles d'un sac SPECIALISE (carquois, giberne, sac
    -- d'ames...) ne prennent que leur famille d'objets. Les compter avec les
    -- autres faisait croire a de la place qu'on n'a pas (Kevin, 23/09).
    -- Famille lue une fois par sac : 0 = sac ordinaire.
    local familles, generales, speciales, ordreSpeciaux = {}, {}, {}, {}
    for _, item in ipairs(libres) do
        local f = familles[item.sac]
        if f == nil then
            local _, fam = C_Container.GetContainerNumFreeSlots(item.sac)
            f = fam or 0
            familles[item.sac] = f
        end
        if f == 0 then
            table.insert(generales, item)
        else
            if not speciales[item.sac] then
                speciales[item.sac] = {}
                table.insert(ordreSpeciaux, item.sac)
            end
            table.insert(speciales[item.sac], item)
        end
    end
    -- Les cases libres se replient aussi — sacs specialises compris : c'est
    -- souvent le plus gros bloc de la fenetre.
    if #libres > 0 then
        EnteteCategorie(TOP_X, y, BagsEnh_L().SECTION_FREE .. " (" .. #generales .. ")", "free", largeur, true)
        y = y + HEADER_H
    end
    table.sort(ordreSpeciaux)
    if Repliee("free") then
        Ecarter(libres)
        ordreSpeciaux = {}
    else
        y = Grille(generales, y)
    end
    for _, sacID in ipairs(ordreSpeciaux) do
        local nom = C_Container.GetBagName(sacID) or "?"
        -- Un sac specialise est un sous-niveau des cases libres : gris des
        -- sous-titres, comme les materiaux et emplacements.
        Texte(TOP_X, y, BagsEnh_L().SECTION_FREE_SPECIAL:format(nom, #speciales[sacID]), nil, GRAY_FONT_COLOR:GetRGB())
        y = y + HEADER_H
        y = Grille(speciales[sacID], y)
    end

    for i = nbTextes + 1, #textes do textes[i]:Hide() end
    for i = nbEntetesCat + 1, #entetesCat do entetesCat[i]:Hide() end
    for i = nbEtiquettes + 1, #etiquettes do etiquettes[i]:Hide() end
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

-- Depot en banque sur Forever (appele par BagsEnh_SectionAction). Rend :
--   true            -> laisser l'objet (remboursable vers la banque de compte :
--                      le client demande confirmation, un depot groupe non)
--   false, bankType -> deposer, dans le type de banque actif — comme le fait
--                      le clic droit natif (ContainerFrame.lua:1602).
function BagsEnh_ForeverBankDeposit(bag, slot)
    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if BankUtil_IsAccountBankDepositRefundable and BankUtil_IsAccountBankDepositRefundable(loc) then
        return true
    end
    return false, BankFrame and BankFrame.GetActiveBankType and BankFrame:GetActiveBankType()
end

-- Tout ce qui change un classement (menu d'objet, panneaux, regles)
-- appelle BagsEnh_MarkDirty. Core.lua, qui la definit ailleurs, n'est pas
-- charge sur Forever : ici, marquer sale, c'est refaire la vue.
function BagsEnh_MarkDirty()
    Replanifier()
    -- Les listes des reglages (categories, regles, ordre) suivent aussi.
    if BagsEnh_ForeverOptionsRefresh then BagsEnh_ForeverOptionsRefresh() end
end

-- ── La categorie dans l'infobulle ───────────────────────────────────────
--
-- Une ligne « BagsEnh : Consommables / Nourriture » sous l'infobulle d'un
-- objet DU SAC : pourquoi il est range la, utile pour ecrire une regle.
-- C'est une ajout a l'infobulle de Blizzard, donc au choix du joueur
-- (Options > BagsEnh) : jamais, avec une touche, ou toujours. Defaut :
-- avec Maj, comme MyBags. Crochet officiel : TooltipDataProcessor.
local function ToucheInfobulle()
    local m = BagsEnhDB.tipCategory or "shift"
    if m == "always" then return true end
    if m == "shift" then return IsShiftKeyDown() end
    if m == "ctrl" then return IsControlKeyDown() end
    if m == "alt" then return IsAltKeyDown() end
    return false
end

local function LigneInfobulle(tooltip)
    if tooltip ~= GameTooltip or not VueActive() or not ToucheInfobulle() then return end
    local owner = tooltip:GetOwner()
    if not owner or owner:GetParent() ~= sac or not owner.GetBagID then return end
    local link = C_Container.GetContainerItemLink(owner:GetBagID(), owner:GetID())
    if not link then return end
    local cat, _, subCat = BagsEnh_Categorize(link)
    local texte = BagsEnh_CategoryLabel(cat)
    if subCat and subCat ~= "" then texte = texte .. " / " .. subCat end
    tooltip:AddLine(BagsEnh_L().FOREVER_TIP_LINE:format(texte), GRAY_FONT_COLOR:GetRGB())
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("BAG_CONTAINER_UPDATE")
f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
-- Contexte des actions de section : Core.lua le tient sur 3.3.5 et Era,
-- il n'est pas charge ici.
f:RegisterEvent("MERCHANT_SHOW")
f:RegisterEvent("MERCHANT_CLOSED")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("BANKFRAME_CLOSED")
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
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, LigneInfobulle)
        sac:HookScript("OnShow", Replanifier)
        EventRegistry:RegisterCallback("TokenFrame.OnTokenWatchChanged", Replanifier, f)

        -- Puis les reglages (Forever_Options.lua), isoles : s'ils echouent,
        -- on perd les reglages, jamais la vue. L'erreur est gardee pour
        -- /be sonde — le client refuse /run tant que les scripts ne sont
        -- pas autorises.
        local ok, err = pcall(BagsEnh_ForeverOptionsBuild)
        if not ok then table.insert(erreurs, tostring(err)) end

    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" then
        BagsEnh_SetMerchantOpen(event == "MERCHANT_SHOW")
    elseif event == "BANKFRAME_OPENED" or event == "BANKFRAME_CLOSED" then
        BagsEnh_SetBankOpen(event == "BANKFRAME_OPENED")
    elseif event == "PLAYER_LOGIN" then
        for _, nom in ipairs(REMPLACANTS) do
            if C_AddOns.IsAddOnLoaded(nom) then
                remplacant = nom
                print("|cff00ccffBagsEnh|r : " .. BagsEnh_L().FOREVER_REPLACED:format(nom))
                break
            end
        end
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
        BagsEnh_ForeverOptionsOpen()
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
