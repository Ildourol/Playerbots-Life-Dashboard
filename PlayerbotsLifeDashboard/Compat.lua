local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

-- ─── WoW 3.3.5a (Interface 30300, Build 12340) FrameXML Compatibility Layer ───
-- Polyfills modern convenience methods onto FrameXML userdata metatables
-- so standard UI code never errors on missing retail mixin functions.

local function polyfillMetatable(obj)
    if not obj then return end
    local meta = getmetatable(obj)
    local index = meta and meta.__index
    if type(index) == "table" then
        if not index.SetSize then
            rawset(index, "SetSize", function(self, width, height)
                self:SetWidth(width)
                self:SetHeight(height)
            end)
        end
        if not index.SetShown then
            rawset(index, "SetShown", function(self, shown)
                if shown then
                    self:Show()
                else
                    self:Hide()
                end
            end)
        end
        if not index.GetSize then
            rawset(index, "GetSize", function(self)
                return self:GetWidth(), self:GetHeight()
            end)
        end
    end
end

pcall(function()
    local dummyFrame = CreateFrame("Frame")
    polyfillMetatable(dummyFrame)

    local dummyTex = dummyFrame:CreateTexture()
    polyfillMetatable(dummyTex)

    local dummyFont = dummyFrame:CreateFontString()
    polyfillMetatable(dummyFont)

    dummyFrame:Hide()
end)
