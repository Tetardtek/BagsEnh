-- ============================================================
-- Profiles — save / load / delete / export / import (Base64),
-- with per-character auto-load. Mirrors LootEnh's profile system.
-- A profile snapshots the UI settings + item overrides + custom rules.
-- ============================================================

function BagsEnh_GetCharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

function BagsEnh_SaveProfile(name)
    if not name or name == "" then return false end
    BagsEnhDB.profiles = BagsEnhDB.profiles or {}
    local data = {}
    for _, k in ipairs(BagsEnh_PROFILE_KEYS) do
        data[k] = BagsEnh_DeepCopy(BagsEnhDB[k])
    end
    BagsEnhDB.profiles[name] = data
    return true
end

function BagsEnh_LoadProfile(name)
    local data = BagsEnhDB.profiles and BagsEnhDB.profiles[name]
    if not data then return false end
    for _, k in ipairs(BagsEnh_PROFILE_KEYS) do
        if data[k] ~= nil then
            BagsEnhDB[k] = BagsEnh_DeepCopy(data[k])
        end
    end
    -- Remember char → profile
    local charKey = BagsEnh_GetCharKey()
    BagsEnhDB.charProfiles = BagsEnhDB.charProfiles or {}
    BagsEnhDB.charProfiles[charKey] = name

    BagsEnh_InvalidateCategoryCache()
    if BagsEnh_ApplySettings then BagsEnh_ApplySettings() end
    if BagsEnh_MarkDirty then BagsEnh_MarkDirty() end
    return true
end

function BagsEnh_DeleteProfile(name)
    if BagsEnhDB.profiles then BagsEnhDB.profiles[name] = nil end
    if BagsEnhDB.charProfiles then
        for char, prof in pairs(BagsEnhDB.charProfiles) do
            if prof == name then BagsEnhDB.charProfiles[char] = nil end
        end
    end
end

function BagsEnh_ExportProfile(name)
    local data = BagsEnhDB.profiles and BagsEnhDB.profiles[name]
    if not data then return nil end
    return "BE1:" .. BagsEnh_Base64Encode(BagsEnh_SerializeTable(data))
end

function BagsEnh_ImportProfile(str, name)
    if type(str) ~= "string" then return false end
    local payload = str:match("^BE1:(.+)$") or str
    local decoded = BagsEnh_Base64Decode(payload)
    if not decoded then return false end
    local data = BagsEnh_DeserializeTable(decoded)
    if not data then return false end
    BagsEnhDB.profiles = BagsEnhDB.profiles or {}
    BagsEnhDB.profiles[name] = data
    return true
end

function BagsEnh_ListProfiles()
    local names = {}
    if BagsEnhDB.profiles then
        for n in pairs(BagsEnhDB.profiles) do names[#names + 1] = n end
    end
    table.sort(names)
    return names
end

function BagsEnh_AutoLoadProfile()
    local charKey = BagsEnh_GetCharKey()
    local prof = BagsEnhDB.charProfiles and BagsEnhDB.charProfiles[charKey]
    if prof and BagsEnhDB.profiles and BagsEnhDB.profiles[prof] then
        BagsEnh_LoadProfile(prof)
    end
end
