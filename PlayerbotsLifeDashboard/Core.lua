local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Core = CreateFrame("Frame", "PlayerbotsLifeDashboardEventFrame")
LifeDashboard.Core = Core

-- ─── Event Handlers ──────────────────────────────────────────────────────────
Core:RegisterEvent("ADDON_LOADED")
Core:RegisterEvent("PLAYER_LOGIN")
Core:RegisterEvent("PLAYER_LOGOUT")
Core:RegisterEvent("PLAYER_ENTERING_WORLD")
Core:RegisterEvent("CHAT_MSG_ADDON")
Core:RegisterEvent("PLAYER_REGEN_DISABLED")
Core:RegisterEvent("PLAYER_REGEN_ENABLED")
Core:RegisterEvent("PLAYER_TARGET_CHANGED")
Core:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
Core:RegisterEvent("ZONE_CHANGED_NEW_AREA")
Core:RegisterEvent("ZONE_CHANGED")
Core:RegisterEvent("PARTY_MEMBERS_CHANGED")
Core:RegisterEvent("RAID_ROSTER_UPDATE")

Core:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == "PlayerbotsLifeDashboard" then
            LifeDashboard:OnInitSavedVars()
        end

    elseif event == "PLAYER_LOGIN" then
        LifeDashboard:OnPlayerLogin()

    elseif event == "PLAYER_ENTERING_WORLD" then
        if LifeDashboard.Store then
            LifeDashboard.Store:InitWorld()
            LifeDashboard.Store:ScanNearbyWorld()
        end
        if LifeDashboard.MinimapButton then
            LifeDashboard.MinimapButton:Init()
        end
        if LifeDashboard.Protocol and not LifeDashboard.connected then
            LifeDashboard.Protocol:SendMessage("HELLO", "main", nil, "v=1.0.0;build=12340")
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if LifeDashboard.Store and UnitExists("target") and UnitIsPlayer("target") then
            LifeDashboard.Store:ScanUnit("target")
        end

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if LifeDashboard.Store and UnitExists("mouseover") and UnitIsPlayer("mouseover") then
            LifeDashboard.Store:ScanUnit("mouseover")
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
        if LifeDashboard.Store then
            LifeDashboard.Store:ScanNearbyWorld()
        end

    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        if LifeDashboard.Store then
            LifeDashboard.Store:ScanNearbyWorld()
        end

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == LifeDashboard.Protocol.PREFIX then
            LifeDashboard.Protocol:OnPacketReceived(message, sender, channel)
        end

    elseif event == "PLAYER_LOGOUT" then
        LifeDashboard:OnPlayerLogout()

    elseif event == "PLAYER_REGEN_DISABLED" then
        LifeDashboard.inCombat = true

    elseif event == "PLAYER_REGEN_ENABLED" then
        LifeDashboard.inCombat = false
    end
end)

-- ─── Periodic Ticker ─────────────────────────────────────────────────────────
local elapsedTicker = 0
local pingTicker = 0
local handshakeTicker = 0
local worldScanTicker = 0

Core:SetScript("OnUpdate", function(self, elapsed)
    elapsedTicker = elapsedTicker + elapsed
    pingTicker = pingTicker + elapsed
    handshakeTicker = handshakeTicker + elapsed
    worldScanTicker = worldScanTicker + elapsed

    -- Buffer pruning every 2s
    if elapsedTicker >= 2.0 then
        elapsedTicker = 0
        if LifeDashboard.Protocol then
            LifeDashboard.Protocol:PruneExpiredBuffers()
        end
    end

    -- Periodic world scan every 1.5s
    if worldScanTicker >= 1.5 then
        worldScanTicker = 0
        if LifeDashboard.Store then
            LifeDashboard.Store:ScanNearbyWorld()
        end
    end

    -- Handshake retry every 5s until connected
    if not LifeDashboard.connected then
        if handshakeTicker >= 5.0 then
            handshakeTicker = 0
            if LifeDashboard.Protocol then
                LifeDashboard.Protocol:SendMessage("HELLO", "main", nil, "v=1.0.0;build=12340")
            end
        end
    else
        -- Keepalive ping every 20s once connected
        if pingTicker >= 20.0 then
            pingTicker = 0
            if LifeDashboard.Protocol then
                LifeDashboard.Protocol:SendMessage("PING", "main", nil, tostring(math.floor(GetTime() * 1000)))
            end
        end
    end
end)

-- ─── Initialization ──────────────────────────────────────────────────────────
function LifeDashboard:OnInitSavedVars()
    PlayerbotsLifeDashboardDB = PlayerbotsLifeDashboardDB or {}
    local db = PlayerbotsLifeDashboardDB
    db.schemaVersion = db.schemaVersion or 1
    db.window = db.window or { width = 1020, height = 680, scale = 1.0 }
    db.watchlist = db.watchlist or {}
    db.alerts = db.alerts or { enableAudio = true, enableToast = true }
    db.minimap = db.minimap or { angle = 220, hide = false }
end

function LifeDashboard:OnPlayerLogin()
    -- Initialize UI
    self.Window:Init()
    self.Overview:Init(self.Window.frame.ContentFrame)
    self.CityLife:Init(self.Window.frame.ContentFrame)
    self.PvPLife:Init(self.Window.frame.ContentFrame)
    self.Inspector:Init(self.Window.frame)
    self.Settings:Init(self.Window.frame)
    self.Diagnostics:Init(self.Window.frame)

    -- Initialize Minimap Button
    if self.MinimapButton then
        self.MinimapButton:Init()
    end

    -- Baseline World Data
    if self.Store then
        self.Store:InitWorld()
        self.Store:ScanNearbyWorld()
    end

    -- Default to Overview tab
    self.Window:SelectTab(1)

    -- Initiate handshake with server
    self.Protocol:SendMessage("HELLO", "main", nil, "v=1.0.0;build=12340")

    DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00Playerbots Life Dashboard|r v1.0.0 loaded. Click the |cff00ccffMinimap House Icon|r or type |cff00ccff/lifedash|r to open.")
end

function LifeDashboard:OnPlayerLogout()
    if self.Window and self.Window.frame then
        local f = self.Window.frame
        PlayerbotsLifeDashboardDB.window.width = f:GetWidth()
        PlayerbotsLifeDashboardDB.window.height = f:GetHeight()
    end
end

function LifeDashboard:ToggleWindow()
    if not self.Window or not self.Window.frame then return end
    if self.Window.frame:IsShown() then
        self.Window.frame:Hide()
    else
        self.Window.frame:Show()
        if self.Overview and self.Window.activeTabId == 1 then
            self.Overview:ApplyFilters()
        end
    end
end

-- ─── Slash Commands ──────────────────────────────────────────────────────────
SLASH_PLAYERBOTSLIFEDASHBOARD1 = "/lifedash"
SLASH_PLAYERBOTSLIFEDASHBOARD2 = "/ldash"

SlashCmdList["PLAYERBOTSLIFEDASHBOARD"] = function(msg)
    msg = string.lower(strtrim(msg or ""))
    if msg == "debug" then
        LifeDashboard.Protocol.debugEnabled = not LifeDashboard.Protocol.debugEnabled
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffaa00[LifeDashboard]|r Packet debug logging: %s",
            LifeDashboard.Protocol.debugEnabled and "|cff00ff66ENABLED|r" or "|cffff3333DISABLED|r"))
    elseif msg == "test" then
        LifeDashboard.Store:InjectMockData()
        LifeDashboard:ToggleWindow()
    elseif msg == "dump" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffaa00[LifeDashboard]|r Status: %s, Epoch: %s, Bots: %d",
            LifeDashboard.connected and "Connected" or "World Recognition Active",
            LifeDashboard.sessionEpoch or "None",
            #LifeDashboard.Store.botList))
    elseif msg == "minimap" then
        if LifeDashboard.MinimapButton then
            LifeDashboard.MinimapButton:Toggle()
            DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00[LifeDashboard]|r Toggled minimap house icon.")
        end
    elseif msg == "scan" then
        if LifeDashboard.Store then
            LifeDashboard.Store:ScanNearbyWorld()
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffaa00[LifeDashboard]|r Scanned nearby world. %d bots/players known.", #LifeDashboard.Store.botList))
        end
    elseif msg == "reset" then
        if LifeDashboard.Window and LifeDashboard.Window.frame then
            LifeDashboard.Window.frame:ClearAllPoints()
            LifeDashboard.Window.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            LifeDashboard.Window.frame:SetWidth(1020)
            LifeDashboard.Window.frame:SetHeight(680)
            DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00[LifeDashboard]|r Window position and size reset to default.")
        end
    else
        LifeDashboard:ToggleWindow()
    end
end
