-- BagsEnh / Compat.lua
--
-- Couche de compatibilite entre le client 3.3.5 (Ascension / CoA) et le client
-- moderne (Classic Era 1.15+). Chargee EN PREMIER : tout le reste du code
-- l'utilise sans jamais savoir sur quel client il tourne.
--
-- Meme doctrine que LootEnh/Compat.lua : une couche FIGEE plutot que deux
-- branches divergentes. BagsEnh continue d'evoluer sur CoA ; ecrire deux fois
-- serait un drift structurel.
--
-- Principe de degradation : quand une API n'existe nulle part, on renonce a la
-- fonction, jamais a l'addon. Les sacs doivent s'afficher meme si un panneau
-- d'options ne s'enregistre pas.
--
-- Releve en jeu sur Classic Era 1.15.9 (04/08) :
--   C_Container ....................... table
--   GetContainerNumSlots .............. nil    <- les globales conteneurs sont MORTES
--   Settings .......................... table
--   InterfaceOptions_AddCategory ...... nil

BagsEnh_Compat = {}
local C = BagsEnh_Compat

C.modern = (Settings ~= nil and Settings.RegisterCanvasLayoutCategory ~= nil)

local CC = C_Container   -- nil sur 3.3.5

---------------------------------------------------------------------------
-- Conteneurs
---------------------------------------------------------------------------
-- L'essentiel du portage de BagsEnh tient ici : 57 appels, dont un seul cas
-- reellement delicat.
--
-- 🔴 GetContainerItemInfo n'a pas ete renomme, il a change de SIGNATURE.
--    3.3.5    : texture, count, locked, quality, readable, lootable, link,
--               isFiltered, noValue, itemID   (valeurs multiples)
--    moderne  : une TABLE unique, avec des champs nommes
--
-- Les 13 appels de BagsEnh utilisent tous la forme positionnelle
-- (`local _, count, locked = ...`). Plutot que de reecrire 13 sites d'appel, le
-- shim reconstruit l'ancienne signature depuis la table : le code metier n'a pas
-- une ligne a changer, et il reste lisible sur les deux clients.
--
-- ⚠️ Le retour nil quand la case est vide doit etre preserve tel quel :
--    plusieurs endroits font `if not BagsEnh_GetContainerItemInfo(b, s) then`
--    pour detecter une case libre. Renvoyer une table vide casserait ce test.

function BagsEnh_GetContainerItemInfo(bag, slot)
    if CC and CC.GetContainerItemInfo then
        local i = CC.GetContainerItemInfo(bag, slot)
        if not i then return nil end
        return i.iconFileID, i.stackCount, i.isLocked, i.quality, i.isReadable,
               i.hasLoot, i.hyperlink, i.isFiltered, i.hasNoValue, i.itemID
    end
    return GetContainerItemInfo(bag, slot)
end

function BagsEnh_GetContainerNumSlots(bag)
    if CC and CC.GetContainerNumSlots then return CC.GetContainerNumSlots(bag) end
    return GetContainerNumSlots(bag)
end

function BagsEnh_GetContainerItemLink(bag, slot)
    if CC and CC.GetContainerItemLink then return CC.GetContainerItemLink(bag, slot) end
    return GetContainerItemLink(bag, slot)
end


function BagsEnh_UseContainerItem(bag, slot, ...)
    if CC and CC.UseContainerItem then return CC.UseContainerItem(bag, slot, ...) end
    return UseContainerItem(bag, slot, ...)
end

function BagsEnh_PickupContainerItem(bag, slot)
    if CC and CC.PickupContainerItem then return CC.PickupContainerItem(bag, slot) end
    return PickupContainerItem(bag, slot)
end

function BagsEnh_SplitContainerItem(bag, slot, amount)
    if CC and CC.SplitContainerItem then return CC.SplitContainerItem(bag, slot, amount) end
    return SplitContainerItem(bag, slot, amount)
end

function BagsEnh_GetContainerNumFreeSlots(bag)
    if CC and CC.GetContainerNumFreeSlots then return CC.GetContainerNumFreeSlots(bag) end
    return GetContainerNumFreeSlots(bag)
end

function BagsEnh_ContainerIDToInventoryID(bag)
    if CC and CC.ContainerIDToInventoryID then return CC.ContainerIDToInventoryID(bag) end
    return ContainerIDToInventoryID(bag)
end

---------------------------------------------------------------------------
-- Boutons d'objet — nettoyage du gabarit moderne
---------------------------------------------------------------------------
-- `ContainerFrameItemButtonTemplate` a beaucoup grossi depuis 3.3.5 : il embarque
-- des textures et des animations qui n'existaient pas, et que BagsEnh n'eteint
-- donc jamais. Resultat observe sur Classic Era : tous les objets cernes de bleu,
-- y compris les communs — le halo « nouvel objet » de Blizzard, qui double celui
-- que BagsEnh dessine deja.
--
-- On ne parie pas sur LA texture coupable : on neutralise la classe entiere.
-- Chaque test est garde, donc l'appel ne fait rien sur 3.3.5 ou aucune de ces
-- surfaces n'existe.
--
-- 🔴 Ne touche PAS a ce que BagsEnh possede : `beBorder` (sa bordure de qualite)
-- et son propre halo restent maitres de l'affichage. On ne retire que ce que le
-- gabarit ajoute dans notre dos.

local MODERN_BUTTON_SURFACES = {
    "NewItemTexture",        -- halo bleu « nouvel objet » — le coupable observe
    "BattlepayItemTexture",
    "IconBorder",            -- bordure de qualite native, doublon de beBorder
    "IconOverlay",
    "IconOverlay2",
    "ItemContextOverlay",
    "SlotHighlightTexture",
    "ProfessionQualityOverlay",
    "flash",
}

local MODERN_BUTTON_ANIMS = {
    "newitemglowAnim",
    "flashAnim",
}

function BagsEnh_StripModernButton(btn)
    if not btn then return end

    for i = 1, table.getn(MODERN_BUTTON_SURFACES) do
        local t = btn[MODERN_BUTTON_SURFACES[i]]
        if t then
            if t.SetAlpha then t:SetAlpha(0) end
            if t.Hide then t:Hide() end
        end
    end

    -- Les animations rallument leur texture toute seule : les arreter ne suffit
    -- pas si elles peuvent redemarrer, d'ou l'alpha a zero ci-dessus en renfort.
    for i = 1, table.getn(MODERN_BUTTON_ANIMS) do
        local a = btn[MODERN_BUTTON_ANIMS[i]]
        if a and a.Stop then a:Stop() end
    end

    -- Le gabarit moderne expose parfois un raccourci qui rallume la bordure de
    -- qualite a chaque mise a jour. On le neutralise plutot que de courir apres.
    if btn.SetItemButtonQuality then
        btn.SetItemButtonQuality = function() end
    end
end

---------------------------------------------------------------------------
-- Conteneur d'un bouton d'objet
---------------------------------------------------------------------------
-- En 3.3.5, le gestionnaire natif d'infobulle lit le conteneur sur le PARENT du
-- bouton (`self:GetParent():GetID()`). C'est pourquoi BagsEnh place ses boutons
-- sous une frame cachée portant l'identifiant du sac.
--
-- Les gabarits modernes ne fonctionnent plus ainsi : le bouton porte lui-même
-- son conteneur, posé par `SetBagID`. Sans cet appel, le gestionnaire natif ne
-- sait pas quel objet décrire — et l'infobulle ne s'affiche pas.
--
-- Constaté sur les objets en banque. À poser au moment de l'ACQUISITION du
-- bouton, là où le conteneur est connu de façon certaine — pas au rendu, où il
-- ne l'est pas toujours (un emplacement vide n'a pas d'objet à interroger).
function BagsEnh_SetButtonBag(btn, bag)
    if btn and btn.SetBagID and bag then
        btn:SetBagID(bag)
    end
end

---------------------------------------------------------------------------
-- Trace d'infobulle — outil de diagnostic
---------------------------------------------------------------------------
-- Deux hypothèses successives sur « le texte s'affiche puis disparaît » se sont
-- révélées fausses (le rafraîchissement natif, puis l'écrasement asynchrone).
-- Plutôt qu'une troisième, on regarde QUI vide réellement l'infobulle.
--
-- `/be tipdebug` puis survoler l'objet fautif : chaque effacement s'annonce avec
-- la pile d'appel qui l'a provoqué. Le coupable se nomme lui-même.
--
-- Volontairement non désactivable et bavard : c'est un instrument, pas une
-- fonctionnalité. Il ne s'arme que sur demande explicite.

local tipDebugArmed = false

function BagsEnh_TipDebug()
    if tipDebugArmed then
        print("|cff66ccffBagsEnh|r trace déjà active.")
        return
    end
    tipDebugArmed = true

    if hooksecurefunc then
        hooksecurefunc(GameTooltip, "ClearLines", function()
            print("|cffff5555[tip] ClearLines|r\n" .. debugstack(2, 4, 0))
        end)
        -- `SetOwner` REMET L'INFOBULLE A ZERO : c'est lui le coupable quand le
        -- texte disparaît sans qu'aucun ClearLines n'apparaisse. On veut donc sa
        -- pile d'appel, pas seulement son propriétaire.
        hooksecurefunc(GameTooltip, "SetOwner", function(_, owner)
            local n = owner and owner.GetName and owner:GetName() or "?"
            print("|cffffcc00[tip] SetOwner|r " .. tostring(n) .. "\n" .. debugstack(2, 4, 0))
        end)
        if GameTooltip.SetHyperlink then
            hooksecurefunc(GameTooltip, "SetHyperlink", function(_, link)
                print("|cff60ff60[tip] SetHyperlink|r " .. tostring(link))
            end)
        end
    end

    print("|cff66ccffBagsEnh|r trace d'infobulle active — survole l'objet fautif.")
end

---------------------------------------------------------------------------
-- Menus contextuels
---------------------------------------------------------------------------
-- `EasyMenu` a ete retiree des clients recents. Ce n'etait qu'un raccourci de
-- vingt lignes au-dessus d'UIDropDownMenu — qui, lui, est toujours la : les
-- menus deroulants des panneaux d'options en dependent et fonctionnent.
--
-- On la reimplemente plutot que de viser MenuUtil, l'API moderne : UIDropDownMenu
-- existe sur les DEUX clients, donc un seul chemin de code au lieu de deux.
--
-- Symptome sans ce shim : « attempt to call a nil value » au clic sur le badge
-- de categorie d'un objet — la seule voie pour reclasser un objet a la main.

function BagsEnh_EasyMenu(menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay)
    if EasyMenu then
        return EasyMenu(menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay)
    end
    if not UIDropDownMenu_Initialize or not ToggleDropDownMenu then return end

    if displayMode == "MENU" then
        menuFrame.displayMode = displayMode
    end
    UIDropDownMenu_Initialize(menuFrame, function(_, level, list)
        list = list or menuList
        for i = 1, table.getn(list) do
            local entry = list[i]
            if entry and entry.text then
                entry.index = i
                UIDropDownMenu_AddButton(entry, level)
            end
        end
    end, displayMode, nil, menuList)
    ToggleDropDownMenu(1, nil, menuFrame, anchor, x, y, menuList, nil, autoHideDelay)
end

---------------------------------------------------------------------------
-- Backdrop
---------------------------------------------------------------------------
-- Depuis Shadowlands, SetBackdrop n'existe plus sur une frame ordinaire. On
-- applique le mixin a la volee plutot que de toucher chaque CreateFrame : un
-- seul point d'entree, et les SetBackdropColor qui suivent fonctionnent aussi.
--
--     BagsEnh_Backdrop(f):SetBackdrop({ ... })

function BagsEnh_Backdrop(frame)
    if frame and not frame.SetBackdrop and BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
        if frame.HasScript and frame:HasScript("OnSizeChanged") then
            frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
        end
    end
    return frame
end

---------------------------------------------------------------------------
-- Cases a cocher
---------------------------------------------------------------------------
-- Aucune API ne permet d'interroger la presence d'un gabarit : on tente.

local checkTemplate

function BagsEnh_CheckTemplate()
    if checkTemplate ~= nil then return checkTemplate end
    local candidates = {
        "InterfaceOptionsCheckButtonTemplate",
        "UICheckButtonTemplate",
        "OptionsBaseCheckButtonTemplate",
    }
    for i = 1, table.getn(candidates) do
        local ok, f = pcall(CreateFrame, "CheckButton", nil, UIParent, candidates[i])
        if ok and f then
            f:Hide()
            checkTemplate = candidates[i]
            return checkTemplate
        end
    end
    checkTemplate = false
    return checkTemplate
end

---------------------------------------------------------------------------
-- Panneaux d'options
---------------------------------------------------------------------------

local categories = {}
local rootCategory

-- 🔴 Amorçage du cycle OnShow sur client moderne.
--
-- Sur 3.3.5, InterfaceOptions_AddCategory masque le panneau : la premiere
-- ouverture declenche donc OnShow. Le systeme Settings moderne, lui, REPARENTE
-- le canvas sans l'avoir cache au prealable — OnShow ne part jamais, et tout
-- panneau qui se remplit a l'affichage reste vide. Symptome observe : la liste
-- des icones detectees annoncait « aucune » alors que la boite en affichait six.
--
-- Deux filets, parce qu'un panneau d'options muet est un defaut silencieux :
--   1. on cache le panneau une fois, ce qui retablit le cycle nominal ;
--   2. on rejoue les OnShow a l'ouverture de la fenetre de reglages, au cas ou
--      le client n'appellerait pas Show() sur le canvas.
--
-- Le second filet couvre aussi la navigation entre sous-categories, ou le canvas
-- reste affiche pendant qu'on change de page.

local registered = {}
local settingsHooked = false

local function HookSettingsRefresh()
    if settingsHooked or not SettingsPanel or not SettingsPanel.HookScript then return end
    settingsHooked = true
    SettingsPanel:HookScript("OnShow", function()
        for i = 1, table.getn(registered) do
            local p = registered[i]
            local h = p and p.GetScript and p:GetScript("OnShow")
            -- pcall : le rafraichissement d'un panneau ne doit pas empecher
            -- celui des suivants.
            if h then pcall(h, p) end
        end
    end)
end

function BagsEnh_AddOptionsCategory(panel)
    if not panel or not panel.name then return end

    if C.modern then
        local cat
        if panel.parent and categories[panel.parent] then
            cat = Settings.RegisterCanvasLayoutSubcategory(
                categories[panel.parent], panel, panel.name)
        else
            cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
            if Settings.RegisterAddOnCategory then
                Settings.RegisterAddOnCategory(cat)
            end
            rootCategory = rootCategory or cat
        end
        categories[panel.name] = cat
        registered[table.getn(registered) + 1] = panel
        panel:Hide()
        HookSettingsRefresh()
        return cat
    end

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        categories[panel.name] = panel
        rootCategory = rootCategory or panel
        return panel
    end
end


---------------------------------------------------------------------------
-- Metadonnees d'addon
---------------------------------------------------------------------------

function BagsEnh_GetAddOnMetadata(addon, field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addon, field)
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(addon, field)
    end
    return nil
end

