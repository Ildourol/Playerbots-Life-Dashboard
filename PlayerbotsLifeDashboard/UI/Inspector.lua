local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Inspector = {
    drawer = nil,
    currentGuid = nil,
}

LifeDashboard.Inspector = Inspector

function Inspector:Init(parent)
    local d = CreateFrame("Frame", "PlayerbotsLifeDashboardInspectorDrawer", parent)
    d:SetWidth(340)
    d:SetHeight(parent:GetHeight() - 72)
    d:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -40)
    d:SetFrameLevel(parent:GetFrameLevel() + 20)
    d:EnableMouse(true)
    d:Hide()
    LifeDashboard.Widgets:ApplyDarkBackdrop(d, 0.95, 0.9)
    LifeDashboard.InspectorDrawer = d
    self.drawer = d

    -- Header & Close
    local title = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -10)
    title:SetText(LifeDashboard.L and LifeDashboard.L.DRAWER_INSPECTOR or "Bot Inspector")

    local closeBtn = CreateFrame("Button", nil, d, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", d, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        if LifeDashboard.Window then
            LifeDashboard.Window:CloseDrawer()
        else
            d:Hide()
        end
    end)

    -- Bot Identity Line
    local nameFs = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    nameFs:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -36)
    nameFs:SetText("No Bot Selected")
    d.NameText = nameFs

    local infoFs = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    infoFs:SetPoint("TOPLEFT", nameFs, "BOTTOMLEFT", 0, -2)
    infoFs:SetText("Click a bot in the roster to inspect details.")
    d.InfoText = infoFs

    local coordFs = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    coordFs:SetPoint("TOPLEFT", infoFs, "BOTTOMLEFT", 0, -3)
    coordFs:SetText("Location: None")
    coordFs:SetJustifyH("LEFT")
    d.CoordText = coordFs

    -- Accordion Section 1: Ownership & Lease
    local leaseBox = CreateFrame("Frame", nil, d)
    leaseBox:SetWidth(316)
    leaseBox:SetHeight(70)
    leaseBox:SetPoint("TOPLEFT", coordFs, "BOTTOMLEFT", 0, -8)
    LifeDashboard.Widgets:ApplyCardBackdrop(leaseBox)

    local leaseTitle = leaseBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leaseTitle:SetPoint("TOPLEFT", leaseBox, "TOPLEFT", 6, -6)
    leaseTitle:SetText("Ownership & Token Lifecycle")

    local leaseDetails = leaseBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    leaseDetails:SetPoint("TOPLEFT", leaseTitle, "BOTTOMLEFT", 0, -4)
    leaseDetails:SetJustifyH("LEFT")
    leaseDetails:SetText("Lease State: None\nOwner: None\nReservation Expiry: N/A")
    d.LeaseDetails = leaseDetails

    -- Accordion Section 2: AI & Native Strategies
    local stratBox = CreateFrame("Frame", nil, d)
    stratBox:SetWidth(316)
    stratBox:SetHeight(72)
    stratBox:SetPoint("TOPLEFT", leaseBox, "BOTTOMLEFT", 0, -8)
    LifeDashboard.Widgets:ApplyCardBackdrop(stratBox)

    local stratTitle = stratBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stratTitle:SetPoint("TOPLEFT", stratBox, "TOPLEFT", 6, -6)
    stratTitle:SetText("Native AI Strategies")

    local stratDetails = stratBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stratDetails:SetPoint("TOPLEFT", stratTitle, "BOTTOMLEFT", 0, -4)
    stratDetails:SetJustifyH("LEFT")
    stratDetails:SetText("NonCombat: +stay,-follow,-grind,-rpg\nCombat: +pvp,+boost,+dps debuff")
    d.StratDetails = stratDetails

    -- Accordion Section 3: Timeline & Work Chronology
    local tlBox = CreateFrame("Frame", nil, d)
    tlBox:SetPoint("TOPLEFT", stratBox, "BOTTOMLEFT", 0, -8)
    tlBox:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -12, 68)
    LifeDashboard.Widgets:ApplyCardBackdrop(tlBox)

    local tlTitle = tlBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tlTitle:SetPoint("TOPLEFT", tlBox, "TOPLEFT", 6, -6)
    tlTitle:SetText("Action Timeline & Next Tasks")

    local tlDetails = tlBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tlDetails:SetPoint("TOPLEFT", tlTitle, "BOTTOMLEFT", 0, -6)
    tlDetails:SetPoint("BOTTOMRIGHT", tlBox, "BOTTOMRIGHT", -6, 6)
    tlDetails:SetJustifyH("LEFT")
    tlDetails:SetJustifyV("TOP")
    tlDetails:SetText("No queued or observed tasks recorded.")
    d.TimelineDetails = tlDetails

    -- ─── Bottom Action Bar (Target, Find, Pin, Whisper) ──────────────────────────
    local actionBar = CreateFrame("Frame", nil, d)
    actionBar:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 12, 10)
    actionBar:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -12, 10)
    actionBar:SetHeight(52)
    d.ActionBar = actionBar

    -- Row 1: Target, Find/Coords, Pin
    local targetBtn = CreateFrame("Button", "PlayerbotsLifeInspectorTargetBtn", actionBar, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    targetBtn:SetWidth(95)
    targetBtn:SetHeight(22)
    targetBtn:SetPoint("TOPLEFT", actionBar, "TOPLEFT", 0, 0)
    targetBtn:SetText("Target")
    targetBtn:SetAttribute("type", "macro")
    targetBtn:SetAttribute("macrotext", "")
    targetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Target Bot", 1, 1, 1)
        GameTooltip:AddLine("Executes secure /target command for this bot in the 3D world.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    targetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    d.TargetBtn = targetBtn

    local findBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    findBtn:SetWidth(105)
    findBtn:SetHeight(22)
    findBtn:SetPoint("LEFT", targetBtn, "RIGHT", 6, 0)
    findBtn:SetText("Find / Coords")
    findBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Find / Coordinates", 1, 1, 1)
        GameTooltip:AddLine("Prints bot location and coordinates to chat, and sets a map waypoint.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    findBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    findBtn:SetScript("OnClick", function()
        local guid = Inspector.currentGuid
        local bot = LifeDashboard.Store and LifeDashboard.Store.bots and LifeDashboard.Store.bots[guid]
        if not bot then return end

        local c = bot.coords
        if c and c.x and c.y then
            local msg = string.format("|cff33ccff[Life Dashboard]|r %s is at |cffffd000%s|r (X: %.1f, Y: %.1f, Z: %.1f)", bot.name, c.zone or bot.location or "World", c.x, c.y, c.z or 0)
            DEFAULT_CHAT_FRAME:AddMessage(msg)

            if SlashCmdList and SlashCmdList["TOMTOM_WAY"] then
                SlashCmdList["TOMTOM_WAY"](string.format("%.1f %.1f %s (%s)", c.x, c.y, bot.name, bot.location or ""))
            end
        else
            local msg = string.format("|cff33ccff[Life Dashboard]|r %s is located in |cffffd000%s|r [Activity: %s]", bot.name, bot.location or "World", bot.activity or "Active")
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
    end)
    d.FindBtn = findBtn

    local pinBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    pinBtn:SetWidth(104)
    pinBtn:SetHeight(22)
    pinBtn:SetPoint("LEFT", findBtn, "RIGHT", 6, 0)
    pinBtn:SetText("Pin ★")
    pinBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Pin to Watchlist", 1, 1, 1)
        GameTooltip:AddLine("Toggles priority pinning so this bot stays at the top of your lists.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    pinBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pinBtn:SetScript("OnClick", function()
        local guid = Inspector.currentGuid
        if not guid then return end
        local isWatched = LifeDashboard.Store:ToggleWatchlist(guid)
        local bot = LifeDashboard.Store.bots and LifeDashboard.Store.bots[guid]
        local botName = bot and bot.name or "Bot"

        if isWatched then
            pinBtn:SetText("|cffffd700★ Pinned|r")
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ccff[Life Dashboard]|r Added |cffffd000%s|r to Watchlist.", botName))
        else
            pinBtn:SetText("Pin ★")
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ccff[Life Dashboard]|r Removed |cffffd000%s|r from Watchlist.", botName))
        end

        if LifeDashboard.Overview and LifeDashboard.Overview.ApplyFilters then
            LifeDashboard.Overview:ApplyFilters()
        end
        if LifeDashboard.CityLife and LifeDashboard.CityLife.UpdateResidents then
            LifeDashboard.CityLife:UpdateResidents()
        end
        if LifeDashboard.PvPLife and LifeDashboard.PvPLife.UpdateParticipants then
            LifeDashboard.PvPLife:UpdateParticipants()
        end
    end)
    d.PinBtn = pinBtn

    -- Row 2: Whisper Bot, Quick Hint
    local whisperBtn = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
    whisperBtn:SetWidth(120)
    whisperBtn:SetHeight(22)
    whisperBtn:SetPoint("BOTTOMLEFT", actionBar, "BOTTOMLEFT", 0, 2)
    whisperBtn:SetText("Whisper Bot")
    whisperBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Whisper Bot", 1, 1, 1)
        GameTooltip:AddLine("Opens chat prompt to whisper commands or chat with this bot.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    whisperBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    whisperBtn:SetScript("OnClick", function()
        local guid = Inspector.currentGuid
        local bot = LifeDashboard.Store and LifeDashboard.Store.bots and LifeDashboard.Store.bots[guid]
        if not bot then return end

        if ChatFrame_OpenChat then
            ChatFrame_OpenChat("/w " .. bot.name .. " ")
        end
    end)
    d.WhisperBtn = whisperBtn

    local hintFs = actionBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hintFs:SetPoint("LEFT", whisperBtn, "RIGHT", 10, 0)
    hintFs:SetText("Target or monitor bot")
    d.HintFs = hintFs
end

function Inspector:DisplayBot(guid)
    self.currentGuid = guid
    local d = self.drawer
    if not d then return end

    local bot = LifeDashboard.Store and LifeDashboard.Store.bots and LifeDashboard.Store.bots[guid]
    if not bot then
        d.NameText:SetText("No Bot Selected")
        d.InfoText:SetText("Click a bot in the roster to inspect details.")
        d.CoordText:SetText("Location: None")
        d.LeaseDetails:SetText("Lease State: None\nModule Owner: None\nReservation Expiry: N/A")
        d.StratDetails:SetText("NonCombat: Default AI\nCombat: Default AI")
        d.TimelineDetails:SetText("No queued or observed tasks recorded.")
        d.PinBtn:SetText("Pin ★")
        if not InCombatLockdown() then
            d.TargetBtn:SetAttribute("macrotext", "")
        end
        return
    end

    local isWatched = LifeDashboard.Store:IsWatchlisted(guid)
    local star = isWatched and "|cffffd700★ |r" or ""
    local typeBadge = bot.isRealPlayer and "|cffffcc00[Player]|r " or "|cff00ff66[Bot]|r "
    d.NameText:SetText(star .. typeBadge .. bot.name)

    d.InfoText:SetText(string.format("Level %d %s | %s | %s",
        bot.level or 80,
        string.upper(bot.faction or "ALLIANCE"),
        string.upper(bot.module or "CITY"),
        bot.status or "Active"))

    local c = bot.coords
    if c and c.x and c.y then
        d.CoordText:SetText(string.format("|cff33ccffLocation:|r %s\n|cffaaaaaaCoords:|r X: %.1f, Y: %.1f, Z: %.1f",
            bot.location or c.zone or "World", c.x, c.y, c.z or 0))
    else
        d.CoordText:SetText(string.format("|cff33ccffLocation:|r %s", bot.location or "Unknown Zone"))
    end

    d.LeaseDetails:SetText(string.format("Module Owner: %s Life\nRole: %s\nActivity: %s\nStatus: %s (%.1fs ago)",
        string.upper(bot.module or "city"),
        bot.role or "Autonomous Actor",
        bot.activity or "None",
        bot.status or "Active",
        GetTime() - (bot.updatedAt or GetTime())))

    -- AI Strategies
    local stratText
    if bot.module == "city" then
        stratText = string.format("Role: %s\nNonCombat: +stay,+rpg,-follow\nCombat: +duel,+defend", bot.role or "Flex")
    elseif bot.module == "pvp" then
        stratText = string.format("Zone: %s\nCombat: +pvp,+boost,+dps\nNonCombat: +stay,-grind", bot.zone or "PvP Zone")
    else
        stratText = "Player entity: Natural human control."
    end
    d.StratDetails:SetText(stratText)

    -- Pin button text
    d.PinBtn:SetText(isWatched and "|cffffd700★ Pinned|r" or "Pin ★")

    -- Target button macro
    if not InCombatLockdown() then
        d.TargetBtn:SetAttribute("macrotext", "/target " .. bot.name)
    end

    -- Rebuild Timeline Text
    local timeline = (LifeDashboard.Timeline and LifeDashboard.Timeline.GetBotTimeline) and LifeDashboard.Timeline:GetBotTimeline(guid) or {}
    local lines = {}
    for i, item in ipairs(timeline) do
        local badge = LifeDashboard.Clock and LifeDashboard.Clock:FormatTruthBadge(item.truthClass) or item.truthClass
        local due = LifeDashboard.Clock and LifeDashboard.Clock:FormatDueTime(item.dueMs, item.truthClass) or tostring(item.dueMs)
        table.insert(lines, string.format("%d. %s %s\n   |cffaaaaaaDue: %s (%s)|r", i, badge, item.title, due, item.source))
    end
    if #lines == 0 then
        if bot.lastAction or bot.nextTask then
            d.TimelineDetails:SetText(string.format("Current Action:\n  %s\n\nNext Task:\n  %s\n\nDue in: %s",
                bot.lastAction or "None",
                bot.nextTask or "None",
                LifeDashboard.Clock:FormatDueTime(bot.dueMs or 0, bot.truthClass or "Observed")))
        else
            d.TimelineDetails:SetText("No queued or observed tasks recorded.")
        end
    else
        d.TimelineDetails:SetText(table.concat(lines, "\n\n"))
    end
end
