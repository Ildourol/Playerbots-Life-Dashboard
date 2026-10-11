local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

-- ─── WoW 3.3.5a (Interface 30300, Build 12340) FrameXML Compatibility Layer ───
-- Provides safe helper functions without modifying global frame userdata metatables,
-- preventing execution taint or cross-addon interference.

local Compat = {}
LifeDashboard.Compat = Compat

function Compat.SetSize(frame, width, height)
    if not frame then return end
    frame:SetWidth(width)
    frame:SetHeight(height)
end

function Compat.SetShown(frame, shown)
    if not frame then return end
    if shown then
        frame:Show()
    else
        frame:Hide()
    end
end

function Compat.GetSize(frame)
    if not frame then return 0, 0 end
    return frame:GetWidth(), frame:GetHeight()
end
