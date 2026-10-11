local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Settings = {
    drawer = nil,
}

LifeDashboard.Settings = Settings

function Settings:Init(parent)
    local d = CreateFrame("Frame", "PlayerbotsLifeDashboardSettingsDrawer", parent)
    d:SetWidth(360)
    d:SetHeight(parent:GetHeight() - 72)
    d:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -40)
    d:SetFrameLevel(parent:GetFrameLevel() + 20)
    d:EnableMouse(true)
    d:Hide()
    LifeDashboard.Widgets:ApplyDarkBackdrop(d, 0.95, 0.9)
    LifeDashboard.SettingsDrawer = d
    self.drawer = d

    local title = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -10)
    title:SetText(LifeDashboard.L and LifeDashboard.L.DRAWER_SETTINGS or "Configuration")

    local closeBtn = CreateFrame("Button", nil, d, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", d, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        if LifeDashboard.Window then
            LifeDashboard.Window:CloseDrawer()
        else
            d:Hide()
        end
    end)

    local desc = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    desc:SetText("Effective Module Settings & Defaults (Read-Only)")

    local searchBox = LifeDashboard.Widgets:CreateSearchBox(d, 336, "Filter configuration keys...", function(text)
        Settings:FilterConfig(text)
    end)
    searchBox:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -8)
    d.SearchBox = searchBox

    local cfgCols = {
        { name = "Setting Key", width = 190 },
        { name = "Effective", width = 80 },
        { name = "State", width = 60 },
    }

    local cfgTable = LifeDashboard.Widgets:CreateVirtualizedTable(d, 340, d:GetHeight() - 95, 24, cfgCols, function(row, item)
        row.cells[1]:SetText(item.key)
        row.cells[2]:SetText(tostring(item.value))
        if item.supported then
            row.cells[3]:SetText("|cff00ff66OK|r")
        else
            row.cells[3]:SetText("|cffff9900Partial|r")
        end
    end)
    cfgTable:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -6)
    d.Table = cfgTable

    self:PopulateDefaults()
end

function Settings:PopulateDefaults()
    local defaults = {
        { key = "CityLife.Enable", value = "1", supported = true },
        { key = "CityLife.Population.BorrowPercent", value = "10%", supported = true },
        { key = "CityLife.Population.FixedCount", value = "100", supported = true },
        { key = "CityLife.Population.MaxTotal", value = "120", supported = true },
        { key = "CityLife.Population.Distribution", value = "scaled", supported = true },
        { key = "CityLife.Time.Enable", value = "1", supported = true },
        { key = "CityLife.Behaviour.Relocate", value = "1", supported = true },
        { key = "CityLife.Activities.AFK.Enable", value = "1", supported = true },
        { key = "CityLife.Duels.AllowPlayerChallenge", value = "1", supported = true },
        { key = "PvPLife.Enable", value = "1", supported = true },
        { key = "PvPLife.Events.MaxActive", value = "4", supported = true },
        { key = "PvPLife.Population.BorrowPercent", value = "10%", supported = true },
        { key = "PvPLife.Population.FixedCount", value = "100", supported = true },
        { key = "PvPLife.Duel.PairLimit", value = "12", supported = true },
        { key = "PvPLife.Movement.UseMovePoint", value = "1", supported = true },
        { key = "PvPLife.ReactiveRaidResponse.Enable", value = "1", supported = true },
        { key = "PvPLife.ReactiveRaidResponse.LoginOfflineBots", value = "0", supported = true },
        { key = "PvPLife.Audit.Enable", value = "1", supported = true },
    }
    self.configList = defaults
    if self.drawer and self.drawer.Table then
        self.drawer.Table:SetData(defaults)
    end
end

function Settings:FilterConfig(search)
    if not self.configList then return end
    search = string.lower(search or "")
    local filtered = {}
    for _, item in ipairs(self.configList) do
        if search == "" or string.find(string.lower(item.key), search, 1, true) then
            table.insert(filtered, item)
        end
    end
    if self.drawer and self.drawer.Table then
        self.drawer.Table:SetData(filtered)
    end
end
