local defaults = {
    lang = "enUS",
    enabled = true,      -- unified view replaces default bags
    scale = 1.0,
    columns = 12,
    posX = 0,
    posY = 0,
    collapsed = {},      -- [categoryKey] = true when section is collapsed
    customRules = {},    -- name pattern -> category key (panel UI, v1.1)
    itemOverrides = {},  -- [itemID] = categoryKey | "hidden" (badge menu)
    showHidden = false,  -- reveal the "hidden" section
    profiles = {},       -- [name] = settings snapshot
    charProfiles = {},   -- [char-realm] = profile name (auto-load)
}

function BagsEnh_DeepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = BagsEnh_DeepCopy(v)
    end
    return copy
end

function BagsEnh_InitializeDB()
    BagsEnhDB = BagsEnhDB or {}
    for k, v in pairs(defaults) do
        if BagsEnhDB[k] == nil then
            -- Deep copy: never hand the defaults table itself to the DB
            BagsEnhDB[k] = BagsEnh_DeepCopy(v)
        elseif type(v) == "table" then
            for sk, sv in pairs(v) do
                if BagsEnhDB[k][sk] == nil then
                    BagsEnhDB[k][sk] = BagsEnh_DeepCopy(sv)
                end
            end
        end
    end
end
