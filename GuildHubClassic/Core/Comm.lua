local _, ns = ...

local Comm = {
    peers = {},
    lastSyncAt = 0,
    pendingSnapshots = {},
}
ns.Comm = Comm

local Serializer = LibStub and LibStub("LibSerialize", true)
local Deflate = LibStub and LibStub("LibDeflate", true)

function Comm:Encode(message)
    if not Serializer or not Deflate then
        return nil, "libraries-unavailable"
    end
    local ok, serialized = pcall(Serializer.Serialize, Serializer, message)
    if not ok or not serialized then
        return nil, serialized
    end
    local compressed = Deflate:CompressDeflate(serialized, { level = 5 })
    if not compressed then
        return nil, "compression-failed"
    end
    return Deflate:EncodeForWoWAddonChannel(compressed)
end

function Comm:Decode(payload)
    if not Serializer or not Deflate or type(payload) ~= "string" then
        return nil, "libraries-unavailable"
    end
    local decoded = Deflate:DecodeForWoWAddonChannel(payload)
    if not decoded then
        return nil, "decode-failed"
    end
    local decompressed = Deflate:DecompressDeflate(decoded)
    if not decompressed then
        return nil, "decompression-failed"
    end
    local ok, success, message = pcall(Serializer.Deserialize, Serializer, decompressed)
    if not ok or not success then
        return nil, "deserialize-failed"
    end
    return message
end

function Comm:Envelope(kind, body)
    return {
        kind = kind,
        body = body,
        protocol = ns.protocolVersion,
        addonVersion = ns.version,
        flavor = ns.GameAPI:GetFlavor(),
        capabilities = ns.GameAPI:GetCapabilities().capabilityVersion,
        guildKey = ns.Database:GetGuildKey(),
        actor = ns.GameAPI:GetPlayerName(),
        sentAt = ns.GameAPI:Now(),
    }
end

function Comm:Send(kind, body, distribution, target)
    if ns.Database.db.settings.demoMode or not ns.GameAPI:IsInGuild() then
        return false
    end
    local encoded, errorMessage = self:Encode(self:Envelope(kind, body))
    if not encoded then
        ns.Database:LogError("comm-encode", errorMessage)
        return false
    end
    ns.Addon:SendCommMessage(ns.addonPrefix, encoded, distribution or "GUILD", target, "NORMAL")
    return true
end

function Comm:Initialize()
    ns.GameAPI:RegisterAddonPrefix(ns.addonPrefix)
    ns.Addon:RegisterComm(ns.addonPrefix, function(_, prefix, payload, distribution, sender)
        Comm:OnMessage(prefix, payload, distribution, sender)
    end)
end

function Comm:SendHello()
    self:Send("hello", {
        lastMergedAt = (ns.Database:GetGuild(false) or {}).lastMergedAt or 0,
    }, "GUILD")
end

function Comm:BroadcastOperation(operation)
    self:Send("operation", operation, "GUILD")
end

function Comm:BroadcastConfig(scope, value)
    self:Send("config", { scope = scope, value = value }, "GUILD")
end

function Comm:RequestSync()
    if not ns.GameAPI:IsInGuild() or ns.Database.db.settings.demoMode then
        return false
    end
    local token = ns.Database:NextId("sync")
    self.pendingSync = { token = token, offers = {} }
    self:Send("sync-request", { requestedAt = ns.GameAPI:Now(), token = token }, "GUILD")
    self.lastSyncAt = ns.GameAPI:Now()
    ns.GameAPI:After(2.0, function()
        local pending = Comm.pendingSync
        if not pending or pending.token ~= token then return end
        local bestName, bestFreshness
        for name, freshness in pairs(pending.offers) do
            if not bestFreshness or freshness > bestFreshness then
                bestName, bestFreshness = name, freshness
            end
        end
        if bestName then
            Comm:Send("snapshot-request", { token = token }, "WHISPER", bestName)
        end
    end)
    return true
end

function Comm:SendSnapshot(target, syncToken, retry)
    local snapshot = ns.Database:GetSnapshot()
    if snapshot then
        local deliveryToken = syncToken .. ":snapshot"
        self:Send("snapshot", {
            token = syncToken,
            deliveryToken = deliveryToken,
            snapshot = snapshot,
        }, "WHISPER", target)
        self.pendingSnapshots[target] = { token = deliveryToken, retries = retry or 0 }
        ns.GameAPI:After(6, function()
            local pending = Comm.pendingSnapshots[target]
            if not pending or pending.token ~= deliveryToken then return end
            if pending.retries < 1 then
                Comm:SendSnapshot(target, syncToken, pending.retries + 1)
            else
                ns.Database:LogError("snapshot-timeout", target)
                Comm.pendingSnapshots[target] = nil
            end
        end)
    end
end

function Comm:OnMessage(_, payload, _, sender)
    sender = ns.GameAPI:NormalizeCharacterName(sender)
    if not sender or sender == ns.GameAPI:GetPlayerName() then
        return
    end
    local message, errorMessage = self:Decode(payload)
    if not message then
        ns.Database:LogError("comm-decode", errorMessage)
        return
    end
    if message.guildKey ~= ns.Database:GetGuildKey() or message.flavor ~= ns.GameAPI:GetFlavor() then
        return
    end

    local previousPeer = self.peers[sender]
    self.peers[sender] = {
        version = message.addonVersion,
        protocol = message.protocol,
        capabilities = message.capabilities,
        lastSeen = ns.GameAPI:Now(),
        compatible = message.protocol == ns.protocolVersion,
        warned = previousPeer and previousPeer.warned or false,
    }

    if message.protocol ~= ns.protocolVersion then
        if not self.peers[sender].warned then
            self.peers[sender].warned = true
            ns:Print(ns:L("INCOMPATIBLE_VERSION", sender))
        end
        return
    end
    if message.kind == "hello" then
        return
    elseif message.kind == "operation" then
        local ok, reason = ns.Store:ApplyRemote(message.body, sender)
        if not ok then
            ns.Database:LogError("remote-operation", reason)
        end
    elseif message.kind == "config" then
        local body = message.body or {}
        local guild = ns.Database:GetGuild()
        if body.scope == "bankKeepers" and ns.Permissions:IsOfficer(sender)
            and type(body.value) == "table" then
            guild.config.bankKeepers = ns.Database:DeepCopy(body.value)
        elseif body.scope == "officerRankThreshold" and ns.Permissions:IsLeader(sender)
            and type(body.value) == "number" then
            guild.config.officerRankThreshold = body.value
        end
    elseif message.kind == "sync-request" then
        local token = message.body and message.body.token
        if token then
            ns.GameAPI:After(math.random() * 1.5, function()
                local guild = ns.Database:GetGuild(false)
                Comm:Send("sync-offer", {
                    token = token,
                    lastMergedAt = guild and guild.lastMergedAt or 0,
                }, "WHISPER", sender)
            end)
        end
    elseif message.kind == "sync-offer" then
        local body = message.body or {}
        if self.pendingSync and body.token == self.pendingSync.token then
            self.pendingSync.offers[sender] = tonumber(body.lastMergedAt) or 0
        end
    elseif message.kind == "snapshot-request" then
        local token = message.body and message.body.token
        if token then
            Comm:SendSnapshot(sender, token, 0)
        end
    elseif message.kind == "snapshot" then
        local body = message.body or {}
        local merged, reason = ns.Store:MergeSnapshot(body.snapshot, sender)
        if not merged then
            ns.Database:LogError("snapshot", reason)
        else
            self.lastSyncAt = ns.GameAPI:Now()
            self.pendingSync = nil
            self:Send("snapshot-ack", {
                token = body.token,
                deliveryToken = body.deliveryToken,
                merged = merged,
            }, "WHISPER", sender)
        end
    elseif message.kind == "snapshot-ack" then
        local pending = self.pendingSnapshots[sender]
        if pending and message.body and message.body.deliveryToken == pending.token then
            self.pendingSnapshots[sender] = nil
        end
    end
end

function Comm:GetPeers()
    local now = ns.GameAPI:Now()
    local result = {}
    for name, peer in pairs(self.peers) do
        if peer.lastSeen + 600 >= now then
            result[#result + 1] = {
                name = name,
                version = peer.version,
                protocol = peer.protocol,
                compatible = peer.compatible,
                lastSeen = peer.lastSeen,
            }
        end
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return result
end

function Comm:GetCompatiblePeerCount()
    local count = 0
    for _, peer in ipairs(self:GetPeers()) do
        if peer.compatible then
            count = count + 1
        end
    end
    return count
end
