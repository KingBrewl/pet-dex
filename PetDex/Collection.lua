-- Collection model: what the player has seen and tamed, plus beasts learned
-- in game that the shipped data doesn't cover (Forever additions, gaps).
local _, ns = ...

function ns:GetBeast(npcID)
    return ns.Beasts[npcID] or self.db.discovered[npcID]
end

function ns:GetRecord(npcID, create)
    local record = self.db.beasts[npcID]
    if not record and create then
        record = {}
        self.db.beasts[npcID] = record
    end
    return record
end

-- "tamed", "seen" or nil
function ns:GetStatus(npcID)
    local record = self.db.beasts[npcID]
    if not record then return nil end
    if record.tamed then return "tamed" end
    if record.seen then return "seen" end
end

function ns:IsRare(npcID)
    local beast = self:GetBeast(npcID)
    return beast ~= nil and (beast.rarity == "rare" or beast.rarity == "unique")
end

-- Record or update a beast that isn't in Data/Beasts.lua.
-- info: { name, family, level, zone, classification, tamed }
function ns:Discover(npcID, info)
    if ns.Beasts[npcID] then return end
    local beast = self.db.discovered[npcID]
    if not beast then
        beast = { name = info.name, family = info.family, zones = {}, rarity = "common" }
        self.db.discovered[npcID] = beast
        self:Debug("discovered beast not in data:", info.name, npcID)
    end
    beast.family = beast.family or info.family
    if info.level and info.level > 0 then
        beast.minLevel = math.min(beast.minLevel or info.level, info.level)
        beast.maxLevel = math.max(beast.maxLevel or info.level, info.level)
    end
    if info.zone and info.zone ~= "" then
        beast.zones[info.zone] = true
    end
    if info.classification == "rare" or info.classification == "rareelite" then
        beast.rarity = "rare"
    end
    -- A beast with a pet family isn't necessarily tameable; a real tame proves it.
    if info.tamed then
        beast.verified = true
    end
end

function ns:MarkSeen(npcID, info)
    self:Discover(npcID, info)
    local record = self:GetRecord(npcID, true)
    local now = time()
    if not record.seen then
        record.seen = now
        if self:IsRare(npcID) and self.db.settings.announce then
            self:Print("First sighting of a rare:", "|cff0070dd" .. info.name .. "|r")
        end
    end
    record.lastSeen = now
    record.lastZone = info.zone
end

-- source: "tame" (watched it happen), "pet" or "stable" (matched an existing pet)
-- Returns true if this is a new entry in the collection.
function ns:MarkTamed(npcID, info, source)
    info.tamed = true
    self:Discover(npcID, info)
    local record = self:GetRecord(npcID, true)
    local isNew = not record.tamed
    local now = time()
    record.seen = record.seen or now
    record.tamed = record.tamed or now
    record.firstTamedBy = record.firstTamedBy or ns.charKey
    record.source = record.source or source
    if source == "tame" then
        record.tameCount = (record.tameCount or 0) + 1
    end
    if isNew and self.db.settings.announce then
        local stats = self:GetStats()
        self:Print(("Added %s to your collection! (%d/%d)"):format(info.name, stats.tamed, stats.total))
    end
    return isNew
end

-- Find a beast by name (and family, if given). Returns an npcID only when
-- exactly one beast matches, so renamed or ambiguous pets stay unmatched.
function ns:MatchByName(name, family)
    if not name then return end
    local found, count = nil, 0
    local function check(npcID, beast)
        if beast.name == name and (not family or not beast.family or beast.family == family) then
            found, count = npcID, count + 1
        end
    end
    for npcID, beast in pairs(ns.Beasts) do check(npcID, beast) end
    for npcID, beast in pairs(self.db.discovered) do check(npcID, beast) end
    if count == 1 then
        return found
    end
end

-- Totals count shipped beasts plus discovered beasts proven tameable.
-- Unverified discoveries are reported separately.
function ns:GetStats()
    local stats = { total = 0, seen = 0, tamed = 0, rares = 0, raresTamed = 0, unverified = 0 }
    local function count(npcID, beast)
        local status = self:GetStatus(npcID)
        stats.total = stats.total + 1
        if status then stats.seen = stats.seen + 1 end
        if status == "tamed" then stats.tamed = stats.tamed + 1 end
        if beast.rarity == "rare" or beast.rarity == "unique" then
            stats.rares = stats.rares + 1
            if status == "tamed" then stats.raresTamed = stats.raresTamed + 1 end
        end
    end
    for npcID, beast in pairs(ns.Beasts) do count(npcID, beast) end
    for npcID, beast in pairs(self.db.discovered) do
        if beast.verified then
            count(npcID, beast)
        else
            stats.unverified = stats.unverified + 1
        end
    end
    return stats
end
