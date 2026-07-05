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

-- ============================================================
-- Serialization + Base64 (profiles export/import) — same battle-tested
-- implementation as LootEnh.
-- ============================================================

-- Keys carried by a profile
BagsEnh_PROFILE_KEYS = {
    "scale", "columns", "iconSize", "spacing", "width", "height", "enabled", "showHidden",
    "itemOverrides", "customRules", "collapsed",
}

function BagsEnh_SerializeTable(t)
    local function ser(v)
        local vt = type(v)
        if vt == "string" then
            return string.format("%q", v)
        elseif vt == "number" then
            return tostring(v)
        elseif vt == "boolean" then
            return v and "true" or "false"
        elseif vt == "table" then
            local parts = {}
            local n = #v
            for i = 1, n do parts[#parts + 1] = ser(v[i]) end
            for k, val in pairs(v) do
                if type(k) == "number" and k >= 1 and k <= n and math.floor(k) == k then
                    -- array part, already handled
                else
                    local key
                    if type(k) == "string" then
                        key = "[" .. string.format("%q", k) .. "]"
                    else
                        key = "[" .. tostring(k) .. "]"
                    end
                    parts[#parts + 1] = key .. "=" .. ser(val)
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        return "nil"
    end
    return ser(t)
end

function BagsEnh_DeserializeTable(s)
    if type(s) ~= "string" or s == "" then return nil end
    local fn = loadstring("return " .. s)
    if not fn then return nil end
    setfenv(fn, {})
    local ok, result = pcall(fn)
    if not ok or type(result) ~= "table" then return nil end
    return result
end

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function BagsEnh_Base64Encode(data)
    local out = {}
    local len = #data
    for i = 1, len, 3 do
        local a = string.byte(data, i)
        local b = i + 1 <= len and string.byte(data, i + 1) or 0
        local c = i + 2 <= len and string.byte(data, i + 2) or 0
        local n = a * 65536 + b * 256 + c
        out[#out + 1] = string.sub(b64chars, math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
        out[#out + 1] = string.sub(b64chars, math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        out[#out + 1] = i + 1 <= len and string.sub(b64chars, math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "="
        out[#out + 1] = i + 2 <= len and string.sub(b64chars, n % 64 + 1, n % 64 + 1) or "="
    end
    return table.concat(out)
end

function BagsEnh_Base64Decode(data)
    if type(data) ~= "string" then return nil end
    data = data:gsub("[^A-Za-z0-9+/=]", "")
    local out = {}
    for i = 1, #data, 4 do
        local a, b, c, d =
            (string.find(b64chars, string.sub(data, i, i), 1, true) or 1) - 1,
            (string.find(b64chars, string.sub(data, i + 1, i + 1), 1, true) or 1) - 1,
            (string.find(b64chars, string.sub(data, i + 2, i + 2), 1, true) or 1) - 1,
            (string.find(b64chars, string.sub(data, i + 3, i + 3), 1, true) or 1) - 1
        local n = a * 262144 + b * 4096 + c * 64 + d
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if string.sub(data, i + 2, i + 2) ~= "=" then
            out[#out + 1] = string.char(math.floor(n / 256) % 256)
        end
        if string.sub(data, i + 3, i + 3) ~= "=" then
            out[#out + 1] = string.char(n % 256)
        end
    end
    return table.concat(out)
end
