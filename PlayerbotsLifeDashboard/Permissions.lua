local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Permissions = {
    currentTier = "Public",
    capabilities = {
        cityLife = false,
        pvpLife = false,
        actionObserver = false,
        operatorControls = false,
        auditLogs = false,
    },
}

LifeDashboard.Permissions = Permissions

local KNOWN_TIERS = {
    ["Public"] = true,
    ["AuthorizedObserver"] = true,
    ["Operator"] = true,
    ["Admin"] = true,
}

local VALID_CAPS = {
    ["city"] = "cityLife",
    ["pvp"] = "pvpLife",
    ["observer"] = "actionObserver",
    ["controls"] = "operatorControls",
    ["audit"] = "auditLogs",
}

function Permissions:Reset()
    self.currentTier = "Public"
    self.capabilities.cityLife = false
    self.capabilities.pvpLife = false
    self.capabilities.actionObserver = false
    self.capabilities.operatorControls = false
    self.capabilities.auditLogs = false
    if LifeDashboard.Window and LifeDashboard.Window.UpdateHeaderStatus then
        LifeDashboard.Window:UpdateHeaderStatus()
    end
end

function Permissions:UpdateFromWelcome(capsString, tier)
    -- Reset prior capabilities on new session handshake
    self.capabilities.cityLife = false
    self.capabilities.pvpLife = false
    self.capabilities.actionObserver = false
    self.capabilities.operatorControls = false
    self.capabilities.auditLogs = false

    if tier and KNOWN_TIERS[tier] then
        self.currentTier = tier
    else
        self.currentTier = "Public"
    end

    if capsString and capsString ~= "" then
        -- Tokenize on commas, semicolons, or whitespace to prevent substring false-positives
        for token in string.gmatch(capsString, "[^,;%s]+") do
            local cleanToken = string.lower(token)
            local capKey = VALID_CAPS[cleanToken]
            if capKey then
                self.capabilities[capKey] = true
            end
        end
    end

    if LifeDashboard.Window and LifeDashboard.Window.UpdateHeaderStatus then
        LifeDashboard.Window:UpdateHeaderStatus()
    end
end

function Permissions:CanViewDiagnostics()
    return self.currentTier == "AuthorizedObserver" or self.currentTier == "Operator" or self.currentTier == "Admin"
end

function Permissions:CanExecuteControls()
    return self.capabilities.operatorControls and (self.currentTier == "Operator" or self.currentTier == "Admin")
end

function Permissions:RedactSensitive(value, kind)
    if self.currentTier == "Admin" then
        return value
    end
    if kind == "account" then
        return "<hidden>"
    elseif kind == "whisper" then
        return "<private>"
    elseif kind == "audit_path" then
        return "<server_logs>"
    end
    return value
end
