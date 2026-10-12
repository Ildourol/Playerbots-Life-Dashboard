# Playerbots Life Dashboard

**Playerbots Life Dashboard** (`PlayerbotsLifeDashboard`) is an in-game telemetry, monitoring, and inspection addon for World of Warcraft 3.3.5a clients (Interface `30300`, build `12340`). It provides real-time observability, population tracking, and direct interaction tools for autonomous bots powered by [`mod-playerbots-city-life`](https://github.com/Ildourol/mod-playerbots-city-life) and [`mod-playerbots-pvp-life`](https://github.com/Ildourol/mod-playerbots-pvp-life).

---

## Features

### 1. Three Core Management Tabs
- **Overview:** Combined server health and population dashboard displaying total bot capacity, active City Life and PvP Life quotas, real-time activity feeds, and cross-module alerts. Includes multi-criteria search and quick-filter buttons for `All`, `Bots`, `Players`, `City Life`, `PvP Life`, and `★ Watchlist`.
- **City Life:** Deep inspection of urban hubs (Stormwind, Orgrimmar, Ironforge, Undercity, Darnassus, Dalaran, etc.), resident counts, POI assignments, citizen roles (*Plaza Socializer*, *Civic Wanderer*, *Wall Patroller*, *Dock Fisher*, *Inn Dancer*, *Tavern Patron*), and active civic routines.
- **PvP Life:** Real-time visibility into world PvP hotspots (Gurubashi Arena, Capital Gates, Dark Portal, Wintergrasp), skirmishes, faction campaigns, capital gate duel arenas (*Gate Duelist*), server work queues (*Move*, *Engage*, *Duel*, *Chat*), and reactive defense forces.

### 2. Autonomous Bot Monitoring & Player Distinction
- **Clear Badges:** Autonomous bots are distinguished with `[Bot]` / `[B]` badges, while scanned real players are badged with `[Player]` / `[P]`. Real players scanned from the world or party/raid never overwrite or conceal autonomous playerbots.
- **★ Watchlist System:** Pin priority bots with a gold star (`★`) saved persistently in `PlayerbotsLifeDashboardDB`. Pinned bots automatically float to the top of all rosters and can be isolated with the `★ Watch` filter button.

### 3. Finding and Interacting with Bots
- **Target Bot:** Native secure action button executing `/target <BotName>` to instantly acquire the selected bot in the 3D game world without UI taint.
- **Find / Coordinates:** Displays exact 3D coordinates (`X`, `Y`, `Z`, `Zone`) in the inspector drawer. Clicking **Find / Coords** prints formatted location information to chat and automatically registers a TomTom waypoint (`/way`) if TomTom is installed.
- **Whisper Bot:** Opens chat prompt with `/w <BotName> ` to quickly issue native playerbot commands (`.bot`, `follow`, `stay`, etc.).

### 4. Client Integration
- **Minimap Button:** Quick-access minimap button with custom house icon, left-click to toggle dashboard, right-click for quick status, and draggable around the minimap rim.
- **Stock 3.3.5a Compatibility:** Pure Lua 5.1 and FrameXML implementation. Requires zero patched client binaries, custom DLLs, or MPQ patches.

---

## Installation

1. Copy the `PlayerbotsLifeDashboard` folder from this repository into your World of Warcraft client directory:
   ```text
   World of Warcraft\Interface\AddOns\PlayerbotsLifeDashboard\
   ```
2. Ensure the directory structure looks like this:
   ```text
   Interface\AddOns\PlayerbotsLifeDashboard\
       PlayerbotsLifeDashboard.toc
       Bindings.xml
       Core.lua
       Store.lua
       ...
       UI\
           ...
   ```
3. In the character selection screen, click **AddOns** and enable **Playerbots Life Dashboard** (check *Load out of date AddOns* if needed).
4. In-game, open the dashboard via:
   - Clicking the house minimap button
   - Typing `/lifedash` or `/ldash`
   - Binding a hotkey in the standard Blizzard *Key Bindings* menu

---

## Slash Commands

- `/lifedash` or `/ldash` — Toggle the main dashboard window
- `/lifedash show` — Show the dashboard
- `/lifedash hide` — Hide the dashboard
- `/lifedash toggle` — Toggle the dashboard
- `/lifedash config` — Open the settings drawer
- `/lifedash diag` — Open the diagnostics drawer
- `/lifedash minimap` — Toggle the minimap icon

---

## Server Requirements

- [AzerothCore 3.3.5a](https://github.com/azerothcore/azerothcore-wotlk) (Playerbot branch)
- [`mod-playerbots`](https://github.com/mod-playerbots/mod-playerbots)
- Either or both Life modules:
  - [`mod-playerbots-city-life`](https://github.com/Ildourol/mod-playerbots-city-life)
  - [`mod-playerbots-pvp-life`](https://github.com/Ildourol/mod-playerbots-pvp-life)
