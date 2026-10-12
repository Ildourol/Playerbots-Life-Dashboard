local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Settings = {
    drawer = nil,
    initialized = false,
}

LifeDashboard.Settings = Settings

function Settings:Init(parent)
    if self.initialized then return end
    self.initialized = true

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
    desc:SetText("Module Configuration Defaults (Unverified / Awaiting Server CONFIG)")
    d.Desc = desc

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
        if item.fromServer then
            row.cells[3]:SetText("|cff00ff66Live|r")
        else
            row.cells[3]:SetText("|cff888888Default|r")
        end
    end)
    cfgTable:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -6)
    d.Table = cfgTable

    self:PopulateDefaults()
end

function Settings:PopulateDefaults()
    local defaults = {
        { key = "CityLife.Enable", value = "1", fromServer = false },
        { key = "CityLife.Population.BorrowPercent", value = "10%", fromServer = false },
        { key = "CityLife.Population.FixedCount", value = "100", fromServer = false },
        { key = "CityLife.Population.MaxTotal", value = "120", fromServer = false },
        { key = "CityLife.Population.Distribution", value = "scaled", fromServer = false },
        { key = "CityLife.Time.Enable", value = "1", fromServer = false },
        { key = "CityLife.Behaviour.Relocate", value = "1", fromServer = false },
        { key = "CityLife.Activities.AFK.Enable", value = "1", fromServer = false },
        { key = "CityLife.Chat.ScriptedConversations", value = "1", fromServer = false },
        { key = "CityLife.Weight.WanderDistrict", value = "30", fromServer = false },
        { key = "CityLife.Weight.SitInTavern", value = "20", fromServer = false },
        { key = "CityLife.Weight.RandomEmote", value = "15", fromServer = false },
        { key = "CityLife.Weight.VisitAuctionHouse", value = "10", fromServer = false },
        { key = "CityLife.Weight.VisitMailbox", value = "10", fromServer = false },
        { key = "CityLife.Weight.BuyFood", value = "10", fromServer = false },
        { key = "CityLife.Weight.VisitTrainer", value = "8", fromServer = false },
        { key = "CityLife.Weight.DrinkInTavern", value = "10", fromServer = false },
        { key = "CityLife.Weight.WalkCityWalls", value = "10", fromServer = false },
        { key = "CityLife.Weight.ReturnToInn", value = "15", fromServer = false },
        { key = "PvPLife.Enable", value = "1", fromServer = false },
        { key = "PvPLife.Events.MaxActive", value = "4", fromServer = false },
        { key = "PvPLife.Population.BorrowPercent", value = "10%", fromServer = false },
        { key = "PvPLife.Population.FixedCount", value = "100", fromServer = false },
        { key = "PvPLife.Duel.PairLimit", value = "12", fromServer = false },
        { key = "PvPLife.Duel.RelocateCooldownSeconds", value = "20", fromServer = false },
        { key = "PvPLife.Duel.CooldownSeconds", value = "45", fromServer = false },
        { key = "PvPLife.Duel.AlwaysActive", value = "1", fromServer = false },
        { key = "PvPLife.Movement.UseMovePoint", value = "1", fromServer = false },
        { key = "PvPLife.ReactiveRaidResponse.Enable", value = "1", fromServer = false },
        { key = "PvPLife.ReactiveRaidResponse.LoginOfflineBots", value = "0", fromServer = false },
        { key = "PvPLife.Audit.Enable", value = "1", fromServer = false },
    }

    -- If server has transmitted CONFIG items, overlay them as authoritative
    if LifeDashboard.Store and LifeDashboard.Store.config then
        for _, item in ipairs(defaults) do
            if LifeDashboard.Store.config[item.key] ~= nil then
                item.value = LifeDashboard.Store.config[item.key]
                item.fromServer = true
            end
        end
    end

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
