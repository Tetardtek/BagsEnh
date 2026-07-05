# BagsEnh — Document de cadrage

> Série **Enh** — addons WoW 3.3.0 (Ascension) qui améliorent l'UI sans dépendance externe.
> Frère de [LootEnh](https://github.com/Tetardtek/LootEnh). Rédigé le 2026-07-05, avant la première ligne de code.

---

## Vision

Un gestionnaire de sacs **pratique dès l'installation** : une vue unifiée qui regroupe
les items par catégorie, une recherche instantanée, et un bouton qui range
physiquement les sacs. Pas un clone d'AdiBags — un outil taillé pour Ascension
(Worldforged, Mystic Scrolls, matos de raid) qui dialogue avec LootEnh.

**Ce que BagsEnh n'est pas** : un bank manager (v2+), un vendeur automatique,
un addon de stats d'inventaire.

---

## ADN série Enh (non négociable)

| Principe | Application |
|----------|-------------|
| Zéro dépendance | API 3.3.0 pure, pas d'Ace3, pas de libs embarquées |
| Profils | Save/Load/Export/Import Base64, auto-load par personnage |
| Localisation | enUS + frFR dès la v1 |
| Options natives | Panel Interface > AddOns > BagsEnh, mêmes helpers que LootEnh |
| Ascension-aware | Catégories et règles pensées pour le serveur, pas génériques |
| Inter-Enh | Expose et consomme des signaux simples entre addons de la série |

---

## Décisions de design (actées 2026-07-05)

### D1 — Vue : unifiée par défaut, toggle retour Blizzard
- **Mode BagsEnh (défaut)** : une fenêtre unique remplace les sacs, sections par
  catégorie avec en-têtes repliables, compteur de slots global, barre de recherche.
- **Mode Blizzard (toggle)** : les fenêtres de sacs d'origine, intactes. Seul ajout :
  le bouton « Ranger » (tri physique) injecté sur le backpack.
- Le toggle est une option du panel + commande `/be toggle`. Hook de
  `OpenAllBags`/`ToggleBackpack`/`ToggleBag` quand le mode BagsEnh est actif.

### D2 — Tri : virtuel (affichage) + physique (bouton)
- **Virtuel** : la vue unifiée regroupe par catégorie en continu. Les items ne
  bougent jamais dans les vrais sacs. Zéro risque, zéro coût serveur.
- **Physique** : bouton « Ranger » qui réorganise réellement les items
  (équipement ensemble, consos ensemble, gris en fin de sac). Implémentation
  3.3.5 : boucle `PickupContainerItem` throttlée sur `OnUpdate`, gestion des
  slots verrouillés (`ITEM_LOCK_CHANGED`), annulation si combat.
- Le tri physique sert le mode Blizzard et la banque (v2).

### D3 — Catégories : prédéfinies + règles custom
- **Prédéfinies (auto, par priorité croissante)** :
  1. `Divers` (fallback)
  2. Type d'objet natif : `Équipement` / `Consommables` / `Métiers & Récolte` / `Gemmes` / `Quête`
  3. Qualité : `Gris (à vendre)`
  4. Ascension : `Worldforged`, `Mystic Scrolls`, `Matériaux de raid`
     (réutilise la taxonomie auto-roll de LootEnh : patterns de noms + itemIDs connus)
- **Custom (user)** : règles nom/pattern → catégorie perso, shift-clic pour
  auto-remplir (même UX que Custom Rules de LootEnh). Priorité absolue.
- Moteur : `Categorize(bag, slot) → categoryKey`, résolution
  custom > Ascension > qualité > type natif > fallback. Cache par itemID,
  invalidé sur changement de règles.

---

## Architecture (calquée sur LootEnh)

```
BagsEnh.toc          SavedVariables: BagsEnhDB
Locales.lua          enUS + frFR
Defaults.lua         DB + InitializeDB (deep copy des défauts — leçon LootEnh)
Utils.lua            helpers partagés (DeepCopy, Base64, quality colors)
Categories.lua       moteur de catégorisation + taxonomie Ascension
Layout.lua           calcul des sections, tri virtuel, recherche
Frames.lua           fenêtre unifiée, item buttons (pool), en-têtes
SortEngine.lua       tri physique (state machine OnUpdate + locks)
Hooks.lua            OpenAllBags/ToggleBag + toggle Blizzard
Profiles.lua         profils (copie adaptée de LootEnh)
Panel_Main.lua       options générales + toggle vue
Panel_Categories.lua règles custom
Panel_Profiles.lua   profils
Core.lua             events + wiring (chargé en dernier)
```

**Events clés** : `BAG_UPDATE` (refresh différé/coalescé — jamais un refresh par
event brut), `ITEM_LOCK_CHANGED` (tri physique), `PLAYER_MONEY` (footer or),
`BAG_UPDATE_COOLDOWN` (cooldowns visibles).

**Perf** : pool de boutons d'items réutilisés (jamais recréés), refresh coalescé
sur un timer 0.1s, cache de catégorisation par itemID. Un sac de 120 slots doit
rester fluide sur le client 3.3.

---

## Pont inter-Enh (LootEnh ↔ BagsEnh)

Convention série légère, sans lib de communication :

```lua
-- Côté émetteur (LootEnh, déjà en place : il voit chaque loot)
if BagsEnh_OnNewLoot then BagsEnh_OnNewLoot(itemLink, count) end

-- Côté BagsEnh
function BagsEnh_OnNewLoot(link, count)
    -- marque l'item « nouveau » → badge + surlignage dans la vue unifiée
end
```

- Chaque addon fonctionne à 100 % sans l'autre (check `if fn then`).
- v1 : badge « nouveau » sur les items fraîchement lootés, section `Nouveau`
  optionnelle en tête de fenêtre.

---

## Phasage — pas de bricolage

### v1.0 — MVP utile (cible : jouable au quotidien)
- [ ] Vue unifiée : sections par catégories prédéfinies, en-têtes repliables
- [ ] Recherche instantanée (filtre en tapant, les autres items s'assombrissent)
- [ ] Compteur slots + or en footer
- [ ] Tri physique « Ranger » (bouton vue unifiée + backpack Blizzard)
- [ ] Toggle vue BagsEnh / Blizzard
- [ ] Tooltips, clic droit use/équip, shift-clic link — parité totale avec les sacs natifs
- [ ] Options minimales : échelle, colonnes, toggle, catégories on/off

### v1.1 — Règles custom + profils
- [ ] Panel Custom Categories (patterns nom, shift-clic)
- [ ] Profils Base64 complets
- [ ] Pont LootEnh : badge « nouveau »

### v2 — plus tard, si l'usage le réclame
- Banque (même vue unifiée)
- Tri physique configurable (ordre des catégories)
- Recherche par type/qualité (`q:épique`, `t:gemme`)
- Autres signaux inter-Enh

---

## Risques & garde-fous

| Risque | Garde-fou |
|--------|-----------|
| Tri physique = déplacements réels → item « perdu » perçu | State machine défensive : jamais 2 pickups simultanés, abort en combat, log des swaps en debug |
| Remplacer les sacs = invasif (keybinds, autres addons) | Toggle Blizzard toujours accessible, hooks réversibles, pas de remplacement des frames natives (on les cache, on ne les détruit pas) |
| Taxonomie Ascension mouvante (nouveau serveur, 21 classes) | Taxonomie isolée dans `Categories.lua`, données séparées de la logique |
| Perf BAG_UPDATE en rafale (loot AoE, courrier) | Coalescing 0.1s systématique dès la v1 |

---

## Questions ouvertes (à trancher en route)

- Nom des catégories FR/EN définitif (v1)
- Position/skin de la fenêtre : backdrop LootEnh-like ou style plus moderne ?
  (candidat naturel pour partager le futur theming v1.1 de LootEnh)
- Le bouton « Ranger » vide-t-il aussi les gris chez le marchand ? (non en v1 — pas un auto-vendeur, à débattre)
