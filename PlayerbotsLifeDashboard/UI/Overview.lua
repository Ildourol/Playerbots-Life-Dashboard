local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Overview = {}
LifeDashboard.Overview = Overview

local CLASS_COLORS = {
    [1] = "c69b6d", -- Warrior
    [2] = "f48cba", -- Paladin
    [3] = "aad372", -- Hunter
    [4] = "fff468", -- Rogue
    [5] = "ffffff", -- Priest
    [6] = "c41e3a", -- Death Knight
    [7] = "0070dd", -- Shaman
    [8] = "3fc7eb", -- Mage
    [9] = "8788ee", -- Warlock
    [11] = "ff7c0a", -- Druid
}

function Overview:Init(parent)
    local pane = CreateFrame("Frame", "PlayerbotsLifeDashboardOverviewPane", parent)
    pane:SetAllPoints(parent)
    LifeDashboard.OverviewPane = pane

    -- ─── Top Stat Cards ──────────────────────────────────────────────────────────
    local cardWidth = 230
    local cardHeight = 65
    local cardY = -4

    local c1 = LifeDashboard.Widgets:CreateStatCard(pane, cardWidth, cardHeight, LifeDashboard.L.CARD_TOTAL_POOL)
    c1:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, cardY)
    pane.CardTotal = c1

    local c2 = LifeDashboard.Widgets:CreateStatCard(pane, cardWidth, cardHeight, LifeDashboard.L.CARD_CITY_CAPACITY)
    c2:SetPoint("LEFT", c1, "RIGHT", 14, 0)
    pane.CardCity = c2

    local c3 = LifeDashboard.Widgets:CreateStatCard(pane, cardWidth, cardHeight, LifeDashboard.L.CARD_PVP_CAPACITY)
    c3:SetPoint("LEFT", c2, "RIGHT", 14, 0)
    pane.CardPvP = c3

    local c4 = LifeDashboard.Widgets:CreateStatCard(pane, cardWidth, cardHeight, LifeDashboard.L.CARD_FREE_CAPACITY)
    c4:SetPoint("LEFT", c3, "RIGHT", 14, 0)
    pane.CardFree = c4

    -- ─── Filter & Search Bar ─────────────────────────────────────────────────────
    local filterBar = CreateFrame("Frame", nil, pane)
    filterBar:SetWidth(pane:GetWidth())
    filterBar:SetHeight(30)
    filterBar:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -(cardHeight + 14))

    local searchBox = LifeDashboard.Widgets:CreateSearchBox(filterBar, 220, LifeDashboard.L.SEARCH_PLACEHOLDER, function(text)
        Overview:ApplyFilters()
    end)
    searchBox:SetPoint("LEFT", filterBar, "LEFT", 0, 0)
    pane.SearchBox = searchBox

    -- Filter Buttons: ALL, BOTS, PLAYERS, CITY, PVP, WATCHLIST
    pane.selectedModuleFilter = "ALL"
    local btnAll = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    btnAll:SetWidth(45)
    btnAll:SetHeight(22)
    btnAll:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
    btnAll:SetText("All")
    btnAll:SetScript("OnClick", function()
        pane.selectedModuleFilter = "ALL"
        Overview:ApplyFilters()
    end)

    local btnBots = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    btnBots:SetWidth(55)
    btnBots:SetHeight(22)
    btnBots:SetPoint("LEFT", btnAll, "RIGHT", 5, 0)
    btnBots:SetText("Bots")
    btnBots:SetScript("OnClick", function()
        pane.selectedModuleFilter = "BOTS"
        Overview:ApplyFilters()
    end)

    local btnPlayers = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    btnPlayers:SetWidth(65)
    btnPlayers:SetHeight(22)
    btnPlayers:SetPoint("LEFT", btnBots, "RIGHT", 5, 0)
    btnPlayers:SetText("Players")
    btnPlayers:SetScript("OnClick", function()
        pane.selectedModuleFilter = "PLAYERS"
        Overview:ApplyFilters()
    end)

    local btnCity = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    btnCity:SetWidth(70)
    btnCity:SetHeight(22)
    btnCity:SetPoint("LEFT", btnPlayers, "RIGHT", 5, 0)
    btnCity:SetText("City Life")
    btnCity:SetScript("OnClick", function()
        pane.selectedModuleFilter = "city"
        Overview:ApplyFilters()
    end)

    local btnPvP = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    btnPvP:SetWidth(70)
    btnPvP:SetHeight(22)
    btnPvP:SetPoint("LEFT", btnCity, "RIGHT", 5, 0)
    btnPvP:SetText("PvP Life")
    btnPvP:SetScript("OnClick", function()
        pane.selectedModuleFilter = "pvp"
        Overview:ApplyFilters()
    end)

    local btnWatch = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
    btnWatch:SetWidth(85)
    btnWatch:SetHeight(22)
    btnWatch:SetPoint("LEFT", btnPvP, "RIGHT", 5, 0)
    btnWatch:SetText("|cffffd700★ Watch|r")
    btnWatch:SetScript("OnClick", function()
        pane.selectedModuleFilter = "WATCHLIST"
        Overview:ApplyFilters()
    end)

    -- ─── Virtualized Master Bot Table ───────────────────────────────────────────
    local columns = {
        { name = LifeDashboard.L.COL_BOT, width = 130 },
        { name = LifeDashboard.L.COL_MODULE, width = 70 },
        { name = LifeDashboard.L.COL_LOCATION, width = 110 },
        { name = LifeDashboard.L.COL_ACTIVITY, width = 130 },
        { name = LifeDashboard.L.COL_LAST_ACTION, width = 140 },
        { name = LifeDashboard.L.COL_NEXT_TASK, width = 180 },
        { name = LifeDashboard.L.COL_DUE, width = 110 },
        { name = LifeDashboard.L.COL_STATUS, width = 80 },
    }

    local tableFrame = LifeDashboard.Widgets:CreateVirtualizedTable(pane, 990, 420, 24, columns, function(row, item)
        local cColor = CLASS_COLORS[item.classId] or "ffffff"
        local isWatched = LifeDashboard.Store and LifeDashboard.Store:IsWatchlisted(item.guid)
        local watchPrefix = isWatched and "|cffffd700★ |r" or ""
        local tag = item.isRealPlayer and "|cffffcc00[P]|r " or "|cff00ff66[B]|r "
        row.cells[1]:SetText(string.format("%s%s|cff%s%s|r", watchPrefix, tag, cColor, item.name))

        if item.module == "city" then
            row.cells[2]:SetText("|cff33ccffCity|r")
        elseif item.module == "pvp" then
            row.cells[2]:SetText("|cffff3333PvP|r")
        else
            row.cells[2]:SetText("|cffffcc00World|r")
        end

        row.cells[3]:SetText(item.location or "")
        row.cells[4]:SetText(item.activity or "")
        row.cells[5]:SetText(item.lastAction or "|cff666666--|r")
        row.cells[6]:SetText(item.nextTask or "|cff666666--|r")

        local dueText = LifeDashboard.Clock:FormatDueTime(item.dueMs, item.truthClass)
        row.cells[7]:SetText(dueText)
        row.cells[8]:SetText(item.status or "Active")

        row:SetScript("OnClick", function()
            LifeDashboard.Store.selectedBotGuid = item.guid
            LifeDashboard.Window:OpenDrawer("inspector")
            if LifeDashboard.Inspector and LifeDashboard.Inspector.DisplayBot then
                LifeDashboard.Inspector:DisplayBot(item.guid)
            end
        end)
    end)
    tableFrame:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -8)
    pane.Table = tableFrame

    -- Listen to store updates
    LifeDashboard.Store:RegisterListener("ON_CAPACITY_UPDATED", function(cap)
        Overview:UpdateCards(cap)
    end)
    LifeDashboard.Store:RegisterListener("ON_ROSTER_UPDATED", function()
        Overview:ApplyFilters()
    end)
end

function Overview:UpdateCards(cap)
    local pane = LifeDashboard.OverviewPane
    if not pane then return end
    pane.CardTotal.Value:SetText(tostring(cap.total))
    pane.CardCity.Value:SetText(string.format("%d / %d", cap.cityActive, cap.cityTarget))
    pane.CardPvP.Value:SetText(string.format("%d / %d", cap.pvpActive, cap.pvpTarget))
    pane.CardFree.Value:SetText(tostring(cap.free))
end

function Overview:ApplyFilters()
    local pane = LifeDashboard.OverviewPane
    if not pane or not pane.Table then return end

    local search = string.lower(pane.SearchBox:GetText() or "")
    local modFilter = pane.selectedModuleFilter or "ALL"

    local filtered = {}
    for _, bot in ipairs(LifeDashboard.Store.botList or {}) do
        local matchesMod = false
        if modFilter == "ALL" then
            matchesMod = true
        elseif modFilter == "BOTS" then
            matchesMod = not bot.isRealPlayer
        elseif modFilter == "PLAYERS" then
            matchesMod = (bot.isRealPlayer == true)
        elseif modFilter == "WATCHLIST" then
            matchesMod = LifeDashboard.Store:IsWatchlisted(bot.guid)
        elseif modFilter == "city" then
            matchesMod = (bot.module == "city" and not bot.isRealPlayer)
        elseif modFilter == "pvp" then
            matchesMod = (bot.module == "pvp" and not bot.isRealPlayer)
        end

        local matchesSearch = true
        if search ~= "" then
            matchesSearch = string.find(string.lower(bot.name), search, 1, true) or
                            (bot.location and string.find(string.lower(bot.location), search, 1, true)) or
                            (bot.activity and string.find(string.lower(bot.activity), search, 1, true)) or
                            (bot.role and string.find(string.lower(bot.role), search, 1, true))
        end
        if matchesMod and matchesSearch then
            table.insert(filtered, bot)
        end
    end

    pane.Table:SetData(filtered)
end
