local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Timeline = {}
LifeDashboard.Timeline = Timeline

function Timeline:GetBotTimeline(guid)
    local bot = LifeDashboard.Store.bots[guid]
    if not bot then return {} end

    local entries = {}

    -- 1. Last Observed Action
    if bot.lastAction and bot.lastAction ~= "" then
        table.insert(entries, {
            truthClass = "OBSERVED",
            title = "Observed Action: " .. bot.lastAction,
            dueMs = 0,
            source = "Native AI Execution",
            icon = "Interface\\Icons\\Spell_Holy_BlessingOfStrength",
        })
    end

    -- 2. Current Activity State
    if bot.activity and bot.activity ~= "" then
        table.insert(entries, {
            truthClass = "OBSERVED",
            title = "Activity: " .. (LifeDashboard.L["ACT_" .. bot.activity] or bot.activity),
            dueMs = 0,
            source = (bot.module == "city" and "City Life Manager" or "PvP Life Manager"),
            icon = "Interface\\Icons\\Achievement_Zone_Stormwind",
        })
    end

    -- 3. Next Queued Task
    if bot.nextTask and bot.nextTask ~= "" then
        table.insert(entries, {
            truthClass = bot.truthClass or "QUEUED",
            title = "Next Task: " .. bot.nextTask,
            dueMs = bot.dueMs or 0,
            source = "Task Work Queue",
            icon = "Interface\\Icons\\Spell_ChargePositive",
        })
    end

    -- 4. Check for matching work queue items
    for _, item in ipairs(LifeDashboard.Store.workQueues) do
        if item.botGuid == guid or item.botName == bot.name then
            table.insert(entries, {
                truthClass = item.truthClass or "QUEUED",
                title = string.upper(item.queue) .. ": " .. item.taskType,
                dueMs = item.dueMs,
                source = "Server Queue",
                icon = "Interface\\Icons\\Ability_Hunter_MasterMarksman",
            })
        end
    end

    return entries
end
