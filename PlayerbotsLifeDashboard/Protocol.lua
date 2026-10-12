local ADDON_NAME, LifeDashboard = ...
LifeDashboard = LifeDashboard or {}
_G["PlayerbotsLifeDashboard"] = LifeDashboard

local Protocol = {
    PREFIX = "LIFE335",
    VERSION = 1,
    MAX_WIRE_BYTES = 240,
    MAX_PARTS = 200,
    MAX_TOTAL_BYTES = 32768,
    MAX_INFLIGHT_BUFFERS = 10,
    ASSEMBLY_TIMEOUT_SEC = 10,
    debugEnabled = false,
    buffers = {}, -- [session..":"..stream..":"..seq..":"..reqId] = buffer
    reqCounter = 1000,
}

LifeDashboard.Protocol = Protocol

local KNOWN_INBOUND_KINDS = {
    ["WELCOME"] = true,
    ["CAPACITY"] = true,
    ["ROSTER"] = true,
    ["RECORDS"] = true,
    ["HUBS"] = true,
    ["ZONES"] = true,
    ["QUEUES"] = true,
    ["DELTA"] = true,
    ["TOMBSTONE"] = true,
    ["ALERT"] = true,
    ["PING"] = true,
    ["PONG"] = true,
    ["DENIED"] = true,
    ["CONFIG"] = true,
    ["BOT_DETAIL"] = true,
}

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
    local len = string.len(data or "")
    for i = 1, len do
        local byte = string.byte(data, i)
        local idx = bit.band(bit.bxor(crc, byte), 0xFF)
        crc = bit.bxor(bit.rshift(crc, 8), crcTable[idx])
    end
    crc = bit.bxor(crc, 0xFFFFFFFF)
    return string.format("%08X", crc)
end

-- ─── Percent Escaping / Decoding ──────────────────────────────────────────────
function Protocol:Escape(str)
    if not str then return "" end
    str = tostring(str)
    return string.gsub(str, "([|%t%n\r%%%z])", function(c)
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

function Protocol:BuildEscapedAtoms(payload)
    local atoms = {}
    local len = string.len(payload or "")
    for i = 1, len do
        local c = string.sub(payload, i, i)
        local b = string.byte(c)
        if b == 124 or b == 37 or b == 9 or b == 10 or b == 13 or b == 0 or b < 32 then
            table.insert(atoms, string.format("%%%02X", b))
        else
            table.insert(atoms, c)
        end
    end
    return atoms
end

-- ─── Outbound Transmission ───────────────────────────────────────────────────
function Protocol:NextRequestId()
    self.reqCounter = self.reqCounter + 1
    if self.reqCounter > 999999 then self.reqCounter = 1000 end
    return self.reqCounter
end

function Protocol:PlanChunks(atoms, kind, session, stream, seq, reqId, totalBytes, crc)
    local estimatedParts = math.max(1, math.ceil(#atoms / 150))

    local function pack(targetParts)
        local result = {}
        local currentChunk = {}
        local currentChunkLen = 0
        local currentPart = 1

        for _, atom in ipairs(atoms) do
            local atomLen = string.len(atom)
            local headerLen = string.len(string.format("%d|%s|%s|%s|%d|%d|%d|%d|%d|%s|",
                self.VERSION, kind, session, stream, seq, reqId, currentPart, targetParts, totalBytes, crc))
            local maxBodyLen = self.MAX_WIRE_BYTES - headerLen

            if currentChunkLen + atomLen > maxBodyLen then
                table.insert(result, table.concat(currentChunk))
                currentChunk = { atom }
                currentChunkLen = atomLen
                currentPart = currentPart + 1
                if currentPart > self.MAX_PARTS then
                    return nil
                end
            else
                table.insert(currentChunk, atom)
                currentChunkLen = currentChunkLen + atomLen
            end
        end
        if #currentChunk > 0 then
            table.insert(result, table.concat(currentChunk))
        end
        return result
    end

    local chunks = pack(estimatedParts)
    if not chunks then return nil end

    if #chunks ~= estimatedParts then
        chunks = pack(#chunks)
        if not chunks then return nil end
    end

    return chunks
end

function Protocol:SendMessage(kind, stream, reqId, payload)
    reqId = reqId or self:NextRequestId()
    stream = stream or "main"
    payload = payload or ""

    local session = LifeDashboard.sessionEpoch or "0"
    local crc = self:CalculateCRC32(payload)
    local totalBytes = string.len(payload)
    local seq = 1

    local playerName = UnitName("player")
    if not playerName then return nil end

    if totalBytes == 0 then
        local header = string.format("%d|%s|%s|%s|%d|%d|%d|%d|%d|%s|",
            self.VERSION, kind, session, stream, seq, reqId, 1, 1, 0, crc)
        local wireFrame = header
        if string.len(wireFrame) <= self.MAX_WIRE_BYTES then
            if self.debugEnabled then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ccff[LIFE335:OUT]|r %s (part 1/1)", wireFrame))
            end
            SendAddonMessage(self.PREFIX, wireFrame, "WHISPER", playerName)
        end
        return reqId
    end

    local atoms = self:BuildEscapedAtoms(payload)
    local chunks = self:PlanChunks(atoms, kind, session, stream, seq, reqId, totalBytes, crc)
    if not chunks then
        if self.debugEnabled then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff3333[LIFE335:ERR]|r Failed to plan chunks for payload.")
        end
        return nil
    end

    local totalParts = #chunks
    for part = 1, totalParts do
        local header = string.format("%d|%s|%s|%s|%d|%d|%d|%d|%d|%s|",
            self.VERSION, kind, session, stream, seq, reqId, part, totalParts, totalBytes, crc)
        local wireFrame = header .. chunks[part]

        -- Strict assert: wire frame must never exceed 240 bytes
        if string.len(wireFrame) <= self.MAX_WIRE_BYTES then
            if self.debugEnabled then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ccff[LIFE335:OUT]|r %s (part %d/%d)", wireFrame, part, totalParts))
            end
            SendAddonMessage(self.PREFIX, wireFrame, "WHISPER", playerName)
        else
            if self.debugEnabled then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff3333[LIFE335:ERR]|r Frame exceeded 240 bytes (%d), dropped", string.len(wireFrame)))
            end
        end
    end

    return reqId
end

-- ─── Inbound Packet Reception ────────────────────────────────────────────────
function Protocol:OnPacketReceived(message, sender, channel)
    if not message or string.sub(message, 1, 2) ~= "1|" then return end

    -- Verify channel is WHISPER
    if channel and channel ~= "WHISPER" then
        return
    end

    -- Verify self-whisper sender with exact normalized match
    local selfName = UnitName("player")
    if not sender or not selfName then return end

    local normalizedSender = sender
    local dashIdx = string.find(sender, "-", 1, true)
    if dashIdx then
        local sName = string.sub(sender, 1, dashIdx - 1)
        local sRealm = string.sub(sender, dashIdx + 1)
        local myRealm = GetRealmName()
        if not myRealm or sRealm == myRealm or sRealm == "" then
            normalizedSender = sName
        end
    end

    if string.lower(normalizedSender) ~= string.lower(selfName) and string.lower(sender) ~= string.lower(selfName) then
        return
    end

    -- Split header fields: V|kind|session|stream|seq|request|part|parts|bytes|crc|body
    local v, kind, session, stream, seq, reqId, part, parts, totalBytes, crc, body =
        string.match(message, "^(%d+)|([^|]+)|([^|]+)|([^|]+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|([%x%X]+)|(.*)$")

    if not v or not kind or not session or not stream or not seq or not reqId or not part or not parts or not totalBytes or not crc then
        return
    end

    v = tonumber(v)
    if v ~= self.VERSION then return end

    if not KNOWN_INBOUND_KINDS[kind] then return end

    seq = tonumber(seq)
    reqId = tonumber(reqId)
    part = tonumber(part)
    parts = tonumber(parts)
    totalBytes = tonumber(totalBytes)

    -- Strict validation of parts and totalBytes bounds (DASH-05)
    if not part or not parts or part < 1 or parts < 1 or part > parts or parts > self.MAX_PARTS then
        return
    end
    if not totalBytes or totalBytes < 0 or totalBytes > self.MAX_TOTAL_BYTES then
        return
    end
    if string.len(crc) ~= 8 then
        return
    end

    if self.debugEnabled then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff99[LIFE335:IN]|r %s stream=%s part=%d/%d len=%d", kind, stream, part, parts, string.len(body or "")))
    end

    if parts == 1 then
        -- Single-packet message: assemble and dispatch immediately
        local unescaped = self:Unescape(body)
        if string.len(unescaped) ~= totalBytes then
            if self.debugEnabled then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff3333[LIFE335:ERR]|r Single-part byte count mismatch! Expected %d got %d", totalBytes, string.len(unescaped)))
            end
            return
        end

        local calcCrc = self:CalculateCRC32(unescaped)
        if string.upper(calcCrc) == string.upper(crc) then
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
        -- Enforce buffer count cap
        local bufCount = 0
        for _ in pairs(self.buffers) do bufCount = bufCount + 1 end
        if bufCount >= self.MAX_INFLIGHT_BUFFERS then
            self:PruneExpiredBuffers()
            bufCount = 0
            for _ in pairs(self.buffers) do bufCount = bufCount + 1 end
            if bufCount >= self.MAX_INFLIGHT_BUFFERS then
                if self.debugEnabled then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff3333[LIFE335:ERR]|r In-flight buffer limit reached, dropped fragment.")
                end
                return
            end
        end

        buf = {
            parts = {},
            receivedCount = 0,
            totalParts = parts,
            totalBytes = totalBytes,
            crc = string.upper(crc),
            createdAt = now,
            session = session,
            stream = stream,
            kind = kind,
            reqId = reqId,
        }
        self.buffers[bufKey] = buf
    else
        -- Metadata consistency validation across chunks (DASH-05)
        if buf.totalParts ~= parts or buf.totalBytes ~= totalBytes or buf.crc ~= string.upper(crc) or buf.kind ~= kind then
            if self.debugEnabled then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff3333[LIFE335:ERR]|r Corrupted chunk metadata mismatch, discarded buffer.")
            end
            self.buffers[bufKey] = nil
            return
        end
    end

    if not buf.parts[part] then
        buf.parts[part] = body
        buf.receivedCount = buf.receivedCount + 1
    end

    -- Check completion
    if buf.receivedCount >= buf.totalParts then
        local complete = true
        for i = 1, buf.totalParts do
            if not buf.parts[i] then
                complete = false
                break
            end
        end

        if complete then
            local assembled = table.concat(buf.parts)
            self.buffers[bufKey] = nil

            local unescaped = self:Unescape(assembled)
            if string.len(unescaped) ~= buf.totalBytes then
                if self.debugEnabled then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff3333[LIFE335:ERR]|r Reassembled byte length mismatch! Expected %d got %d", buf.totalBytes, string.len(unescaped)))
                end
                return
            end

            local calcCrc = self:CalculateCRC32(unescaped)
            if string.upper(calcCrc) == buf.crc then
                self:DispatchMessage(buf.kind, buf.stream, buf.reqId, buf.session, unescaped)
            else
                if self.debugEnabled then
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffff3333[LIFE335:ERR]|r Reassembly CRC Mismatch! Expected %s got %s", buf.crc, calcCrc))
                end
            end
        end
    end
end

function Protocol:DispatchMessage(kind, stream, reqId, session, payload)
    if LifeDashboard.Store and LifeDashboard.Store.HandleMessage then
        LifeDashboard.Store:HandleMessage(kind, stream, reqId, session, payload)
    end
end

-- ─── Buffer Pruning & Cleanup ────────────────────────────────────────────────
function Protocol:PruneExpiredBuffers()
    local now = GetTime()
    for k, buf in pairs(self.buffers) do
        if now - buf.createdAt > self.ASSEMBLY_TIMEOUT_SEC then
            self.buffers[k] = nil
        end
    end
end

function Protocol:ResetBuffers()
    self.buffers = {}
end
