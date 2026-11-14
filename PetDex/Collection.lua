-- Collection model.
--
-- Facts are recorded per NPC (the game identifies units by NPC ID): what the
-- player has seen and tamed, plus beasts learned in game that the shipped data
-- doesn't cover. Dex entries are LOOKS, and a look's status is derived from
-- the NPCs that wear it, so correcting the NPC -> look data fixes everyone's
-- dex without touching saved variables.
local _, ns = ...

local RARITY_RANK = { common = 1, rare = 2, unique = 3 }

---------------------------------------------------------------------------
-- Look index, built once from shipped data
---------------------------------------------------------------------------
local lookNPCs = {} -- [lookID] = { npcID, ... }

for npcID, beast in pairs(ns.Beasts) do
    for _, lookID in ipairs(beast.looks or {}) do
        lookNPCs[lookID] = lookNPCs[lookID] or {}
        table.insert(lookNPCs[lookID], npcID)
        ns.Looks[lookID] = ns.Looks[lookID] or { label = beast.name, family = beast.family }
    end
end

-- A look is only as rare as the most common NPC that wears it.
for lookID, look in pairs(ns.Looks) do
    if not look.rarity then
        local rarity
        for _, npcID in ipairs(lookNPCs[lookID] or {}) do
            local npcRarity = ns.Beasts[npcID].rarity or "common"
            if not rarity or RARITY_RANK[npcRarity] < RARITY_RANK[rarity] then
                rarity = npcRarity
            end
        end
        look.rarity = rarity or "common"
    end
end

-- NPCs we have no look data for (discovered in game, or shipped without
-- looks) stand in as their own look, "npc:<id>", until the data covers them.
local function StandInNPC(lookID)
    return type(lookID) == "string" and tonumber(lookID:match("^npc:(%d+)$"))
end

---------------------------------------------------------------------------
-- NPCs
---------------------------------------------------------------------------
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

-- NPC-level "tamed", "seen" or nil: has this NPC been tamed or seen at all.
function ns:GetStatus(npcID)
    local record = self.db.beasts[npcID]
    if not record then return nil end
    if record.tamed then return "tamed" end
    if record.seen then return "seen" end
end

-- Spawn rarity of the NPC (rare spawns are worth announcing even when their
-- look is common).
function ns:IsRare(npcID)
    local beast = self:GetBeast(npcID)
    return beast ~= nil and (beast.rarity == "rare" or beast.rarity == "unique")
end

---------------------------------------------------------------------------
-- Looks
---------------------------------------------------------------------------
function ns:GetLooks(npcID)
    local beast = ns.Beasts[npcID]
    if beast and beast.looks and #beast.looks > 0 then
        return beast.looks
    end
    return { "npc:" .. npcID }
end

function ns:GetLookNPCs(lookID)
    local npcID = StandInNPC(lookID)
    if npcID then
        return { npcID }
    end
    return lookNPCs[lookID] or {}
end

-- { label, family, rarity, standIn } or nil
function ns:GetLook(lookID)
    local npcID = StandInNPC(lookID)
    if not npcID then
        return ns.Looks[lookID]
    end
    local beast = self:GetBeast(npcID)
    if beast then
        return { label = beast.name, family = beast.family, rarity = beast.rarity or "common", standIn = true }
    end
end

-- Does this NPC record show this look? An NPC with a single look always shows
-- it; for NPCs with several, only looks confirmed in record.looks count.
local function RecordLookStatus(npcID, record, lookID)
    if record.looks and record.looks[lookID] then
        return record.looks[lookID]
    end
    if #ns:GetLooks(npcID) == 1 then
        if record.tamed then return "tamed" end
        if record.seen then return "seen" end
    end
end

-- "tamed", "seen" or nil
function ns:GetLookStatus(lookID)
    local status
    for _, npcID in ipairs(self:GetLookNPCs(lookID)) do
        local record = self.db.beasts[npcID]
        local npcStatus = record and RecordLookStatus(npcID, record, lookID)
        if npcStatus == "tamed" then
            return "tamed"
        end
        status = status or npcStatus
    end
    return status
end

-- Calls fn(lookID, look) for every look in the collection: shipped looks,
-- shipped NPCs without look data, and discovered beasts proven tameable.
-- Returns the number of discovered beasts still waiting to be verified.
function ns:ForEachLook(fn)
    for lookID, look in pairs(ns.Looks) do
        fn(lookID, look)
    end
    for npcID, beast in pairs(ns.Beasts) do
        if not beast.looks or #beast.looks == 0 then
            local lookID = "npc:" .. npcID
            fn(lookID, self:GetLook(lookID))
        end
    end
    local unverified = 0
    for npcID, beast in pairs(self.db.discovered) do
        if beast.verified then
            local lookID = "npc:" .. npcID
            fn(lookID, self:GetLook(lookID))
        else
            unverified = unverified + 1
        end
    end
    return unverified
end

---------------------------------------------------------------------------
-- Recording
---------------------------------------------------------------------------

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

-- Remember exactly which look was seen or tamed, when we know it
-- (info.lookID). Never downgrades a tamed look to seen.
local function ConfirmLook(record, lookID, status)
    if not lookID then return end
    record.looks = record.looks or {}
    if record.looks[lookID] ~= "tamed" then
        record.looks[lookID] = status
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
    ConfirmLook(record, info.lookID, "seen")
end

local function TamedLooks(npcID)
    local tamed = {}
    for _, lookID in ipairs(ns:GetLooks(npcID)) do
        if ns:GetLookStatus(lookID) == "tamed" then
            tamed[lookID] = true
        end
    end
    return tamed
end

-- source: "tame" (watched it happen), "pet" or "stable" (matched an existing pet)
-- info.lookID: the exact look, if known.
-- Returns true if this added a new look to the collection.
function ns:MarkTamed(npcID, info, source)
    info.tamed = true
    self:Discover(npcID, info)
    local before = TamedLooks(npcID)
    local record = self:GetRecord(npcID, true)
    local now = time()
    record.seen = record.seen or now
    record.tamed = record.tamed or now
    record.firstTamedBy = record.firstTamedBy or ns.charKey
    record.source = record.source or source
    if source == "tame" then
        record.tameCount = (record.tameCount or 0) + 1
    end
    ConfirmLook(record, info.lookID, "tamed")

    local isNew = false
    for lookID in pairs(TamedLooks(npcID)) do
        if not before[lookID] then
            isNew = true
        end
    end
    if isNew and self.db.settings.announce then
        local stats = self:GetStats()
        self:Print(("Added %s to your collection! (%d/%d looks)"):format(info.name, stats.tamed, stats.total))
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

---------------------------------------------------------------------------
-- Stats, counted in looks
---------------------------------------------------------------------------
function ns:GetStats()
    local stats = { total = 0, seen = 0, tamed = 0, rares = 0, raresTamed = 0 }
    stats.unverified = self:ForEachLook(function(lookID, look)
        local status = self:GetLookStatus(lookID)
        stats.total = stats.total + 1
        if status then stats.seen = stats.seen + 1 end
        if status == "tamed" then stats.tamed = stats.tamed + 1 end
        if look and (look.rarity == "rare" or look.rarity == "unique") then
            stats.rares = stats.rares + 1
            if status == "tamed" then stats.raresTamed = stats.raresTamed + 1 end
        end
    end)
    return stats
end
