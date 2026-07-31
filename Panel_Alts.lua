-- ============================================================
-- Alts panel — Interface > AddOns > BagsEnh > Personnages en cache
-- Gère le cache multi-perso (/be alts) : liste les personnages connus et
-- permet de retirer ceux qu'on ne joue plus. Confirmation obligatoire.
-- ============================================================

local rows = {}

local function FmtLastSeen(key, ld)
    local ts = BagsEnh_CharLastSeen(key)
    if not ts then return ld.WH_NEVER end
    return date("%d/%m/%y", ts)
end

-- Confirmations
if not StaticPopupDialogs["BAGSENH_ALTS_DELETE"] then
    StaticPopupDialogs["BAGSENH_ALTS_DELETE"] = {
        text = "%s", button1 = DELETE, button2 = CANCEL,
        timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
        OnAccept = function(self)
            if not self.data then return end
            BagsEnh_DeleteCachedChar(self.data)
            BagsEnh_Print(
                BagsEnh_L().WH_DELETED:format(BagsEnh_CharColorName(self.data)))
            local P = _G.BagsEnhAltsPanel
            if P and P.Rebuild then P.Rebuild() end
            if BagsEnh_RefreshWarehouses then BagsEnh_RefreshWarehouses() end
        end,
    }
end
if not StaticPopupDialogs["BAGSENH_ALTS_CLEARALL"] then
    StaticPopupDialogs["BAGSENH_ALTS_CLEARALL"] = {
        text = "%s", button1 = DELETE, button2 = CANCEL,
        timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
        OnAccept = function()
            BagsEnh_ClearCache()
            local P = _G.BagsEnhAltsPanel
            if P and P.Rebuild then P.Rebuild() end
            if BagsEnh_RefreshWarehouses then BagsEnh_RefreshWarehouses() end
        end,
    }
end

function BagsEnh_CreateAltsPanel()
    local ld = BagsEnh_L()
    local P = CreateFrame("Frame", "BagsEnhAltsPanel", UIParent)
    P.name = ld.WH_ALTS_SECTION
    P.parent = "BagsEnh"

    local title = P:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BagsEnh — " .. ld.WH_ALTS_SECTION)

    local hint = P:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -42)
    hint:SetPoint("RIGHT", P, "RIGHT", -20, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(ld.WH_ALTS_HINT)

    local scroll = CreateFrame("ScrollFrame", "BagsEnhAltsScroll", P, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -74)
    scroll:SetPoint("BOTTOMRIGHT", -34, 56)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    local function AcquireRow(i)
        local r = rows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, content)
        r:SetSize(540, 22)
        local bg = r:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(r); bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetVertexColor(1, 1, 1, (i % 2 == 0) and 0.03 or 0.0)
        r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.name:SetPoint("LEFT", 6, 0)
        r.del = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
        r.del:SetSize(74, 18)
        r.del:SetPoint("RIGHT", -2, 0)
        r.del:SetText(ld.WH_DELETE)
        r.seen = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        r.seen:SetPoint("RIGHT", r.del, "LEFT", -10, 0)
        rows[i] = r
        return r
    end

    local function Rebuild()
        for _, r in ipairs(rows) do r:Hide() end
        local chars = BagsEnh_CachedChars()
        local y = 0
        for i, key in ipairs(chars) do
            local r = AcquireRow(i)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:Show()
            r.key = key
            r.name:SetText(BagsEnh_CharColorName(key))
            r.seen:SetText(FmtLastSeen(key, ld))
            r.del:SetScript("OnClick", function()
                local dlg = StaticPopup_Show("BAGSENH_ALTS_DELETE",
                    ld.WH_DELETE_CONFIRM:format(BagsEnh_CharColorName(key)))
                if dlg then dlg.data = key end
            end)
            y = y + 24
        end
        content:SetHeight(math.max(y, 1))
    end
    P.Rebuild = Rebuild

    local clearAll = CreateFrame("Button", nil, P, "UIPanelButtonTemplate")
    clearAll:SetSize(150, 22)
    clearAll:SetPoint("BOTTOMLEFT", 16, 18)
    clearAll:SetText(ld.WH_CLEAR_ALL)
    clearAll:SetScript("OnClick", function()
        StaticPopup_Show("BAGSENH_ALTS_CLEARALL", ld.WH_CLEAR_ALL_CONFIRM)
    end)

    P:SetScript("OnShow", Rebuild)
    InterfaceOptions_AddCategory(P)
end
