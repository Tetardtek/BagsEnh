-- Item quality colors (rarity 0-6)
BagsEnh_QUALITY_COLORS = {
    [0] = {0.62, 0.62, 0.62},
    [1] = {1.00, 1.00, 1.00},
    [2] = {0.12, 1.00, 0.00},
    [3] = {0.00, 0.44, 0.87},
    [4] = {0.64, 0.21, 0.93},
    [5] = {1.00, 0.50, 0.00},
    [6] = {0.90, 0.80, 0.50},
}

-- Thin colored frame around an icon (same look as LootEnh)
function BagsEnh_CreateIconBorder(f, icon, inset)
    inset = inset or 1
    local b = f:CreateTexture(nil, "BORDER")
    b:SetTexture("Interface\\Buttons\\WHITE8X8")
    b:SetPoint("TOPLEFT", icon, "TOPLEFT", -inset, inset)
    b:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", inset, -inset)
    b:Hide()
    return b
end

function BagsEnh_FormatGold(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = "|cffffd700" .. gold .. "g|r" end
    if silver > 0 then parts[#parts + 1] = "|cffc7c7cf" .. silver .. "s|r" end
    parts[#parts + 1] = "|cffeda55f" .. c .. "c|r"
    return table.concat(parts, " ")
end

function BagsEnh_ItemIDFromLink(link)
    if not link then return nil end
    local id = link:match("|Hitem:(%d+)")
    return id and tonumber(id) or nil
end
