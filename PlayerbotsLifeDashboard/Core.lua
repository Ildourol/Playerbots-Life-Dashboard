local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Core = CreateFrame("Frame", "PlayerbotsLifeDashboardEventFrame")
LifeDashboard.Core = Core

LifeDashboard.connected = false
LifeDashboard.connectionState = "DISCONNECTED"
LifeDashboard.sessionEpoch = nil
LifeDashboard.lastPacketTime = 0
LifeDashboard.inCombat = false
LifeDashboard.uiInitialized = false

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
        if LifeDashboard.Protocol then
            LifeDashboard.Protocol:ResetBuffers()
        end
        if LifeDashboard.Store then
            LifeDashboard.Store:InitWorld()
            LifeDashboard.Store:ScanNearbyWorld()
        end
        if LifeDashboard.MinimapButton then
            LifeDashboard.MinimapButton:Init()
        end
        if not LifeDashboard.connected then
            LifeDashboard.connectionState = "HELLO_SENT"
            if LifeDashboard.Protocol then
                LifeDashboard.Protocol:SendMessage("HELLO", "main", nil, "v=1.0.0;build=12340")
            end
        end
        if LifeDashboard.Window and LifeDashboard.Window.UpdateHeaderStatus then
            LifeDashboard.Window:UpdateHeaderStatus()
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if LifeDashboard.Store and UnitExists("target") and UnitIsPlayer("target") then
            if LifeDashboard.Store:ScanUnit("target") then
                LifeDashboard.Store:RebuildBotList()
                LifeDashboard.Store:Notify("ON_ROSTER_UPDATED")
            end
        end

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if LifeDashboard.Store and UnitExists("mouseover") and UnitIsPlayer("mouseover") then
            if LifeDashboard.Store:ScanUnit("mouseover") then
                LifeDashboard.Store:RebuildBotList()
                LifeDashboard.Store:Notify("ON_ROSTER_UPDATED")
            end
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
        -- Atomically resolve pending secure target updates deferred during combat (DASH-08)
        if LifeDashboard.Inspector and LifeDashboard.Inspector.OnLeaveCombat then
            LifeDashboard.Inspector:OnLeaveCombat()
        end
    end
end)

-- ─── Periodic Ticker (DASH-11 & DASH-12) ─────────────────────────────────────
local elapsedTicker = 0
local pingTicker = 0
local handshakeTicker = 0
local worldScanTicker = 0
local pruneTicker = 0

Core:SetScript("OnUpdate", function(self, elapsed)
    elapsedTicker = elapsedTicker + elapsed
    pingTicker = pingTicker + elapsed
    handshakeTicker = handshakeTicker + elapsed
    worldScanTicker = worldScanTicker + elapsed
    pruneTicker = pruneTicker + elapsed

    -- Buffer pruning every 2s
    if elapsedTicker >= 2.0 then
        elapsedTicker = 0
        if LifeDashboard.Protocol then
            LifeDashboard.Protocol:PruneExpiredBuffers()
        end
    end

    -- Periodic world scan every 1.5s (batched)
    if worldScanTicker >= 1.5 then
        worldScanTicker = 0
        if LifeDashboard.Store then
            LifeDashboard.Store:ScanNearbyWorld()
        end
    end

    -- Prune stale unclassified world entities every 30s (DASH-11)
    if pruneTicker >= 30.0 then
        pruneTicker = 0
        if LifeDashboard.Store then
            LifeDashboard.Store:PruneStaleObserved(300) -- 5 min TTL
        end
    end

    -- Handshake retry every 5s until connected (DASH-12)
    if not LifeDashboard.connected and not LifeDashboard.isMockData then
        if handshakeTicker >= 5.0 then
            handshakeTicker = 0
            LifeDashboard.connectionState = "HELLO_SENT"
            if LifeDashboard.Protocol then
                LifeDashboard.Protocol:SendMessage("HELLO", "main", nil, "v=1.0.0;build=12340")
            end
        end
    else
        -- Keepalive ping every 20s once connected
        if pingTicker >= 20.0 then
            pingTicker = 0
            local now = GetTime()
            -- Heartbeat expiry check: 40s without packet drops connection to STALE
            if not LifeDashboard.isMockData and (now - (LifeDashboard.lastPacketTime or 0)) > 40.0 then
                LifeDashboard.connected = false
                LifeDashboard.connectionState = "STALE"
                LifeDashboard.sessionEpoch = nil
                if LifeDashboard.Permissions and LifeDashboard.Permissions.Reset then
                    LifeDashboard.Permissions:Reset()
                end
                if LifeDashboard.Window and LifeDashboard.Window.UpdateHeaderStatus then
                    LifeDashboard.Window:UpdateHeaderStatus()
                end
            elseif LifeDashboard.connected and LifeDashboard.Protocol then
                LifeDashboard.Protocol:SendMessage("PING", "main", nil, tostring(math.floor(now * 1000)))
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
    if self.uiInitialized then return end
    self.uiInitialized = true

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

    -- Clean initial world data (no mock telemetry)
    if self.Store then
        self.Store:InitWorld()
        self.Store:ScanNearbyWorld()
    end

    -- Default to Overview tab
    self.Window:SelectTab(1)

    -- Initiate handshake with server
    self.connectionState = "HELLO_SENT"
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

function LifeDashboard:ShowWindow()
    if not self.Window or not self.Window.frame then return end
    self.Window.frame:Show()
    if self.Overview and self.Window.activeTabId == 1 then
        self.Overview:ApplyFilters()
    end
end

function LifeDashboard:HideWindow()
    if not self.Window or not self.Window.frame then return end
    self.Window.frame:Hide()
end

-- ─── Slash Commands Dispatcher (DASH-10) ─────────────────────────────────────
SLASH_PLAYERBOTSLIFEDASHBOARD1 = "/lifedash"
SLASH_PLAYERBOTSLIFEDASHBOARD2 = "/ldash"

SlashCmdList["PLAYERBOTSLIFEDASHBOARD"] = function(msg)
    msg = string.lower(strtrim(msg or ""))

    if msg == "show" then
        LifeDashboard:ShowWindow()

    elseif msg == "hide" then
        LifeDashboard:HideWindow()

    elseif msg == "toggle" or msg == "" then
        LifeDashboard:ToggleWindow()

    elseif msg == "config" then
        LifeDashboard:ShowWindow()
        LifeDashboard.Window:OpenDrawer("settings")

    elseif msg == "diag" then
        LifeDashboard:ShowWindow()
        LifeDashboard.Window:OpenDrawer("diagnostics")

    elseif msg == "minimap" then
        if LifeDashboard.MinimapButton then
            LifeDashboard.MinimapButton:Toggle()
            DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00[LifeDashboard]|r Toggled minimap house icon.")
        end

    elseif msg == "debug" then
        LifeDashboard.Protocol.debugEnabled = not LifeDashboard.Protocol.debugEnabled
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffaa00[LifeDashboard]|r Packet debug logging: %s",
            LifeDashboard.Protocol.debugEnabled and "|cff00ff66ENABLED|r" or "|cffff3333DISABLED|r"))

    elseif msg == "test" then
        if LifeDashboard.Store.isMockData then
            LifeDashboard.Store:InitWorld()
            DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00[LifeDashboard]|r Cleared mock demonstration data.")
        else
            LifeDashboard.Store:InjectMockData()
            LifeDashboard:ShowWindow()
            DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00[LifeDashboard]|r Injected mock demonstration data [DEMO MODE]. Type /lifedash test to clear.")
        end

    elseif msg == "dump" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffaa00[LifeDashboard]|r State: %s, Epoch: %s, Bots: %d",
            LifeDashboard.connectionState or "UNKNOWN",
            LifeDashboard.sessionEpoch or "None",
            #LifeDashboard.Store.botList))

    elseif msg == "scan" then
        if LifeDashboard.Store then
            LifeDashboard.Store:ScanNearbyWorld()
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffaa00[LifeDashboard]|r Scanned nearby world. %d entities known.", #LifeDashboard.Store.botList))
        end

    elseif msg == "reset" then
        if LifeDashboard.Window and LifeDashboard.Window.frame then
            LifeDashboard.Window.frame:ClearAllPoints()
            LifeDashboard.Window.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            LifeDashboard.Window.frame:SetWidth(1020)
            LifeDashboard.Window.frame:SetHeight(680)
        end
        if LifeDashboard.Store then
            LifeDashboard.Store:InitWorld()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00[LifeDashboard]|r Window position, size, and store data reset.")

    elseif msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00[Playerbots Life Dashboard Commands]|r")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ccff/lifedash|r or |cff00ccff/ldash|r - Toggle main window")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ccff/lifedash show|r - Show window")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ccff/lifedash hide|r - Hide window")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ccff/lifedash toggle|r - Toggle window")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ccff/lifedash config|r - Open configuration drawer")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ccff/lifedash diag|r - Open diagnostics drawer")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ccff/lifedash minimap|r - Toggle minimap icon")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ccff/lifedash debug|r - Toggle wire packet chat log")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ccff/lifedash test|r - Toggle mock demo data")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ccff/lifedash scan|r - Scan nearby units")
        DEFAULT_CHAT_FRAME:AddMessage("  |cff00ccff/lifedash reset|r - Reset window and clear state")
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffffaa00[LifeDashboard]|r Unknown command '%s'. Type |cff00ccff/lifedash help|r for commands.", msg))
    end
end
