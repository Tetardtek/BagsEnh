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

-- Colored OUTLINE around an icon (4 thin OVERLAY textures — never
-- covers the icon, unlike a filled backdrop). Returns an object with
-- Show / Hide / SetVertexColor.
function BagsEnh_CreateIconBorder(f, icon, thickness)
    thickness = thickness or 2
    local sides = {}
    for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
        local tex = f:CreateTexture(nil, "OVERLAY")
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        if side == "TOP" then
            tex:SetHeight(thickness)
            tex:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
            tex:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
        elseif side == "BOTTOM" then
            tex:SetHeight(thickness)
            tex:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
            tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        elseif side == "LEFT" then
            tex:SetWidth(thickness)
            tex:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
            tex:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
        else
            tex:SetWidth(thickness)
            tex:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
            tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        end
        tex:Hide()
        sides[#sides + 1] = tex
    end
    local border = {}
    function border:Show()
        for _, t in ipairs(sides) do t:Show() end
    end
    function border:Hide()
        for _, t in ipairs(sides) do t:Hide() end
    end
    function border:SetVertexColor(r, g, b, a)
        for _, t in ipairs(sides) do t:SetVertexColor(r, g, b, a or 1) end
    end
    return border
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
