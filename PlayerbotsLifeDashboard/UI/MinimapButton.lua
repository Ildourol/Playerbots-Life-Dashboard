local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local MinimapButton = {
    button = nil,
}
LifeDashboard.MinimapButton = MinimapButton

local BTN_NAME = "PlayerbotsLifeMinimapButton"
local RADIUS = 80

local function deg2rad(degrees)
    return degrees * math.pi / 180
end

function MinimapButton:UpdatePosition(angle)
    local db = PlayerbotsLifeDashboardDB and PlayerbotsLifeDashboardDB.minimap
    local resolvedAngle = angle or (db and db.angle) or 220

    if not Minimap or not Minimap:GetCenter() then
        return
    end

    local xOffset = math.cos(deg2rad(resolvedAngle)) * RADIUS
    local yOffset = math.sin(deg2rad(resolvedAngle)) * RADIUS

    local btn = self.button or _G[BTN_NAME]
    if btn then
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", xOffset, yOffset)
    end
end

local function saveAngleFromCursor(button)
    if not Minimap then return end
    local minimapX, minimapY = Minimap:GetCenter()
    if not minimapX or not minimapY then return end

    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if not scale or scale == 0 then scale = 1 end

    cursorX, cursorY = cursorX / scale, cursorY / scale

    local deltaX, deltaY = cursorX - minimapX, cursorY - minimapY
    local angle = math.deg(math.atan2(deltaY, deltaX))
    if angle < 0 then
        angle = angle + 360
    end

    if PlayerbotsLifeDashboardDB then
        PlayerbotsLifeDashboardDB.minimap = PlayerbotsLifeDashboardDB.minimap or {}
        PlayerbotsLifeDashboardDB.minimap.angle = angle
    end

    MinimapButton:UpdatePosition(angle)
end

function MinimapButton:Init()
    if self.button or _G[BTN_NAME] then return end

    local btn = CreateFrame("Button", BTN_NAME, Minimap)
    self.button = btn

    btn:SetWidth(32)
    btn:SetHeight(32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetMovable(true)
    btn:SetClampedToScreen(true)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    -- Background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetWidth(24)
    bg:SetHeight(24)
    bg:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.bg = bg

    -- House icon (Official Blizzard Innkeeper house tracking texture in 3.3.5)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Minimap\\Tracking\\Innkeeper")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.icon = icon

    -- Circular border
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(54)
    border:SetHeight(54)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    btn.border = border

    -- Highlight texture
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    -- Dragging around minimap
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", saveAngleFromCursor)
    end)

    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        saveAngleFromCursor(self)
    end)

    -- Clicks: Left = Toggle Window, Right = Reset
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            LifeDashboard:ToggleWindow()
        elseif button == "RightButton" then
            if LifeDashboard.Window and LifeDashboard.Window.frame then
                LifeDashboard.Window.frame:ClearAllPoints()
                LifeDashboard.Window.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                LifeDashboard.Window.frame:SetWidth(1020)
                LifeDashboard.Window.frame:SetHeight(680)
                DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00[LifeDashboard]|r Window position reset to center.")
            end
        end
    end)

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cffffaa00" .. (LifeDashboard.L and LifeDashboard.L.ADDON_TITLE or "Playerbots Life Dashboard") .. "|r", 1, 1, 1)
        GameTooltip:AddLine("|cff00ccffLeft-Click:|r Toggle Dashboard Window", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("|cff00ccffRight-Click:|r Reset Window Position", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("|cff00ccffDrag:|r Move Icon Around Minimap", 0.9, 0.9, 0.9)

        local zone = GetZoneText() or ""
        local subzone = GetSubZoneText() or ""
        if zone ~= "" then
            local locStr = zone
            if subzone ~= "" and subzone ~= zone then
                locStr = locStr .. " - " .. subzone
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cffffaa00Current Location:|r " .. locStr, 0.8, 0.8, 0.8)
        end

        local statusText = LifeDashboard.connected and "|cff00ff66Connected (Server Telemetry)|r" or "|cff00ccffWorld Recognition Active|r"
        GameTooltip:AddLine("|cffffaa00Status:|r " .. statusText, 0.8, 0.8, 0.8)

        local botCount = LifeDashboard.Store and LifeDashboard.Store.botList and #LifeDashboard.Store.botList or 0
        if botCount > 0 then
            GameTooltip:AddLine(string.format("|cffffaa00Tracked Bots:|r %d active", botCount), 0.8, 0.8, 0.8)
        end

        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self:UpdatePosition()

    local db = PlayerbotsLifeDashboardDB and PlayerbotsLifeDashboardDB.minimap
    if db and db.hide then
        btn:Hide()
    else
        btn:Show()
    end
end

function MinimapButton:Toggle(show)
    if not self.button then return end
    if show == nil then
        show = not self.button:IsShown()
    end
    if show then
        self.button:Show()
    else
        self.button:Hide()
    end
    if PlayerbotsLifeDashboardDB then
        PlayerbotsLifeDashboardDB.minimap = PlayerbotsLifeDashboardDB.minimap or {}
        PlayerbotsLifeDashboardDB.minimap.hide = not show
    end
end
