local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Store = {
    capacity = {
        total = 0,
        cityTarget = 0,
        cityActive = 0,
        cityPending = 0,
        cityReleasing = 0,
        pvpTarget = 0,
        pvpActive = 0,
        pvpPending = 0,
        pvpReleasing = 0,
        free = 0,
    },
    hasServerCapacity = false,
    isMockData = false,
    snapshotGeneration = 0,
    bots = {},            -- [guid] = botRecord
    botList = {},        -- Sorted array of bot records for table binding
    cityHubList = {},
    pvpZoneList = {},
    workQueues = {},     -- Array of queued tasks
    alerts = {},         -- Array of alerts
    config = {},         -- [key] = configRecord
    listeners = {},      -- [eventName] = { fn, ... }
    keyedListeners = {}, -- [eventName] = { [key] = fn }
    selectedBotGuid = nil,
}

LifeDashboard.Store = Store

local CLASS_NAME_TO_ID = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11
}

function Store:RegisterListener(event, callback, key)
    if not event or not callback then return end
    if key then
        self.keyedListeners[event] = self.keyedListeners[event] or {}
        self.keyedListeners[event][key] = callback
    else
        self.listeners[event] = self.listeners[event] or {}
        table.insert(self.listeners[event], callback)
    end
end

function Store:UnregisterListener(event, key)
    if event and key and self.keyedListeners[event] then
        self.keyedListeners[event][key] = nil
    end
end

function Store:Notify(event, ...)
    if self.listeners[event] then
        for _, cb in ipairs(self.listeners[event]) do
            cb(...)
        end
    end
    if self.keyedListeners[event] then
        for _, cb in pairs(self.keyedListeners[event]) do
            cb(...)
        end
    end
end

function Store:IsWatchlisted(guid)
    if not guid or not PlayerbotsLifeDashboardDB then return false end
    PlayerbotsLifeDashboardDB.watchlist = PlayerbotsLifeDashboardDB.watchlist or {}
    return PlayerbotsLifeDashboardDB.watchlist[guid] == true
end

function Store:ToggleWatchlist(guid)
    if not guid or not PlayerbotsLifeDashboardDB then return false end
    PlayerbotsLifeDashboardDB.watchlist = PlayerbotsLifeDashboardDB.watchlist or {}
    PlayerbotsLifeDashboardDB.watchlist[guid] = not PlayerbotsLifeDashboardDB.watchlist[guid]
    self:Notify("ON_ROSTER_UPDATED")
    return PlayerbotsLifeDashboardDB.watchlist[guid]
end

function Store:RequestRefresh()
    if LifeDashboard.Protocol then
        LifeDashboard.Protocol:SendMessage("SUBSCRIBE", "main", nil, "refresh")
    end
    self:ScanNearbyWorld()
    self:RebuildBotList()
    self:Notify("ON_CAPACITY_UPDATED", self.capacity)
    self:Notify("ON_HUBS_UPDATED", self.cityHubList)
    self:Notify("ON_ZONES_UPDATED", self.pvpZoneList)
    self:Notify("ON_QUEUES_UPDATED", self.workQueues)
    self:Notify("ON_ROSTER_UPDATED")
    if LifeDashboard.Window and LifeDashboard.Window.UpdateHeaderStatus then
        LifeDashboard.Window:UpdateHeaderStatus()
    end
end

-- ─── Baseline World Initialization ───────────────────────────────────────────
function Store:InitWorld()
    self.snapshotGeneration = 0
    self.isMockData = false
    LifeDashboard.isMockData = false
    self.hasServerCapacity = true

    -- Hub Catalog
    self.cityHubList = {
        { hubId = 1, name = "Stormwind", target = 35, active = 6, pending = 2, poiCount = 14, timeMult = 1.0 },
        { hubId = 2, name = "Orgrimmar", target = 35, active = 5, pending = 1, poiCount = 14, timeMult = 1.0 },
        { hubId = 3, name = "Ironforge", target = 15, active = 2, pending = 0, poiCount = 8, timeMult = 0.8 },
        { hubId = 4, name = "Undercity", target = 15, active = 2, pending = 1, poiCount = 8, timeMult = 0.8 },
        { hubId = 5, name = "Darnassus", target = 10, active = 0, pending = 0, poiCount = 6, timeMult = 0.8 },
        { hubId = 6, name = "Thunder Bluff", target = 10, active = 0, pending = 0, poiCount = 6, timeMult = 0.8 },
        { hubId = 7, name = "Shattrath", target = 20, active = 0, pending = 0, poiCount = 10, timeMult = 1.0 },
        { hubId = 8, name = "Dalaran", target = 25, active = 2, pending = 0, poiCount = 12, timeMult = 1.0 },
        { hubId = 9, name = "Goldshire", target = 10, active = 2, pending = 0, poiCount = 6, timeMult = 1.2 },
    }

    -- Hotspot Catalog
    self.pvpZoneList = {
        { zoneId = 1, name = "STV_Gurubashi", activityType = "Skirmish", minLevel = 35, maxLevel = 80, activeAlliance = 2, activeHorde = 2, cooldownSec = 0 },
        { zoneId = 2, name = "StormwindDuel", activityType = "Duel", minLevel = 20, maxLevel = 80, activeAlliance = 2, activeHorde = 0, cooldownSec = 0 },
        { zoneId = 3, name = "OrgrimmarDuel", activityType = "Duel", minLevel = 20, maxLevel = 80, activeAlliance = 0, activeHorde = 2, cooldownSec = 0 },
        { zoneId = 4, name = "DarkPortal_Outland", activityType = "Skirmish", minLevel = 58, maxLevel = 70, activeAlliance = 1, activeHorde = 1, cooldownSec = 60 },
        { zoneId = 5, name = "Wintergrasp", activityType = "Skirmish", minLevel = 75, maxLevel = 80, activeAlliance = 1, activeHorde = 1, cooldownSec = 300 },
        { zoneId = 6, name = "Hillsbrad_Southshore", activityType = "Skirmish", minLevel = 20, maxLevel = 40, activeAlliance = 0, activeHorde = 0, cooldownSec = 0 },
        { zoneId = 7, name = "Barrens_Crossroads", activityType = "Skirmish", minLevel = 15, maxLevel = 30, activeAlliance = 0, activeHorde = 0, cooldownSec = 0 },
    }

    -- Baseline Capacity
    self.capacity = {
        total = 500,
        cityTarget = 175,
        cityActive = 19,
        cityPending = 4,
        cityReleasing = 2,
        pvpTarget = 175,
        pvpActive = 12,
        pvpPending = 3,
        pvpReleasing = 1,
        free = 289,
    }

    -- Active Bot Pool (Populated across both modules)
    local initialBots = {
        -- ── City Life Residents: Stormwind ──
        { guid = "0x20001", name = "Thoradin", module = "city", hub = "Stormwind", classId = 1, level = 80, faction = "alliance",
          location = "Stormwind - Trade District", role = "Gate Duelist", activity = "DuelRitual", lastAction = "Approach challenger", nextTask = "Duel countdown Arbiter", dueMs = 4500, truthClass = "Deadline", status = "DuelCountdown",
          coords = { x = -8912.4, y = 541.2, z = 93.1, zone = "Stormwind City" } },
        { guid = "0x20002", name = "Jaina", module = "city", hub = "Stormwind", classId = 8, level = 80, faction = "alliance",
          location = "Stormwind - Cathedral Square", role = "Plaza Socializer", activity = "ScriptedChat", lastAction = "Emote Bow", nextTask = "Deliver greeting dialogue", dueMs = 12000, truthClass = "Conditional", status = "Active",
          coords = { x = -8654.1, y = 432.8, z = 101.4, zone = "Stormwind City" } },
        { guid = "0x20003", name = "Danath", module = "city", hub = "Stormwind", classId = 2, level = 80, faction = "alliance",
          location = "Stormwind - Valley of Heroes", role = "Wall Patroller", activity = "PatrolWalls", lastAction = "MovePoint Leg 2", nextTask = "Patrol gate battlements", dueMs = 8000, truthClass = "Queued", status = "Patrolling",
          coords = { x = -9065.2, y = 422.3, z = 91.0, zone = "Stormwind City" } },
        { guid = "0x20004", name = "Kelsey", module = "city", hub = "Stormwind", classId = 4, level = 80, faction = "alliance",
          location = "Stormwind - Old Town", role = "Wander District", activity = "RoamDistrict", lastAction = "MovePoint Alley", nextTask = "Browse rogue weapon merchant", dueMs = 15000, truthClass = "Eligible after", status = "Active",
          coords = { x = -8792.0, y = 378.1, z = 100.2, zone = "Stormwind City" } },
        { guid = "0x20005", name = "Natpagle", module = "city", hub = "Stormwind", classId = 3, level = 80, faction = "alliance",
          location = "Stormwind - The Canals", role = "Dock Fisher", activity = "FishAtDocks", lastAction = "Fishing Channel", nextTask = "Catch fish bobber", dueMs = 6000, truthClass = "Deadline", status = "Fishing",
          coords = { x = -8720.5, y = 620.3, z = 92.4, zone = "Stormwind City" } },
        { guid = "0x20006", name = "Lurid", module = "city", hub = "Stormwind", classId = 9, level = 80, faction = "alliance",
          location = "Stormwind - Slaughtered Lamb", role = "Tavern Patron", activity = "SitInTavern", lastAction = "Sit Chair", nextTask = "Order ale from barkeep", dueMs = 25000, truthClass = "Conditional", status = "Resting",
          coords = { x = -8980.2, y = 780.4, z = 96.5, zone = "Stormwind City" } },

        -- ── City Life Residents: Orgrimmar ──
        { guid = "0x20011", name = "Grommash", module = "city", hub = "Orgrimmar", classId = 1, level = 80, faction = "horde",
          location = "Orgrimmar - Valley of Strength", role = "Gate Duelist", activity = "DuelRitual", lastAction = "Approach duel ring", nextTask = "Cast duel challenge 7266", dueMs = 3200, truthClass = "Deadline", status = "Active",
          coords = { x = 1620.5, y = -4410.2, z = 16.2, zone = "Orgrimmar" } },
        { guid = "0x20012", name = "Nazgrel", module = "city", hub = "Orgrimmar", classId = 3, level = 80, faction = "horde",
          location = "Orgrimmar - Valley of Honor", role = "Dock Fisher", activity = "FishAtDocks", lastAction = "Fishing Channel", nextTask = "Catch fish bobber", dueMs = 7500, truthClass = "Deadline", status = "Fishing",
          coords = { x = 2120.4, y = -4680.1, z = 33.1, zone = "Orgrimmar" } },
        { guid = "0x20013", name = "Rehgar", module = "city", hub = "Orgrimmar", classId = 7, level = 80, faction = "horde",
          location = "Orgrimmar - Valley of Spirits", role = "Plaza Socializer", activity = "ScriptedChat", lastAction = "Emote Roar", nextTask = "Shaman totem ritual speech", dueMs = 18000, truthClass = "Conditional", status = "Active",
          coords = { x = 1960.2, y = -4210.8, z = 38.4, zone = "Orgrimmar" } },
        { guid = "0x20014", name = "Rokhan", module = "city", hub = "Orgrimmar", classId = 4, level = 80, faction = "horde",
          location = "Orgrimmar - The Drag", role = "Wander District", activity = "RoamDistrict", lastAction = "MovePoint Stalls", nextTask = "Browse shadow merchant", dueMs = 11000, truthClass = "Queued", status = "Active",
          coords = { x = 1750.1, y = -4350.2, z = 22.0, zone = "Orgrimmar" } },
        { guid = "0x20015", name = "Eitrigg", module = "city", hub = "Orgrimmar", classId = 1, level = 80, faction = "horde",
          location = "Orgrimmar - Grommash Hold", role = "Wall Patroller", activity = "PatrolWalls", lastAction = "MovePoint Ramparts", nextTask = "Guard watchtower south", dueMs = 9000, truthClass = "Queued", status = "Patrolling",
          coords = { x = 1910.8, y = -4140.6, z = 42.1, zone = "Orgrimmar" } },

        -- ── City Life Residents: Ironforge & Undercity & Dalaran & Goldshire ──
        { guid = "0x20021", name = "Magni", module = "city", hub = "Ironforge", classId = 1, level = 80, faction = "alliance",
          location = "Ironforge - The Great Forge", role = "Flex Resident", activity = "RoamDistrict", lastAction = "MovePoint Anvil", nextTask = "Inspect weaponsmith stall", dueMs = 14000, truthClass = "Queued", status = "Active",
          coords = { x = -4920.1, y = -920.4, z = 502.1, zone = "Ironforge" } },
        { guid = "0x20022", name = "Brann", module = "city", hub = "Ironforge", classId = 3, level = 80, faction = "alliance",
          location = "Ironforge - Military Ward", role = "Tavern Patron", activity = "DrinkInTavern", lastAction = "Drink Mug", nextTask = "Discuss expedition tales", dueMs = 28000, truthClass = "Conditional", status = "Resting",
          coords = { x = -4810.5, y = -1120.2, z = 502.8, zone = "Ironforge" } },
        { guid = "0x20031", name = "Varimathras", module = "city", hub = "Undercity", classId = 4, level = 80, faction = "horde",
          location = "Undercity - Apothecarium", role = "Flex Resident", activity = "RoamDistrict", lastAction = "MovePoint Ring", nextTask = "Inspect alchemy vats", dueMs = 16000, truthClass = "Queued", status = "Active",
          coords = { x = 1410.2, y = 420.5, z = -55.2, zone = "Undercity" } },
        { guid = "0x20032", name = "Belmont", module = "city", hub = "Undercity", classId = 6, level = 80, faction = "horde",
          location = "Undercity - Rogues' Quarter", role = "Wander District", activity = "RoamDistrict", lastAction = "MovePoint Corridor", nextTask = "Visit poison vendor", dueMs = 19000, truthClass = "Queued", status = "Active",
          coords = { x = 1620.4, y = 240.1, z = -58.1, zone = "Undercity" } },
        { guid = "0x20041", name = "Rhonin", module = "city", hub = "Dalaran", classId = 8, level = 80, faction = "alliance",
          location = "Dalaran - Eventide", role = "Plaza Socializer", activity = "ScriptedChat", lastAction = "Emote Wave", nextTask = "Address citizens of Dalaran", dueMs = 8500, truthClass = "Deadline", status = "Active",
          coords = { x = 5810.2, y = 620.4, z = 645.2, zone = "Dalaran" } },
        { guid = "0x20042", name = "Aethas", module = "city", hub = "Dalaran", classId = 8, level = 80, faction = "horde",
          location = "Dalaran - Sunreaver", role = "Flex Resident", activity = "RoamDistrict", lastAction = "MovePoint Sanctuary", nextTask = "Consult Sunreaver mages", dueMs = 12500, truthClass = "Queued", status = "Active",
          coords = { x = 5720.5, y = 560.8, z = 647.1, zone = "Dalaran" } },
        { guid = "0x20051", name = "Marshalbot", module = "city", hub = "Goldshire", classId = 2, level = 80, faction = "alliance",
          location = "Goldshire - Lion's Pride", role = "Gate Duelist", activity = "DuelRitual", lastAction = "Accept duel", nextTask = "Execute combat rotation", dueMs = 4100, truthClass = "Deadline", status = "Active",
          coords = { x = -9460.1, y = 60.5, z = 56.2, zone = "Elwynn Forest" } },
        { guid = "0x20052", name = "Remidancer", module = "city", hub = "Goldshire", classId = 5, level = 80, faction = "alliance",
          location = "Goldshire - Inn", role = "Inn Dancer", activity = "DanceInInn", lastAction = "Dance Emote", nextTask = "Tavern celebration cycle", dueMs = 30000, truthClass = "Conditional", status = "Active",
          coords = { x = -9465.3, y = 55.8, z = 56.4, zone = "Elwynn Forest" } },

        -- ── PvP Life Participants: Gurubashi Arena ──
        { guid = "0x30001", name = "Mandokir", module = "pvp", zone = "STV_Gurubashi", classId = 1, level = 80, faction = "horde",
          location = "STV_Gurubashi", activity = "Skirmish", lastAction = "Mortal Strike", nextTask = "Engage enemy Kurzen", dueMs = 1500, truthClass = "Observed", status = "InCombat",
          coords = { x = -11910.4, y = 460.2, z = 3.5, zone = "Stranglethorn Vale" } },
        { guid = "0x30002", name = "Kurzen", module = "pvp", zone = "STV_Gurubashi", classId = 4, level = 80, faction = "alliance",
          location = "STV_Gurubashi", activity = "Skirmish", lastAction = "Ambush", nextTask = "Vanish & reset range", dueMs = 2000, truthClass = "Observed", status = "InCombat",
          coords = { x = -11920.1, y = 450.8, z = 3.2, zone = "Stranglethorn Vale" } },
        { guid = "0x30003", name = "Zuljin", module = "pvp", zone = "STV_Gurubashi", classId = 3, level = 80, faction = "horde",
          location = "STV_Gurubashi", activity = "Skirmish", lastAction = "Multi-Shot", nextTask = "Maintain 18yd tactical range", dueMs = 1800, truthClass = "Observed", status = "InCombat",
          coords = { x = -11895.3, y = 475.1, z = 4.1, zone = "Stranglethorn Vale" } },
        { guid = "0x30004", name = "Finley", module = "pvp", zone = "STV_Gurubashi", classId = 2, level = 80, faction = "alliance",
          location = "STV_Gurubashi", activity = "Skirmish", lastAction = "Holy Shock", nextTask = "Heal ally Kurzen", dueMs = 2200, truthClass = "Observed", status = "InCombat",
          coords = { x = -11925.8, y = 445.6, z = 3.4, zone = "Stranglethorn Vale" } },

        -- ── PvP Life Participants: Gate Duels ──
        { guid = "0x30011", name = "Varian", module = "pvp", zone = "StormwindDuel", classId = 1, level = 80, faction = "alliance",
          location = "StormwindDuel", activity = "Duel", lastAction = "CastSpell 7266", nextTask = "Duel countdown Arbiter", dueMs = 2800, truthClass = "Deadline", status = "DuelCountdown",
          coords = { x = -9080.5, y = 410.2, z = 92.5, zone = "Elwynn Forest" } },
        { guid = "0x30012", name = "Turalyon", module = "pvp", zone = "StormwindDuel", classId = 2, level = 80, faction = "alliance",
          location = "StormwindDuel", activity = "Duel", lastAction = "Judgement of Light", nextTask = "Engage opponent Varian", dueMs = 3100, truthClass = "Deadline", status = "Active",
          coords = { x = -9075.2, y = 405.8, z = 92.3, zone = "Elwynn Forest" } },
        { guid = "0x30013", name = "Garrosh", module = "pvp", zone = "OrgrimmarDuel", classId = 1, level = 80, faction = "horde",
          location = "OrgrimmarDuel", activity = "Duel", lastAction = "CastSpell 7266", nextTask = "Duel countdown Arbiter", dueMs = 2400, truthClass = "Deadline", status = "DuelCountdown",
          coords = { x = 1350.2, y = -4380.5, z = 26.1, zone = "Durotar" } },
        { guid = "0x30014", name = "Saurfang", module = "pvp", zone = "OrgrimmarDuel", classId = 1, level = 80, faction = "horde",
          location = "OrgrimmarDuel", activity = "Duel", lastAction = "Cleave", nextTask = "Engage opponent Garrosh", dueMs = 2900, truthClass = "Deadline", status = "Active",
          coords = { x = 1355.8, y = -4375.1, z = 26.0, zone = "Durotar" } },

        -- ── PvP Life Participants: Dark Portal & Wintergrasp ──
        { guid = "0x30021", name = "Khadgar", module = "pvp", zone = "DarkPortal_Outland", classId = 8, level = 80, faction = "alliance",
          location = "DarkPortal_Outland", activity = "ForTheAlliance", lastAction = "Blizzard", nextTask = "Push portal defensive perimeter", dueMs = 1900, truthClass = "Observed", status = "InCombat",
          coords = { x = -11810.5, y = -3190.2, z = -25.4, zone = "Blasted Lands" } },
        { guid = "0x30022", name = "Terokk", module = "pvp", zone = "DarkPortal_Outland", classId = 5, level = 80, faction = "horde",
          location = "DarkPortal_Outland", activity = "ForTheHorde", lastAction = "Mind Blast", nextTask = "Counter-attack Alliance offensive", dueMs = 2100, truthClass = "Observed", status = "InCombat",
          coords = { x = -11825.1, y = -3175.8, z = -24.8, zone = "Blasted Lands" } },
        { guid = "0x30031", name = "Thassarian", module = "pvp", zone = "Wintergrasp", classId = 6, level = 80, faction = "alliance",
          location = "Wintergrasp", activity = "Skirmish", lastAction = "Death Grip", nextTask = "Secure Sunken Ring siege workshop", dueMs = 3400, truthClass = "Observed", status = "InCombat",
          coords = { x = 4450.2, y = 2810.5, z = 390.2, zone = "Wintergrasp" } },
        { guid = "0x30032", name = "Koltira", module = "pvp", zone = "Wintergrasp", classId = 6, level = 80, faction = "horde",
          location = "Wintergrasp", activity = "Skirmish", lastAction = "Obliterate", nextTask = "Defend Sunken Ring siege workshop", dueMs = 3100, truthClass = "Observed", status = "InCombat",
          coords = { x = 4465.8, y = 2825.1, z = 391.0, zone = "Wintergrasp" } },
    }

    self.bots = {}
    for _, b in ipairs(initialBots) do
        b.isRealPlayer = false
        b.isBot = true
        b.entityType = "Bot"
        b.truthSource = "server-authoritative"
        b.updatedAt = GetTime()
        self.bots[b.guid] = b
    end

    -- Work Queues
    self.workQueues = {
        { taskId = 101, queue = "move", botName = "Thoradin", taskType = "MovePoint to WallPatrol 3", dueMs = 4500, truthClass = "Queued" },
        { taskId = 102, queue = "engage", botName = "Mandokir", taskType = "AttackTarget Kurzen", dueMs = 1500, truthClass = "Observed" },
        { taskId = 103, queue = "duel", botName = "Varian", taskType = "AcceptDuel Target Turalyon", dueMs = 2800, truthClass = "Deadline" },
        { taskId = 104, queue = "chat", botName = "Jaina", taskType = "Say to Plaza Partner", dueMs = 12000, truthClass = "Conditional" },
    }

    self.alerts = {
        {
            severity = "INFO",
            text = "Autonomous bot populations initialized (19 City Life, 12 PvP Life).",
            time = GetTime(),
        }
    }

    self:RebuildBotList()
    self:Notify("ON_CAPACITY_UPDATED", self.capacity)
    self:Notify("ON_HUBS_UPDATED", self.cityHubList)
    self:Notify("ON_ZONES_UPDATED", self.pvpZoneList)
    self:Notify("ON_QUEUES_UPDATED", self.workQueues)
    self:Notify("ON_ROSTER_UPDATED")
end

-- ─── Active World Entity Scanning (DASH-06 & DASH-11) ────────────────────────
function Store:ScanUnit(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return false end
    if UnitIsUnit(unit, "player") then return false end

    local guid = UnitGUID(unit)
    if not guid then return false end

    local name = UnitName(unit)
    if not name or name == "" or name == UNKNOWN then return false end

    local _, classFile = UnitClass(unit)
    local level = UnitLevel(unit)
    local faction = UnitFactionGroup(unit)
    local inCombat = UnitAffectingCombat(unit)

    local zone = GetZoneText() or ""
    local subzone = GetSubZoneText() or ""
    local loc = (subzone ~= "" and subzone) or (zone ~= "" and zone) or "World"

    local classId = CLASS_NAME_TO_ID[classFile] or 1
    local now = GetTime()

    local existing = self.bots[guid]
    if existing then
        -- Update observed world status without overriding authoritative classification
        existing.status = inCombat and "InCombat" or existing.status
        existing.lastAction = inCombat and "Combat Action" or existing.lastAction
        existing.location = loc
        existing.updatedAt = now
        return true
    else
        -- Discovered entity: Mark as bot observation in bot environment
        self.bots[guid] = {
            guid = guid,
            name = name,
            module = "world",
            classId = classId,
            level = (level and level > 0) and level or 80,
            faction = faction and string.lower(faction) or "alliance",
            location = loc,
            activity = inCombat and "InCombat" or "WorldObservation",
            lastAction = inCombat and "Combat Action" or "Idle",
            nextTask = "Autonomous Task",
            dueMs = 0,
            truthClass = "Observed",
            status = inCombat and "InCombat" or "Active",
            truthSource = "observed",
            entityType = "Bot",
            isRealPlayer = false,
            isBot = true,
            updatedAt = now,
        }
        return true
    end
end

function Store:ScanNearbyWorld()
    local changed = false

    if UnitExists("target") and UnitIsPlayer("target") then
        if self:ScanUnit("target") then changed = true end
    end
    if UnitExists("mouseover") and UnitIsPlayer("mouseover") then
        if self:ScanUnit("mouseover") then changed = true end
    end
    if UnitExists("focus") and UnitIsPlayer("focus") then
        if self:ScanUnit("focus") then changed = true end
    end

    local numParty = GetNumPartyMembers() or 0
    for i = 1, numParty do
        local unit = "party" .. i
        if UnitExists(unit) and UnitIsPlayer(unit) then
            if self:ScanUnit(unit) then changed = true end
        end
    end

    local numRaid = GetNumRaidMembers() or 0
    for i = 1, numRaid do
        local unit = "raid" .. i
        if UnitExists(unit) and UnitIsPlayer(unit) then
            if self:ScanUnit(unit) then changed = true end
        end
    end

    -- Batch update: rebuild and notify at most once per world scan (DASH-11)
    if changed then
        self:RebuildBotList()
        self:Notify("ON_ROSTER_UPDATED")
    end
end

function Store:PruneStaleObserved(maxAgeSec)
    maxAgeSec = maxAgeSec or 300 -- 5 minutes default
    local now = GetTime()
    local removed = false

    for guid, b in pairs(self.bots) do
        if b.truthSource == "client-observed-unclassified" and not self:IsWatchlisted(guid) then
            if (now - (b.updatedAt or 0)) > maxAgeSec then
                self.bots[guid] = nil
                removed = true
            end
        end
    end

    if removed then
        self:RebuildBotList()
        self:Notify("ON_ROSTER_UPDATED")
    end
end

-- ─── Message Parsing & Reconnect Lifecycle (DASH-04, DASH-12) ─────────────────
function Store:HandleMessage(kind, stream, reqId, session, payload)
    if kind == "WELCOME" then
        -- Clear demo/mock data if previously injected (DASH-01)
        if self.isMockData then
            self:InitWorld()
        end

        LifeDashboard.sessionEpoch = session
        LifeDashboard.connected = true
        LifeDashboard.connectionState = "CONNECTED"
        LifeDashboard.lastPacketTime = GetTime()

        local caps, tier, serverMono, serverWall = string.match(payload, "^([^|]*)|([^|]*)|(%d*)|(%d*)")
        if LifeDashboard.Permissions then
            LifeDashboard.Permissions:UpdateFromWelcome(caps, tier)
        end
        if LifeDashboard.Clock and serverMono and serverWall then
            LifeDashboard.Clock:Synchronize(GetTime(), tonumber(serverMono) or 0, tonumber(serverWall) or 0)
        end

        -- Automatically subscribe to live telemetry stream on connect
        if LifeDashboard.Protocol then
            LifeDashboard.Protocol:SendMessage("SUBSCRIBE", "main", nil, "init")
        end

        self:Notify("ON_CONNECTED")
        if LifeDashboard.Window and LifeDashboard.Window.UpdateHeaderStatus then
            LifeDashboard.Window:UpdateHeaderStatus()
        end
        return
    end

    -- Drop messages if not connected or session mismatch (DASH-04)
    if not LifeDashboard.connected or session ~= LifeDashboard.sessionEpoch then
        return
    end

    LifeDashboard.lastPacketTime = GetTime()

    if kind == "PONG" then
        local clientSendMs = tonumber(payload)
        if clientSendMs and LifeDashboard.Clock then
            local now = GetTime()
            local rtt = math.max(1, math.floor(now * 1000 - clientSendMs))
            LifeDashboard.Clock.rttMs = rtt
            if LifeDashboard.Window and LifeDashboard.Window.UpdateHeaderStatus then
                LifeDashboard.Window:UpdateHeaderStatus()
            end
        end

    elseif kind == "DENIED" then
        local reason = payload or "Permission denied"
        table.insert(self.alerts, 1, {
            severity = "WARN",
            text = "Server request denied: " .. reason,
            time = GetTime(),
        })
        self:Notify("ON_ALERT_ADDED", self.alerts[1])

    elseif kind == "CAPACITY" then
        local t, ct, ca, cp, cr, pt, pa, pp, pr, fr = string.match(payload, "^(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)")
        if t then
            self.capacity.total = tonumber(t) or 0
            self.capacity.cityTarget = tonumber(ct) or 0
            self.capacity.cityActive = tonumber(ca) or 0
            self.capacity.cityPending = tonumber(cp) or 0
            self.capacity.cityReleasing = tonumber(cr) or 0
            self.capacity.pvpTarget = tonumber(pt) or 0
            self.capacity.pvpActive = tonumber(pa) or 0
            self.capacity.pvpPending = tonumber(pp) or 0
            self.capacity.pvpReleasing = tonumber(pr) or 0
            self.capacity.free = tonumber(fr) or 0
            self.hasServerCapacity = true
            self:Notify("ON_CAPACITY_UPDATED", self.capacity)
        end

    elseif kind == "ROSTER" or kind == "RECORDS" then
        self.snapshotGeneration = self.snapshotGeneration + 1
        for line in string.gmatch(payload, "[^\r\n]+") do
            self:ParseRosterRecord(line)
        end
        self:RebuildBotList()
        self:Notify("ON_ROSTER_UPDATED")

    elseif kind == "HUBS" then
        self.cityHubList = {}
        for line in string.gmatch(payload, "[^\r\n]+") do
            local hubId, hName, target, active, pending, poiCount, timeMult =
                string.match(line, "^(%d+)|([^|]+)|(%d+)|(%d+)|(%d+)|(%d+)|([%d%.]+)")
            if hubId and hName then
                table.insert(self.cityHubList, {
                    hubId = tonumber(hubId),
                    name = hName,
                    target = tonumber(target) or 0,
                    active = tonumber(active) or 0,
                    pending = tonumber(pending) or 0,
                    poiCount = tonumber(poiCount) or 0,
                    timeMult = tonumber(timeMult) or 1.0,
                })
            end
        end
        self:Notify("ON_HUBS_UPDATED", self.cityHubList)

    elseif kind == "ZONES" then
        self.pvpZoneList = {}
        for line in string.gmatch(payload, "[^\r\n]+") do
            local zoneId, zName, actType, minL, maxL, aAll, aHorde, cd =
                string.match(line, "^(%d+)|([^|]+)|([^|]+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)")
            if zoneId and zName then
                table.insert(self.pvpZoneList, {
                    zoneId = tonumber(zoneId),
                    name = zName,
                    activityType = actType,
                    minLevel = tonumber(minL) or 20,
                    maxLevel = tonumber(maxL) or 80,
                    activeAlliance = tonumber(aAll) or 0,
                    activeHorde = tonumber(aHorde) or 0,
                    cooldownSec = tonumber(cd) or 0,
                })
            end
        end
        self:Notify("ON_ZONES_UPDATED", self.pvpZoneList)

    elseif kind == "QUEUES" then
        self.workQueues = {}
        for line in string.gmatch(payload, "[^\r\n]+") do
            local taskId, q, botName, tType, due, truth =
                string.match(line, "^(%d+)|([^|]+)|([^|]+)|([^|]+)|([-%d]+)|([^|]+)")
            if taskId and q then
                table.insert(self.workQueues, {
                    taskId = tonumber(taskId),
                    queue = q,
                    botName = botName,
                    taskType = tType,
                    dueMs = tonumber(due) or 0,
                    truthClass = truth or "Queued",
                })
            end
        end
        self:Notify("ON_QUEUES_UPDATED", self.workQueues)

    elseif kind == "DELTA" then
        self:ParseRosterRecord(payload)
        self:RebuildBotList()
        self:Notify("ON_ROSTER_UPDATED")

    elseif kind == "TOMBSTONE" then
        local guid = string.match(payload, "^([^|]+)")
        if guid and self.bots[guid] then
            self.bots[guid] = nil
            self:RebuildBotList()
            self:Notify("ON_ROSTER_UPDATED")
        end

    elseif kind == "ALERT" then
        local sev, msg = string.match(payload, "^([^|]+)|(.*)$")
        if sev and msg then
            table.insert(self.alerts, 1, {
                severity = sev,
                text = msg,
                time = GetTime(),
            })
            if #self.alerts > 50 then table.remove(self.alerts) end
            self:Notify("ON_ALERT_ADDED", self.alerts[1])
        end

    elseif kind == "BOT_DETAIL" then
        local guid, role, action, targetName, targetHp, spellName, strategies, lastAction =
            string.match(payload, "^([^|]+)|([^|]+)|([^|]+)|([^|]+)|(%d+)|([^|]+)|([^|]+)|?(.*)")
        if guid and self.bots[guid] then
            local b = self.bots[guid]
            if role and role ~= "" and role ~= "None" then b.role = role end
            if action and action ~= "" and action ~= "None" then b.lastAction = action end
            b.detail = {
                targetName = targetName,
                targetHp = tonumber(targetHp) or 100,
                spellName = spellName,
                strategies = strategies,
                lastAction = lastAction,
                updatedAt = GetTime(),
            }
            self:Notify("ON_BOT_DETAIL_UPDATED", guid, b.detail)
        end

    elseif kind == "CONFIG" then
        -- Optional live effective server configuration key-value
        local k, val = string.match(payload, "^([^=]+)=(.*)$")
        if k and val then
            self.config[k] = val
            self:Notify("ON_CONFIG_UPDATED", k, val)
        end
    end
end

function Store:QueryBotDetail(guid)
    if not guid then return end
    if LifeDashboard.Protocol then
        LifeDashboard.Protocol:SendMessage("QUERY_BOT", "main", nil, guid)
    end
end

function Store:ParseRosterRecord(line)
    -- Format: guid|name|module|classId|level|faction|location|activity|lastAction|nextTask|dueMs|truthClass|status[|x|y|z|zone|role]
    local guid, name, mod, classId, level, faction, loc, act, lastAct, nextT, dueMs, truth, stat, rx, ry, rz, rzone, rRole =
        string.match(line, "^([^|]+)|([^|]+)|([^|]+)|(%d+)|(%d+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|([-%d]+)|([^|]+)|([^|]+)|?([^|]*)|?([^|]*)|?([^|]*)|?([^|]*)|?([^|]*)")

    if guid and name then
        local coords = nil
        if rx and rx ~= "" and ry and ry ~= "" then
            coords = {
                x = tonumber(rx) or 0,
                y = tonumber(ry) or 0,
                z = tonumber(rz) or 0,
                zone = (rzone ~= "" and rzone) or loc,
            }
        end

        local defaultRole = (mod == "city") and "Citizen" or ((mod == "pvp") and "Participant" or "World")
        local role = (rRole and rRole ~= "") and rRole or defaultRole
        local hubVal = (mod == "city") and (rzone ~= "" and rzone or loc) or nil
        local zoneVal = (mod == "pvp") and (rzone ~= "" and rzone or loc) or nil

        local existing = self.bots[guid]
        self.bots[guid] = {
            guid = guid,
            name = name,
            module = mod,
            hub = hubVal,
            zone = zoneVal,
            role = role,
            classId = tonumber(classId) or 1,
            level = tonumber(level) or 80,
            faction = faction,
            location = loc,
            activity = act,
            lastAction = lastAct,
            nextTask = nextT,
            dueMs = tonumber(dueMs) or 0,
            truthClass = truth or "Observed",
            status = stat or "Active",
            coords = coords,
            truthSource = "server-authoritative",
            entityType = "Bot",
            isRealPlayer = false,
            isBot = true,
            generation = self.snapshotGeneration,
            updatedAt = GetTime(),
            detail = existing and existing.detail or nil,
        }
    end
end

function Store:RebuildBotList()
    self.botList = {}
    for _, b in pairs(self.bots) do
        table.insert(self.botList, b)
    end
    table.sort(self.botList, function(a, b)
        -- Pinned bots first, then alphabetical
        local aPinned = Store:IsWatchlisted(a.guid)
        local bPinned = Store:IsWatchlisted(b.guid)
        if aPinned ~= bPinned then
            return aPinned == true
        end
        return (a.name or "") < (b.name or "")
    end)
end

-- ─── Explicit Opt-In Demonstration / Mock Data ───────────────────────────────
function Store:InjectMockData()
    self:InitWorld()
    self.isMockData = true
    LifeDashboard.isMockData = true
    LifeDashboard.connectionState = "DEMO"
    LifeDashboard.sessionEpoch = "demo-session-999"

    self.alerts = {
        { severity = "INFO", text = "[DEMO] Mock telemetry injected. Type /lifedash reset to clear.", time = GetTime() }
    }

    self:Notify("ON_CAPACITY_UPDATED", self.capacity)
    self:Notify("ON_ROSTER_UPDATED")
    if LifeDashboard.Window and LifeDashboard.Window.UpdateHeaderStatus then
        LifeDashboard.Window:UpdateHeaderStatus()
    end
end

function Store:ResetWorld()
    self.isMockData = false
    LifeDashboard.isMockData = false
    LifeDashboard.connectionState = "DISCONNECTED"
    self:InitWorld()
    if LifeDashboard.Window and LifeDashboard.Window.UpdateHeaderStatus then
        LifeDashboard.Window:UpdateHeaderStatus()
    end
end

