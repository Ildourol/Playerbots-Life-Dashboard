local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local CityLife = {}
LifeDashboard.CityLife = CityLife

function CityLife:Init(parent)
    local pane = CreateFrame("Frame", "PlayerbotsLifeDashboardCityPane", parent)
    pane:SetAllPoints(parent)
    pane:Hide()
    LifeDashboard.CityLifePane = pane

    -- ─── Left Side: Hub Catalog ──────────────────────────────────────────────────
    local hubPanel = CreateFrame("Frame", nil, pane)
    hubPanel:SetWidth(360)
    hubPanel:SetHeight(480)
    hubPanel:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -6)
    LifeDashboard.Widgets:ApplyDarkBackdrop(hubPanel, 0.5, 0.4)

    local hubTitle = hubPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hubTitle:SetPoint("TOPLEFT", hubPanel, "TOPLEFT", 10, -8)
    hubTitle:SetText("City Life Hubs & Districts")

    local hubCols = {
        { name = "Hub", width = 110 },
        { name = "Target", width = 60 },
        { name = "Active", width = 60 },
        { name = "POIs", width = 50 },
        { name = "Scale", width = 60 },
    }

    local hubTable = LifeDashboard.Widgets:CreateVirtualizedTable(hubPanel, 350, 430, 26, hubCols, function(row, item)
        row.cells[1]:SetText(item.name)
        row.cells[2]:SetText(tostring(item.target))
        row.cells[3]:SetText(string.format("%d (+%d)", item.active, item.pending or 0))
        row.cells[4]:SetText(tostring(item.poiCount or 0))
        row.cells[5]:SetText(string.format("%.1fx", item.timeMult or 1.0))
        row:SetScript("OnClick", function()
            CityLife:SelectHub(item.name)
        end)
    end)
    hubTable:SetPoint("TOPLEFT", hubPanel, "TOPLEFT", 5, -34)
    pane.HubTable = hubTable

    -- ─── Right Side: City Residents & Activities ─────────────────────────────────
    local resPanel = CreateFrame("Frame", nil, pane)
    resPanel:SetPoint("TOPLEFT", hubPanel, "TOPRIGHT", 14, 0)
    resPanel:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 6)
    LifeDashboard.Widgets:ApplyDarkBackdrop(resPanel, 0.5, 0.4)

    local resTitle = resPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resTitle:SetPoint("TOPLEFT", resPanel, "TOPLEFT", 10, -8)
    resTitle:SetText("Active Residents & Activities")
    pane.ResTitle = resTitle

    local resCols = {
        { name = "Resident", width = 130 },
        { name = "Role", width = 110 },
        { name = "Activity", width = 130 },
        { name = "Last Action", width = 130 },
        { name = "Due", width = 100 },
    }

    local resTable = LifeDashboard.Widgets:CreateVirtualizedTable(resPanel, 610, 430, 26, resCols, function(row, item)
        local isWatched = LifeDashboard.Store and LifeDashboard.Store:IsWatchlisted(item.guid)
        local star = isWatched and "|cffffd700★ |r" or ""
        row.cells[1]:SetText(star .. item.name)
        row.cells[2]:SetText(item.role or "Flex")
        row.cells[3]:SetText(item.activity or "")
        row.cells[4]:SetText(item.lastAction or "--")
        row.cells[5]:SetText(LifeDashboard.Clock:FormatDueTime(item.dueMs, item.truthClass))
        row:SetScript("OnClick", function()
            LifeDashboard.Store.selectedBotGuid = item.guid
            LifeDashboard.Window:OpenDrawer("inspector")
            if LifeDashboard.Inspector and LifeDashboard.Inspector.DisplayBot then
                LifeDashboard.Inspector:DisplayBot(item.guid)
            end
        end)
    end)
    resTable:SetPoint("TOPLEFT", resPanel, "TOPLEFT", 5, -34)
    pane.ResTable = resTable

    -- Listen to store updates
    LifeDashboard.Store:RegisterListener("ON_ROSTER_UPDATED", function()
        CityLife:UpdateData()
    end)
    LifeDashboard.Store:RegisterListener("ON_CONNECTED", function()
        CityLife:UpdateData()
    end)
end

function CityLife:SelectHub(hubName)
    if self.selectedHub == hubName then
        self.selectedHub = nil -- Click again to deselect filter
    else
        self.selectedHub = hubName
    end
    self:UpdateResidents()
end

function CityLife:UpdateData()
    local pane = LifeDashboard.CityLifePane
    if not pane then return end

    local hubs = LifeDashboard.Store.cityHubList or {}
    pane.HubTable:SetData(hubs)

    self:UpdateResidents()
end

function CityLife:UpdateResidents()
    local pane = LifeDashboard.CityLifePane
    if not pane then return end

    local filtered = {}
    local sel = self.selectedHub
    for _, b in ipairs(LifeDashboard.Store.botList or {}) do
        if b.module == "city" then
            local matchesHub = true
            if sel and sel ~= "" then
                matchesHub = (b.hub == sel) or (b.location and string.find(string.lower(b.location), string.lower(sel), 1, true))
            end
            if matchesHub then
                table.insert(filtered, b)
            end
        end
    end

    if pane.ResTitle then
        local titleStr = sel and ("Active Residents: " .. sel .. " (" .. #filtered .. " bots)") or ("All Active City Residents (" .. #filtered .. " bots)")
        pane.ResTitle:SetText(titleStr)
    end

    pane.ResTable:SetData(filtered)
end
