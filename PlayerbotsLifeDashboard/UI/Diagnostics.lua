local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Diagnostics = {
    drawer = nil,
}

LifeDashboard.Diagnostics = Diagnostics

function Diagnostics:Init(parent)
    local d = CreateFrame("Frame", "PlayerbotsLifeDashboardDiagnosticsDrawer", parent)
    d:SetWidth(340)
    d:SetHeight(parent:GetHeight() - 72)
    d:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -40)
    d:SetFrameLevel(parent:GetFrameLevel() + 20)
    d:EnableMouse(true)
    d:Hide()
    LifeDashboard.Widgets:ApplyDarkBackdrop(d, 0.95, 0.9)
    LifeDashboard.DiagnosticsDrawer = d
    self.drawer = d

    local title = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -10)
    title:SetText(LifeDashboard.L and LifeDashboard.L.DRAWER_DIAGNOSTICS or "Diagnostics")

    local closeBtn = CreateFrame("Button", nil, d, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", d, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        if LifeDashboard.Window then
            LifeDashboard.Window:CloseDrawer()
        else
            d:Hide()
        end
    end)

    local infoCard = CreateFrame("Frame", nil, d)
    infoCard:SetWidth(316)
    infoCard:SetHeight(210)
    infoCard:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    LifeDashboard.Widgets:ApplyCardBackdrop(infoCard)

    local metricsText = infoCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    metricsText:SetPoint("TOPLEFT", infoCard, "TOPLEFT", 8, -8)
    metricsText:SetPoint("BOTTOMRIGHT", infoCard, "BOTTOMRIGHT", -8, 8)
    metricsText:SetJustifyH("LEFT")
    metricsText:SetJustifyV("TOP")
    d.MetricsText = metricsText

    -- Packet Debug Toggle Checkbox
    local cb = CreateFrame("CheckButton", "LifeDashPacketDebugCB", d, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", infoCard, "BOTTOMLEFT", 0, -12)
    local cbLabel = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cbLabel:SetText("Log LIFE335 Wire Packets to Chat")
    cb:SetScript("OnClick", function(self)
        if LifeDashboard.Protocol then
            LifeDashboard.Protocol.debugEnabled = self:GetChecked()
        end
    end)
    d.DebugCheckbox = cb

    -- Inject Mock Data Button (For Offline / Local Testing)
    local testBtn = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    testBtn:SetWidth(160)
    testBtn:SetHeight(24)
    testBtn:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -14)
    testBtn:SetText("Inject Mock Telemetry")
    testBtn:SetScript("OnClick", function()
        if LifeDashboard.Store and LifeDashboard.Store.InjectMockData then
            LifeDashboard.Store:InjectMockData()
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff66[LifeDashboard]|r Injected realistic mock telemetry dataset.")
        end
    end)

    local rstBtn = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
    rstBtn:SetWidth(140)
    rstBtn:SetHeight(24)
    rstBtn:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)
    rstBtn:SetText("Reset State")
    rstBtn:SetScript("OnClick", function()
        if LifeDashboard.Store then
            LifeDashboard.Store.bots = {}
            LifeDashboard.Store.botList = {}
            LifeDashboard.Store:RebuildBotList()
            LifeDashboard.Store:Notify("ON_ROSTER_UPDATED")
        end
    end)

    d:SetScript("OnUpdate", function(self, elapsed)
        self.updateTimer = (self.updateTimer or 0) + elapsed
        if self.updateTimer > 1.0 then
            self.updateTimer = 0
            Diagnostics:UpdateMetrics()
        end
    end)
end

function Diagnostics:UpdateMetrics()
    local d = self.drawer
    if not d or not d:IsShown() then return end

    UpdateAddOnMemoryUsage()
    local memKb = GetAddOnMemoryUsage("PlayerbotsLifeDashboard")
    local rtt = LifeDashboard.Clock and LifeDashboard.Clock.rttMs or 0
    local buffers = 0
    for _ in pairs(LifeDashboard.Protocol and LifeDashboard.Protocol.buffers or {}) do buffers = buffers + 1 end

    local text = string.format(
        "|cffffaa00Wire Transport Metrics|r\n" ..
        "------------------------------------\n" ..
        "Status: %s\n" ..
        "Server Round-Trip: %d ms\n" ..
        "Active Reassembly Buffers: %d\n" ..
        "Max Chunk Size: 240 bytes\n" ..
        "Session Epoch: %s\n\n" ..
        "|cffffaa00Client Memory & Performance|r\n" ..
        "------------------------------------\n" ..
        "Addon Memory Usage: %.1f KB\n" ..
        "Cached Bots in Roster: %d\n" ..
        "Active City Hubs: %d\n" ..
        "Active PvP Hotspots: %d\n" ..
        "Queued Server Tasks: %d",
        LifeDashboard.connected and "|cff00ff66Connected|r" or "|cff888888Disconnected|r",
        rtt,
        buffers,
        LifeDashboard.sessionEpoch or "None",
        memKb,
        (LifeDashboard.Store and LifeDashboard.Store.botList and #LifeDashboard.Store.botList) or 0,
        (LifeDashboard.Store and LifeDashboard.Store.cityHubList and #LifeDashboard.Store.cityHubList) or 0,
        (LifeDashboard.Store and LifeDashboard.Store.pvpZoneList and #LifeDashboard.Store.pvpZoneList) or 0,
        (LifeDashboard.Store and LifeDashboard.Store.workQueues and #LifeDashboard.Store.workQueues) or 0
    )
    if d.MetricsText then
        d.MetricsText:SetText(text)
    end
end
