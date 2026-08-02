-- ============================================================
-- Version — identite de l'addon et declaration au hub.
--
-- 🔴 CE FICHIER NE VERIFIE PLUS RIEN. Le controle de version de la suite Enh
-- vit ENTIEREMENT dans AllEnh, et nulle part ailleurs.
--
-- Pourquoi ce retrait (02/08) : il y avait ici un protocole complet de
-- diffusion par messages d'addon. Deux defauts l'ont condamne.
--
--   1. Il ne portait qu'en GUILDE et en GROUPE. Un joueur sans guilde et hors
--      groupe n'etait jamais prevenu — c'est-a-dire precisement celui qu'on
--      voulait atteindre. Le canal partage du hub, lui, touche tout le monde.
--
--   2. Il dupliquait un comparateur de versions deja present dans le hub. Deux
--      implementations de la meme logique, vouees a diverger. Toutes les
--      variantes envisagees pour les garder identiques (fichier partage recopie
--      dans chaque depot, bibliotheque embarquee) revenaient a une SYNCHRONISATION
--      MANUELLE presentee comme une garantie — c'est-a-dire la recette du drift,
--      pas son remede.
--
-- Le recadrage qui tranche : verifier une version n'est pas une fonction de
-- BagsEnh, c'est une fonction de la SUITE. BagsEnh trie les sacs parfaitement
-- sans AllEnh, et c'est ca, « rester complet seul ». Savoir qu'une version plus
-- recente existe releve de la distribution — sans le hub, on regarde la page
-- GitHub, comme pour n'importe quel addon.
--
-- Ce qui couvre le cas autonome : le lien en tete du README, et /be version.
-- ============================================================

local GITHUB = "https://github.com/Tetardtek/BagsEnh"
local LATEST = GITHUB .. "/releases/latest"
local VERSION = (GetAddOnMetadata and GetAddOnMetadata("BagsEnh", "Version")) or "?"

-- Affichage manuel (/be version).
function BagsEnh_VersionInfo()
    BagsEnh_Print("v" .. VERSION .. " — " .. LATEST)
end

-- Declaration au hub, sans dependance : si AllEnh est absent, la ligne ne fait
-- rien. C'est lui qui decouvre les addons Enh presents, pas l'inverse — un
-- quatrieme addon dans deux ans sera couvert sans qu'on touche au hub.
local reg = CreateFrame("Frame")
reg:RegisterEvent("PLAYER_LOGIN")
reg:SetScript("OnEvent", function()
    if AllEnh_Register then
        AllEnh_Register("BagsEnh", { addon = "BagsEnh", url = LATEST })
    end
end)
