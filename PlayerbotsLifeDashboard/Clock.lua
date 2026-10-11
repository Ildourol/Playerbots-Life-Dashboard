local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Clock = {
    serverMonotonicOffset = 0,
    rttMs = 0,
    serverWallOffset = 0,
    lastSync = 0,
}

LifeDashboard.Clock = Clock

function Clock:Synchronize(clientSendTime, serverTimeMonotonic, serverWallEpoch)
    local now = GetTime()
    self.rttMs = math.max(1, math.floor((now - clientSendTime) * 1000))
    local halfRttSec = (self.rttMs / 2000)
    self.serverMonotonicOffset = (serverTimeMonotonic / 1000) - now - halfRttSec
    if serverWallEpoch and serverWallEpoch > 0 then
        self.serverWallOffset = serverWallEpoch - time()
    end
    self.lastSync = now
end

function Clock:GetEstimatedServerTime()
    return (GetTime() + self.serverMonotonicOffset) * 1000
end

-- ─── Truth Class Evaluation & Badges ─────────────────────────────────────────
Clock.TRUTH_CLASSES = {
    OBSERVED       = { code = "Observed",       color = "00ff66", text = "Observed" },
    QUEUED         = { code = "Queued",         color = "00ccff", text = "Queued" },
    DEADLINE       = { code = "Deadline",       color = "ffcc00", text = "Deadline" },
    ELIGIBLE_AFTER = { code = "Eligible after", color = "ff9933", text = "Eligible after" },
    CONDITIONAL    = { code = "Conditional",    color = "cc66ff", text = "Conditional" },
    ESTIMATED      = { code = "Estimated",      color = "99ccff", text = "Estimated" },
    UNKNOWN        = { code = "Unknown",        color = "888888", text = "Unknown" },
}

function Clock:FormatTruthBadge(truthClass)
    local meta = self.TRUTH_CLASSES[truthClass] or self.TRUTH_CLASSES.UNKNOWN
    return string.format("|cff%s[%s]|r", meta.color, meta.text)
end

function Clock:FormatDueTime(dueMs, truthClass)
    if not dueMs then return "|cff888888--|r" end
    local remainingSec = math.floor(dueMs / 1000)

    if remainingSec < 0 then
        local overdueSec = math.abs(remainingSec)
        if truthClass == "DEADLINE" then
            return string.format("|cffff3333Expired (%ds ago)|r", overdueSec)
        else
            return string.format("|cffff9900Overdue (%ds)|r", overdueSec)
        end
    elseif remainingSec == 0 then
        return "|cff00ff66Due now|r"
    elseif remainingSec < 60 then
        return string.format("|cff%sin %ds|r", (self.TRUTH_CLASSES[truthClass] or self.TRUTH_CLASSES.QUEUED).color, remainingSec)
    elseif remainingSec < 3600 then
        local mins = math.floor(remainingSec / 60)
        local secs = remainingSec % 60
        return string.format("|cff%sin %dm %ds|r", (self.TRUTH_CLASSES[truthClass] or self.TRUTH_CLASSES.QUEUED).color, mins, secs)
    else
        local hours = math.floor(remainingSec / 3600)
        local mins = math.floor((remainingSec % 3600) / 60)
        return string.format("|cff%sin %dh %dm|r", (self.TRUTH_CLASSES[truthClass] or self.TRUTH_CLASSES.QUEUED).color, hours, mins)
    end
end
