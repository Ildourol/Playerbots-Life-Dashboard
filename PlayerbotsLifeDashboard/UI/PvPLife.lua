local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local PvPLife = {}
LifeDashboard.PvPLife = PvPLife

function PvPLife:Init(parent)
    local pane = CreateFrame("Frame", "PlayerbotsLifeDashboardPvPPane", parent)
    pane:SetAllPoints(parent)
    pane:Hide()
    LifeDashboard.PvPLifePane = pane

    -- ─── Left Side: Hotspot Catalog ──────────────────────────────────────────────
    local zonePanel = CreateFrame("Frame", nil, pane)
    zonePanel:SetWidth(380)
    zonePanel:SetHeight(480)
    zonePanel:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -6)
    LifeDashboard.Widgets:ApplyDarkBackdrop(zonePanel, 0.5, 0.4)

    local zoneTitle = zonePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoneTitle:SetPoint("TOPLEFT", zonePanel, "TOPLEFT", 10, -8)
    zoneTitle:SetText("PvP Life Hotspots & Skirmishes")

    local zoneCols = {
        { name = "Zone", width = 130 },
        { name = "Type", width = 80 },
        { name = "Levels", width = 60 },
        { name = "A / H", width = 60 },
        { name = "Status", width = 50 },
    }

    local zoneTable = LifeDashboard.Widgets:CreateVirtualizedTable(zonePanel, 370, 430, 26, zoneCols, function(row, item)
        row.cells[1]:SetText(item.name)
        row.cells[2]:SetText(item.activityType or "Skirmish")
        row.cells[3]:SetText(string.format("%d-%d", item.minLevel or 20, item.maxLevel or 80))
        row.cells[4]:SetText(string.format("|cff0070dd%d|r / |cffc41e3a%d|r", item.activeAlliance or 0, item.activeHorde or 0))

        if (item.cooldownSec or 0) > 0 then
            row.cells[5]:SetText(string.format("|cffff9900%ds|r", item.cooldownSec))
        else
            row.cells[5]:SetText("|cff00ff66Live|r")
        end

        row:SetScript("OnClick", function()
            PvPLife:SelectZone(item.name)
        end)
    end)
    zoneTable:SetPoint("TOPLEFT", zonePanel, "TOPLEFT", 5, -34)
    pane.ZoneTable = zoneTable

    -- ─── Top Right: Work Queues Monitor ──────────────────────────────────────────
    local queuePanel = CreateFrame("Frame", nil, pane)
    queuePanel:SetPoint("TOPLEFT", zonePanel, "TOPRIGHT", 14, 0)
    queuePanel:SetWidth(590)
    queuePanel:SetHeight(220)
    LifeDashboard.Widgets:ApplyDarkBackdrop(queuePanel, 0.5, 0.4)

    local queueTitle = queuePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    queueTitle:SetPoint("TOPLEFT", queuePanel, "TOPLEFT", 10, -8)
    queueTitle:SetText("Server Work Queues (Move, Engage, Duel, Chat)")

    local queueCols = {
        { name = "Queue", width = 80 },
        { name = "Bot", width = 110 },
        { name = "Task", width = 230 },
        { name = "Due", width = 90 },
        { name = "Truth", width = 70 },
    }

    local queueTable = LifeDashboard.Widgets:CreateVirtualizedTable(queuePanel, 580, 175, 24, queueCols, function(row, item)
        row.cells[1]:SetText(string.upper(item.queue or ""))
        row.cells[2]:SetText(item.botName or "")
        row.cells[3]:SetText(item.taskType or "")
        row.cells[4]:SetText(LifeDashboard.Clock:FormatDueTime(item.dueMs, item.truthClass))
        row.cells[5]:SetText(LifeDashboard.Clock:FormatTruthBadge(item.truthClass or "QUEUED"))
    end)
    queueTable:SetPoint("TOPLEFT", queuePanel, "TOPLEFT", 5, -34)
    pane.QueueTable = queueTable

    -- ─── Bottom Right: Active Participants in Zone ───────────────────────────────
    local partPanel = CreateFrame("Frame", nil, pane)
    partPanel:SetPoint("TOPLEFT", queuePanel, "BOTTOMLEFT", 0, -10)
    partPanel:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 6)
    LifeDashboard.Widgets:ApplyDarkBackdrop(partPanel, 0.5, 0.4)

    local partTitle = partPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    partTitle:SetPoint("TOPLEFT", partPanel, "TOPLEFT", 10, -8)
    partTitle:SetText("Zone Participants")
    pane.PartTitle = partTitle

    local partCols = {
        { name = "Participant", width = 130 },
        { name = "Faction", width = 80 },
        { name = "Action", width = 150 },
        { name = "Next Order", width = 140 },
        { name = "State", width = 80 },
    }

    local partTable = LifeDashboard.Widgets:CreateVirtualizedTable(partPanel, 580, 200, 24, partCols, function(row, item)
        local isWatched = LifeDashboard.Store and LifeDashboard.Store:IsWatchlisted(item.guid)
        local star = isWatched and "|cffffd700★ |r" or ""
        row.cells[1]:SetText(star .. item.name)
        if item.faction == "alliance" then
            row.cells[2]:SetText("|cff0070ddAlliance|r")
        else
            row.cells[2]:SetText("|cffc41e3aHorde|r")
        end
        row.cells[3]:SetText(item.lastAction or "--")
        row.cells[4]:SetText(item.nextTask or "--")
        row.cells[5]:SetText(item.status or "Active")

        row:SetScript("OnClick", function()
            LifeDashboard.Store.selectedBotGuid = item.guid
            LifeDashboard.Window:OpenDrawer("inspector")
            if LifeDashboard.Inspector and LifeDashboard.Inspector.DisplayBot then
                LifeDashboard.Inspector:DisplayBot(item.guid)
            end
        end)
    end)
    partTable:SetPoint("TOPLEFT", partPanel, "TOPLEFT", 5, -34)
    pane.PartTable = partTable

    -- Listen to store updates
    LifeDashboard.Store:RegisterListener("ON_ROSTER_UPDATED", function()
        PvPLife:UpdateData()
    end)
    LifeDashboard.Store:RegisterListener("ON_CONNECTED", function()
        PvPLife:UpdateData()
    end)
end

function PvPLife:SelectZone(zoneName)
    if self.selectedZone == zoneName then
        self.selectedZone = nil -- Click again to deselect
    else
        self.selectedZone = zoneName
    end
    self:UpdateParticipants()
end

function PvPLife:UpdateData()
    local pane = LifeDashboard.PvPLifePane
    if not pane then return end

    local zones = LifeDashboard.Store.pvpZoneList or {}
    pane.ZoneTable:SetData(zones)

    local queues = LifeDashboard.Store.workQueues or {}
    pane.QueueTable:SetData(queues)

    self:UpdateParticipants()
end

function PvPLife:UpdateParticipants()
    local pane = LifeDashboard.PvPLifePane
    if not pane then return end

    local filtered = {}
    local sel = self.selectedZone
    local selLower = sel and string.lower(sel)
    for _, b in ipairs(LifeDashboard.Store.botList or {}) do
        if b.module == "pvp" then
            if not sel then
                table.insert(filtered, b)
            else
                local match = false
                if b.zone and (b.zone == sel or string.lower(b.zone) == selLower) then
                    match = true
                elseif b.location and (b.location == sel or string.find(string.lower(b.location), selLower, 1, true)) then
                    match = true
                end
                if match then
                    table.insert(filtered, b)
                end
            end
        end
    end
    pane.PartTable:SetData(filtered)

    if pane.PartTitle then
        if sel then
            pane.PartTitle:SetText(string.format("Zone Participants: %s (%d bots)", sel, #filtered))
        else
            pane.PartTitle:SetText(string.format("Zone Participants: All Zones (%d bots)", #filtered))
        end
    end
end
