-- ============================================================
-- Bag opening hooks — reversible. When the unified view is on,
-- the default bag toggles route to BagsEnh; when off, everything
-- behaves like stock Blizzard (originals are kept, never destroyed).
-- ============================================================

local orig = {}

local function UnifiedOn()
    return BagsEnhDB and BagsEnhDB.enabled
end

function BagsEnh_InstallHooks()
    if orig.ToggleBackpack then return end -- already installed

    orig.ToggleBackpack = ToggleBackpack
    orig.ToggleBag = ToggleBag
    orig.OpenAllBags = OpenAllBags
    orig.CloseAllBags = CloseAllBags
    orig.OpenBackpack = OpenBackpack
    orig.CloseBackpack = CloseBackpack

    ToggleBackpack = function(...)
        if UnifiedOn() then BagsEnh_Toggle() else orig.ToggleBackpack(...) end
    end
    ToggleBag = function(bag, ...)
        if UnifiedOn() then BagsEnh_Toggle() else orig.ToggleBag(bag, ...) end
    end
    OpenAllBags = function(...)
        if UnifiedOn() then BagsEnh_Show() else orig.OpenAllBags(...) end
    end
    CloseAllBags = function(...)
        if UnifiedOn() then BagsEnh_Hide() else orig.CloseAllBags(...) end
    end
    OpenBackpack = function(...)
        if UnifiedOn() then BagsEnh_Show() else orig.OpenBackpack(...) end
    end
    CloseBackpack = function(...)
        if UnifiedOn() then BagsEnh_Hide() else orig.CloseBackpack(...) end
    end
end

function BagsEnh_SetUnified(state)
    BagsEnhDB.enabled = state and true or false
    local ld = BagsEnh_L()
    if not state and BagsEnh_IsShown() then
        BagsEnh_Hide()
    end
    DEFAULT_CHAT_FRAME:AddMessage(ld.TOGGLE_HINT:format(state and ld.STATE_ON or ld.STATE_OFF))
end
