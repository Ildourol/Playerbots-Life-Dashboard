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

function Permissions:UpdateFromWelcome(capsString, tier)
    if tier and tier ~= "" then
        self.currentTier = tier
    end

    if capsString then
        self.capabilities.cityLife = string.find(capsString, "city") ~= nil
        self.capabilities.pvpLife = string.find(capsString, "pvp") ~= nil
        self.capabilities.actionObserver = string.find(capsString, "observer") ~= nil
        self.capabilities.operatorControls = string.find(capsString, "controls") ~= nil
        self.capabilities.auditLogs = string.find(capsString, "audit") ~= nil
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
