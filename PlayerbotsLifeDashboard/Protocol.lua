local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Protocol = {
    PREFIX = "LIFE335",
    VERSION = 1,
    MAX_WIRE_BYTES = 240,
    ASSEMBLY_TIMEOUT_SEC = 10,
    debugEnabled = false,
    buffers = {}, -- [session..":"..stream..":"..seq] = { parts = {}, count = 0, totalParts = N, totalBytes = B, crc = C, createdAt = T }
    reqCounter = 1000,
}

LifeDashboard.Protocol = Protocol

-- ─── CRC32 Implementation (Pure Lua 5.1) ─────────────────────────────────────
local crcTable = nil
local function InitCrcTable()
    crcTable = {}
    for i = 0, 255 do
        local crc = i
        for j = 1, 8 do
            if crc % 2 ~= 0 then
                crc = bit.bxor(bit.rshift(crc, 1), 0xEDB88320)
            else
                crc = bit.rshift(crc, 1)
            end
        end
        crcTable[i] = crc
    end
end

function Protocol:CalculateCRC32(data)
    if not crcTable then InitCrcTable() end
    local crc = 0xFFFFFFFF
    local len = string.len(data)
    for i = 1, len do
        local byte = string.byte(data, i)
        local idx = bit.band(bit.bxor(crc, byte), 0xFF)
        crc = bit.bxor(bit.rshift(crc, 8), crcTable[idx])
    end
    crc = bit.bxor(crc, 0xFFFFFFFF)
    -- Format as 8 uppercase hex characters
    return string.format("%08X", crc)
end

-- ─── Percent Escaping / Decoding ──────────────────────────────────────────────
function Protocol:Escape(str)
    if not str then return "" end
    str = tostring(str)
    return string.gsub(str, "([|%t%n%%%z])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

function Protocol:Unescape(str)
    if not str then return "" end
    str = tostring(str)
    return string.gsub(str, "%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
end

-- ─── Outbound Transmission ───────────────────────────────────────────────────
function Protocol:NextRequestId()
    self.reqCounter = self.reqCounter + 1
    if self.reqCounter > 999999 then self.reqCounter = 1000 end
    return self.reqCounter
end

function Protocol:SendMessage(kind, stream, reqId, payload)
    reqId = reqId or self:NextRequestId()
    stream = stream or "main"
    payload = payload or ""

    local session = LifeDashboard.sessionEpoch or "0"
    local crc = self:CalculateCRC32(payload)
    local totalBytes = string.len(payload)

    -- Estimate chunk payload capacity:
    -- Header template: "1|kind|session|stream|0|reqId|part|parts|bytes|crc|"
    -- Usually around 40-50 chars, safely leaving ~180-190 bytes per body chunk.
    local chunkPayloadBudget = 180
    local totalParts = math.max(1, math.ceil(totalBytes / chunkPayloadBudget))
    local seq = 1

    for part = 1, totalParts do
        local startIdx = (part - 1) * chunkPayloadBudget + 1
        local endIdx = math.min(totalBytes, part * chunkPayloadBudget)
        local rawChunk = string.sub(payload, startIdx, endIdx)
        local escapedChunk = self:Escape(rawChunk)

        local header = string.format("%d|%s|%s|%s|%d|%d|%d|%d|%d|%s|",
            self.VERSION, kind, session, stream, seq, reqId, part, totalParts, totalBytes, crc)
        local wireFrame = header .. escapedChunk

        if string.len(wireFrame) > self.MAX_WIRE_BYTES then
            -- Fallback safety slice if escaping expands payload beyond 240 bytes
            escapedChunk = string.sub(escapedChunk, 1, self.MAX_WIRE_BYTES - string.len(header))
            wireFrame = header .. escapedChunk
        end

        if self.debugEnabled then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ccff[LIFE335:OUT]|r %s (part %d/%d)", wireFrame, part, totalParts))
        end

        local playerName = UnitName("player")
        if playerName then
            SendAddonMessage(self.PREFIX, wireFrame, "WHISPER", playerName)
        end
    end

    return reqId
end

-- ─── Inbound Packet Reception ────────────────────────────────────────────────
function Protocol:OnPacketReceived(message, sender, channel)
    if not message or string.sub(message, 1, 2) ~= "1|" then return end

    -- Verify self-whisper
    local selfName = UnitName("player")
    if sender and selfName and not string.find(sender, selfName, 1, true) then
        return
    end

    -- Split header fields: V|kind|session|stream|seq|request|part|parts|bytes|crc|body
    local v, kind, session, stream, seq, reqId, part, parts, totalBytes, crc, body =
        string.match(message, "^(%d+)|([^|]+)|([^|]+)|([^|]+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|([%x%X]+)|(.*)$")

    if not v or not kind or not part or not parts then
        return
    end

    v = tonumber(v)
    seq = tonumber(seq)
    reqId = tonumber(reqId)
    part = tonumber(part)
    parts = tonumber(parts)
    totalBytes = tonumber(totalBytes)

    if self.debugEnabled then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff99[LIFE335:IN]|r %s stream=%s part=%d/%d", kind, stream, part, parts))
    end

    if parts == 1 then
        -- Single-packet message, assemble and dispatch immediately
        local unescaped = self:Unescape(body)
        local calcCrc = self:CalculateCRC32(unescaped)
        if string.upper(calcCrc) == string.upper(crc) or crc == "00000000" then
            self:DispatchMessage(kind, stream, reqId, session, unescaped)
        else
            if self.debugEnabled then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff3333[LIFE335:ERR]|r CRC Mismatch! Expected %s got %s", crc, calcCrc))
            end
        end
        return
    end

    -- Multi-chunk message reassembly
    local bufKey = session .. ":" .. stream .. ":" .. seq .. ":" .. reqId
    local buf = self.buffers[bufKey]
    local now = GetTime()

    if not buf then
        buf = {
            parts = {},
            receivedCount = 0,
            totalParts = parts,
            totalBytes = totalBytes,
            crc = crc,
            createdAt = now,
            session = session,
            stream = stream,
            kind = kind,
            reqId = reqId,
        }
        self.buffers[bufKey] = buf
    end

    if not buf.parts[part] then
        buf.parts[part] = body
        buf.receivedCount = buf.receivedCount + 1
    end

    -- Check completion
    if buf.receivedCount >= buf.totalParts then
        local assembled = ""
        for i = 1, buf.totalParts do
            if buf.parts[i] then
                assembled = assembled .. buf.parts[i]
            end
        end
        self.buffers[bufKey] = nil

        local unescaped = self:Unescape(assembled)
        local calcCrc = self:CalculateCRC32(unescaped)
        if string.upper(calcCrc) == string.upper(buf.crc) or buf.crc == "00000000" then
            self:DispatchMessage(buf.kind, buf.stream, buf.reqId, buf.session, unescaped)
        else
            if self.debugEnabled then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff3333[LIFE335:ERR]|r Reassembly CRC Mismatch! Expected %s got %s", buf.crc, calcCrc))
            end
        end
    end
end

function Protocol:DispatchMessage(kind, stream, reqId, session, payload)
    if LifeDashboard.Store and LifeDashboard.Store.HandleMessage then
        LifeDashboard.Store:HandleMessage(kind, stream, reqId, session, payload)
    end
end

-- ─── Buffer Pruning ──────────────────────────────────────────────────────────
function Protocol:PruneExpiredBuffers()
    local now = GetTime()
    for k, buf in pairs(self.buffers) do
        if now - buf.createdAt > self.ASSEMBLY_TIMEOUT_SEC then
            self.buffers[k] = nil
        end
    end
end
