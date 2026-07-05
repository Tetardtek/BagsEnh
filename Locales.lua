BagsEnh_Locales = {
    ["enUS"] = {
        TITLE = "BagsEnh",
        SLOTS = "%d/%d slots",
        SORT = "Sort",
        TOGGLE_HINT = "|cff00ccffBagsEnh:|r unified view %s. /be toggle to switch.",
        STATE_ON = "enabled",
        STATE_OFF = "disabled",
        -- Categories
        CAT_NEW = "New",
        CAT_WORLDFORGED = "Worldforged",
        CAT_MYSTIC = "Mystic Scrolls",
        CAT_RAIDMATS = "Raid Materials",
        CAT_EQUIPMENT = "Equipment",
        CAT_CONSUMABLES = "Consumables",
        CAT_GEMS = "Gems",
        CAT_PROFESSION = "Profession & Trade",
        CAT_QUEST = "Quest",
        CAT_JUNK = "Junk",
        CAT_MISC = "Miscellaneous",
    },
    ["frFR"] = {
        TITLE = "BagsEnh",
        SLOTS = "%d/%d emplacements",
        SORT = "Ranger",
        TOGGLE_HINT = "|cff00ccffBagsEnh:|r vue unifiée %s. /be toggle pour changer.",
        STATE_ON = "activée",
        STATE_OFF = "désactivée",
        -- Categories
        CAT_NEW = "Nouveau",
        CAT_WORLDFORGED = "Worldforged",
        CAT_MYSTIC = "Parchemins mystiques",
        CAT_RAIDMATS = "Matériaux de raid",
        CAT_EQUIPMENT = "Équipement",
        CAT_CONSUMABLES = "Consommables",
        CAT_GEMS = "Gemmes",
        CAT_PROFESSION = "Métiers et commerce",
        CAT_QUEST = "Quête",
        CAT_JUNK = "Camelote",
        CAT_MISC = "Divers",
    },
}

function BagsEnh_L()
    local lang = (BagsEnhDB and BagsEnhDB.lang) or "enUS"
    return BagsEnh_Locales[lang] or BagsEnh_Locales["enUS"]
end
