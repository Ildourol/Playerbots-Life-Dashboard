local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Window = {
    frame = nil,
    tabs = {},
    activeTabId = 1,
    activeDrawer = nil,
    initialized = false,
}

LifeDashboard.Window = Window

function Window:Init()
    if self.initialized and self.frame then return end
    self.initialized = true

    local f = CreateFrame("Frame", "PlayerbotsLifeDashboardMainFrame", UIParent)
    f:SetWidth(1020)
    f:SetHeight(680)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetResizable(true)
    f:SetMinResize(760, 500)
    f:SetMaxResize(1600, 1200)
    f:SetClampedToScreen(true)
    f:Hide()

    LifeDashboard.Widgets:ApplyDarkBackdrop(f, 0.92, 0.8)

    -- Window Dragging Title Bar (bounded to title area only so it never overlaps top buttons)
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetWidth(420)
    titleBar:SetHeight(32)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleText:SetText("|cffffaa00" .. (LifeDashboard.L and LifeDashboard.L.ADDON_TITLE or "Playerbots Life Dashboard") .. "|r")
    f.TitleText = titleText

    local statusBadge = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusBadge:SetPoint("LEFT", titleText, "RIGHT", 14, 0)
    statusBadge:SetText("|cff888888[" .. (LifeDashboard.L and LifeDashboard.L.STATUS_DISCONNECTED or "Disconnected") .. "]|r")
    f.StatusBadge = statusBadge

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetFrameLevel(f:GetFrameLevel() + 10)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Top Tools (Drawers): Inspector, Settings, Diagnostics
    local diagBtn = CreateFrame("Button", "PlayerbotsLifeDashboardDiagBtn", f, "UIPanelButtonTemplate")
    diagBtn:SetWidth(95)
    diagBtn:SetHeight(22)
    diagBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -6, -4)
    diagBtn:SetFrameLevel(f:GetFrameLevel() + 10)
    diagBtn:SetText(LifeDashboard.L and LifeDashboard.L.DRAWER_DIAGNOSTICS or "Diagnostics")
    diagBtn:RegisterForClicks("LeftButtonUp")
    diagBtn:SetScript("OnClick", function() Window:ToggleDrawer("diagnostics") end)

    local cfgBtn = CreateFrame("Button", "PlayerbotsLifeDashboardCfgBtn", f, "UIPanelButtonTemplate")
    cfgBtn:SetWidth(105)
    cfgBtn:SetHeight(22)
    cfgBtn:SetPoint("RIGHT", diagBtn, "LEFT", -6, 0)
    cfgBtn:SetFrameLevel(f:GetFrameLevel() + 10)
    cfgBtn:SetText(LifeDashboard.L and LifeDashboard.L.DRAWER_SETTINGS or "Configuration")
    cfgBtn:RegisterForClicks("LeftButtonUp")
    cfgBtn:SetScript("OnClick", function() Window:ToggleDrawer("settings") end)

    local inspBtn = CreateFrame("Button", "PlayerbotsLifeDashboardInspBtn", f, "UIPanelButtonTemplate")
    inspBtn:SetWidth(105)
    inspBtn:SetHeight(22)
    inspBtn:SetPoint("RIGHT", cfgBtn, "LEFT", -6, 0)
    inspBtn:SetFrameLevel(f:GetFrameLevel() + 10)
    inspBtn:SetText(LifeDashboard.L and LifeDashboard.L.DRAWER_INSPECTOR or "Bot Inspector")
    inspBtn:RegisterForClicks("LeftButtonUp")
    inspBtn:SetScript("OnClick", function() Window:ToggleDrawer("inspector") end)

    local topRefreshBtn = CreateFrame("Button", "PlayerbotsLifeDashboardTopRefreshBtn", f, "UIPanelButtonTemplate")
    topRefreshBtn:SetWidth(80)
    topRefreshBtn:SetHeight(22)
    topRefreshBtn:SetPoint("RIGHT", inspBtn, "LEFT", -6, 0)
    topRefreshBtn:SetFrameLevel(f:GetFrameLevel() + 10)
    topRefreshBtn:SetText(LifeDashboard.L and LifeDashboard.L.BTN_REFRESH or "Refresh")
    topRefreshBtn:RegisterForClicks("LeftButtonUp")
    topRefreshBtn:SetScript("OnClick", function()
        if LifeDashboard.Store and LifeDashboard.Store.RequestRefresh then
            LifeDashboard.Store:RequestRefresh()
        elseif LifeDashboard.Protocol then
            LifeDashboard.Protocol:SendMessage("SUBSCRIBE", "main", nil, "refresh")
        end
        f.refreshTimer = 1.0
        if f.StatusBadge then
            f.StatusBadge:SetText("|cff00ff00[Refreshing...]|r")
        end
    end)

    -- ─── Tab Bar (EXACTLY 3 PRIMARY TABS) ────────────────────────────────────────
    local tabContainer = CreateFrame("Frame", nil, f)
    tabContainer:SetWidth(f:GetWidth() - 20)
    tabContainer:SetHeight(28)
    tabContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -40)

    local tabNames = {
        LifeDashboard.L and LifeDashboard.L.TAB_OVERVIEW or "Overview",
        LifeDashboard.L and LifeDashboard.L.TAB_CITY_LIFE or "City Life",
        LifeDashboard.L and LifeDashboard.L.TAB_PVP_LIFE or "PvP Life",
    }

    self.tabs = {}
    for i = 1, 3 do
        local tab = CreateFrame("Button", "LifeDashTab" .. i, f, "CharacterFrameTabButtonTemplate")
        tab:SetID(i)
        tab:SetText(tabNames[i])
        PanelTemplates_TabResize(tab, 0)
        if i == 1 then
            tab:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", 0, 0)
        else
            tab:SetPoint("LEFT", self.tabs[i - 1], "RIGHT", -14, 0)
        end
        tab:SetScript("OnClick", function(self)
            Window:SelectTab(self:GetID())
        end)
        self.tabs[i] = tab
    end

    -- ─── Content Container ───────────────────────────────────────────────────────
    local contentFrame = CreateFrame("Frame", nil, f)
    contentFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -72)
    contentFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 30)
    f.ContentFrame = contentFrame

    -- ─── Footer Bar ──────────────────────────────────────────────────────────────
    local footer = CreateFrame("Frame", nil, f)
    footer:SetWidth(f:GetWidth() - 20)
    footer:SetHeight(24)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 4)

    local footerText = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerText:SetPoint("LEFT", footer, "LEFT", 4, 0)
    footerText:SetText("Protocol: LIFE335 v1 | Client: 3.3.5a (12340)")
    f.FooterText = footerText

    -- Window Resize Handle
    local resizeGrip = CreateFrame("Button", nil, f)
    resizeGrip:SetWidth(16)
    resizeGrip:SetHeight(16)
    resizeGrip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    resizeGrip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

    f:SetScript("OnUpdate", function(selfFrame, elapsed)
        if selfFrame.refreshTimer then
            selfFrame.refreshTimer = selfFrame.refreshTimer - elapsed
            if selfFrame.refreshTimer <= 0 then
                selfFrame.refreshTimer = nil
                Window:UpdateHeaderStatus()
            end
        end
    end)

    self.frame = f

    -- Hook Esc to close window
    tinsert(UISpecialFrames, "PlayerbotsLifeDashboardMainFrame")
end

function Window:UpdateHeaderStatus()
    if not self.frame or not self.frame.StatusBadge then return end

    if LifeDashboard.isMockData then
        self.frame.StatusBadge:SetText("|cffffcc00[DEMO MODE: Mock Telemetry]|r")
    elseif LifeDashboard.connected then
        local rtt = LifeDashboard.Clock and LifeDashboard.Clock.rttMs or 0
        local connStr = LifeDashboard.L and LifeDashboard.L.STATUS_CONNECTED or "Connected"
        self.frame.StatusBadge:SetText(string.format("|cff00ff66[%s: %dms]|r", connStr, rtt))
    elseif LifeDashboard.connectionState == "HELLO_SENT" then
        self.frame.StatusBadge:SetText("|cff00ccff[Connecting...]|r")
    elseif LifeDashboard.connectionState == "STALE" then
        self.frame.StatusBadge:SetText("|cffff9900[Degraded (Stale Heartbeat)]|r")
    else
        self.frame.StatusBadge:SetText("|cff888888[Disconnected: Local Observations Only]|r")
    end
end

function Window:SelectTab(tabId)
    self.activeTabId = tabId
    for i = 1, 3 do
        if i == tabId then
            PanelTemplates_SelectTab(self.tabs[i])
        else
            PanelTemplates_DeselectTab(self.tabs[i])
        end
    end

    -- Hide/Show Tab Panes
    if LifeDashboard.OverviewPane then
        if tabId == 1 then LifeDashboard.OverviewPane:Show() else LifeDashboard.OverviewPane:Hide() end
    end
    if LifeDashboard.CityLifePane then
        if tabId == 2 then LifeDashboard.CityLifePane:Show() else LifeDashboard.CityLifePane:Hide() end
    end
    if LifeDashboard.PvPLifePane then
        if tabId == 3 then LifeDashboard.PvPLifePane:Show() else LifeDashboard.PvPLifePane:Hide() end
    end
end

function Window:ToggleDrawer(drawerName)
    local drawerFrame = (drawerName == "inspector" and LifeDashboard.InspectorDrawer)
                     or (drawerName == "settings" and LifeDashboard.SettingsDrawer)
                     or (drawerName == "diagnostics" and LifeDashboard.DiagnosticsDrawer)

    if drawerFrame and drawerFrame:IsShown() then
        self:CloseDrawer()
    else
        self:OpenDrawer(drawerName)
    end
end

function Window:OpenDrawer(drawerName)
    self:CloseDrawer()
    self.activeDrawer = drawerName

    if drawerName == "inspector" then
        if not LifeDashboard.InspectorDrawer and LifeDashboard.Inspector and LifeDashboard.Inspector.Init then
            LifeDashboard.Inspector:Init(self.frame)
        end
        if LifeDashboard.InspectorDrawer then
            LifeDashboard.InspectorDrawer:Show()
            if LifeDashboard.Inspector and LifeDashboard.Inspector.DisplayBot then
                LifeDashboard.Inspector:DisplayBot(LifeDashboard.Store and LifeDashboard.Store.selectedBotGuid)
            end
        end

    elseif drawerName == "settings" then
        if not LifeDashboard.SettingsDrawer and LifeDashboard.Settings and LifeDashboard.Settings.Init then
            LifeDashboard.Settings:Init(self.frame)
        end
        if LifeDashboard.SettingsDrawer then
            LifeDashboard.SettingsDrawer:Show()
            if LifeDashboard.Settings and LifeDashboard.Settings.PopulateDefaults then
                LifeDashboard.Settings:PopulateDefaults()
            end
        end

    elseif drawerName == "diagnostics" then
        if not LifeDashboard.DiagnosticsDrawer and LifeDashboard.Diagnostics and LifeDashboard.Diagnostics.Init then
            LifeDashboard.Diagnostics:Init(self.frame)
        end
        if LifeDashboard.DiagnosticsDrawer then
            LifeDashboard.DiagnosticsDrawer:Show()
            if LifeDashboard.Diagnostics and LifeDashboard.Diagnostics.UpdateMetrics then
                LifeDashboard.Diagnostics:UpdateMetrics()
            end
        end
    end
end

function Window:CloseDrawer()
    if LifeDashboard.InspectorDrawer then LifeDashboard.InspectorDrawer:Hide() end
    if LifeDashboard.SettingsDrawer then LifeDashboard.SettingsDrawer:Hide() end
    if LifeDashboard.DiagnosticsDrawer then LifeDashboard.DiagnosticsDrawer:Hide() end
    self.activeDrawer = nil
end
