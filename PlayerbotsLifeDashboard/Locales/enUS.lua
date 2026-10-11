local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

-- Bindings strings in global environment
BINDING_HEADER_PLAYERBOTS_LIFE_DASHBOARD_HEADER = "Playerbots Life Dashboard"
BINDING_NAME_PLAYERBOTS_LIFE_DASHBOARD_TOGGLE = "Toggle Dashboard Window"

local L = {
    -- Window Titles
    ADDON_TITLE = "Playerbots Life Dashboard",
    ADDON_SUBTITLE = "Live Telemetry & Diagnostics for City Life and PvP Life",

    -- Tabs (Exactly 3)
    TAB_OVERVIEW = "Overview",
    TAB_CITY_LIFE = "City Life",
    TAB_PVP_LIFE = "PvP Life",

    -- Drawers & Tools
    DRAWER_INSPECTOR = "Bot Inspector",
    DRAWER_SETTINGS = "Configuration",
    DRAWER_DIAGNOSTICS = "Diagnostics",

    -- Status & Headers
    STATUS_CONNECTED = "Connected",
    STATUS_CONNECTING = "Connecting...",
    STATUS_DISCONNECTED = "Disconnected",
    STATUS_DEGRADED = "Degraded",
    STATUS_UNAVAILABLE = "Unavailable",
    STATUS_DEMO = "DEMO MODE",
    STATUS_LOCAL_ONLY = "Local Observations Only",
    STATUS_STALE = "Degraded (Stale)",
    STATUS_AWAITING_TELEMETRY = "Awaiting Server Telemetry",
    BADGE_UNCLASSIFIED = "Observed",
    BADGE_PLAYER = "Player",
    BADGE_BOT = "Bot",

    -- Common Columns
    COL_BOT = "Bot",
    COL_MODULE = "Module",
    COL_LOCATION = "Hub / Zone",
    COL_ACTIVITY = "Activity / Phase",
    COL_LAST_ACTION = "Last Observed Action",
    COL_NEXT_TASK = "Next Task",
    COL_DUE = "Due / Deadline",
    COL_STATUS = "State",
    COL_ALERT = "Alert",

    -- Capacity Summary Cards
    CARD_TOTAL_POOL = "Total Autonomous Bots",
    CARD_CITY_CAPACITY = "City Life Allocation",
    CARD_PVP_CAPACITY = "PvP Life Allocation",
    CARD_FREE_CAPACITY = "Free Pool Remaining",
    CARD_ACTIVE_BOTS = "Active Participants",
    CARD_QUEUED_WORK = "Queued Tasks",

    -- City Roles
    ROLE_FLEX = "Flex Resident",
    ROLE_INN_DANCER = "Inn Dancer",
    ROLE_PLAZA_TALKER = "Plaza Socializer",
    ROLE_GATE_DUELIST = "Gate Duelist",
    ROLE_GOLDSHIRE_DUELIST = "Goldshire Duelist",
    ROLE_FISHER = "Dock Fisher",
    ROLE_CROWD = "Ambient Crowd",

    -- Truth Classes
    TRUTH_OBSERVED = "Observed",
    TRUTH_QUEUED = "Queued",
    TRUTH_DEADLINE = "Deadline",
    TRUTH_ELIGIBLE_AFTER = "Eligible after",
    TRUTH_CONDITIONAL = "Conditional",
    TRUTH_ESTIMATED = "Estimated",
    TRUTH_UNKNOWN = "Unknown",

    -- Common Actions & Activities
    ACT_LEAVE_INN = "Leave Inn",
    ACT_VISIT_AUCTION = "Visit Auction House",
    ACT_VISIT_MAILBOX = "Visit Mailbox",
    ACT_BUY_FOOD = "Buy Food",
    ACT_WANDER = "Wander District",
    ACT_SIT_TAVERN = "Sit in Tavern",
    ACT_WATCH_DUELS = "Watch Duels",
    ACT_VISIT_TRAINER = "Visit Trainer",
    ACT_DRINK_TAVERN = "Drink in Tavern",
    ACT_PATROL_WALLS = "Patrol City Walls",
    ACT_RETURN_INN = "Return to Inn",
    ACT_RELEASE = "Release Cycle",
    ACT_EMOTE = "Random Emote",
    ACT_FISH = "Fish at Docks",
    ACT_IDLE = "Idle Wait",
    ACT_DUEL = "Active Duel",
    ACT_INN_DANCE = "Inn Dance",
    ACT_PLAZA_SOCIAL = "Plaza Social",
    ACT_CROWD_SOCIAL = "Crowd Scene",

    -- PvP Queues & Activities
    PVP_SKIRMISH = "World Skirmish",
    PVP_DUEL = "Hotspot Duel",
    PVP_FOR_THE_HORDE = "For The Horde",
    PVP_FOR_THE_ALLIANCE = "For The Alliance",
    QUEUE_MOVE = "Movement Queue",
    QUEUE_ENGAGE = "Engagement Queue",
    QUEUE_DUEL = "Duel Queue",
    QUEUE_CHAT = "Chat Queue",
    QUEUE_LOGIN = "Reactive Offline Logins",

    -- Buttons
    BTN_REFRESH = "Refresh",
    BTN_CLOSE = "Close",
    BTN_PIN = "Pin Bot",
    BTN_UNPIN = "Unpin Bot",
    BTN_FILTER = "Filter",
    BTN_RESET_FILTERS = "Reset Filters",
    BTN_EXPORT = "Export Data",

    -- Search Placeholders
    SEARCH_PLACEHOLDER = "Search bots, zones, activities...",
}

LifeDashboard.L = L
