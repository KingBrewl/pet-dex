-- PetDex core: namespace, event dispatch, saved variables and small helpers.
local addonName, ns = ...

ns.name = addonName
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (GetMeta and GetMeta(addonName, "Version")) or "dev"

-- Forever is identified by its interface band (16xxx), never by WOW_PROJECT_ID,
-- which has reported different values across Forever builds.
local INTERFACE = select(4, GetBuildInfo())
ns.isForever = INTERFACE >= 16000 and INTERFACE < 20000

---------------------------------------------------------------------------
-- Printing
---------------------------------------------------------------------------
-- Forever's FrameXML has dropped several old global helpers, so we avoid
-- relying on things like tostringall and build strings ourselves.
local function Join(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    return table.concat(parts, " ")
end

function ns:Print(...)
    print("|cff33ff99PetDex|r: " .. Join(...))
end

function ns:Debug(...)
    if self.db and self.db.settings.debug then
        print("|cff888888PetDex debug|r: " .. Join(...))
    end
end

---------------------------------------------------------------------------
-- Events: modules subscribe with ns:On(event, handler).
-- Handlers receive (event, ...) exactly as the game sends them.
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local handlers = {}

function ns:On(event, handler)
    if not handlers[event] then
        -- An event the client doesn't know raises an error; log it and move on
        -- so a renamed event on Forever can't break the whole addon.
        local ok = pcall(frame.RegisterEvent, frame, event)
        if not ok then
            ns.unknownEvents = ns.unknownEvents or {}
            table.insert(ns.unknownEvents, event)
            return
        end
        handlers[event] = {}
    end
    table.insert(handlers[event], handler)
end

frame:SetScript("OnEvent", function(_, event, ...)
    for _, handler in ipairs(handlers[event]) do
        handler(event, ...)
    end
end)

---------------------------------------------------------------------------
-- Saved variables
--
-- PetDexDB (account-wide):
--   version     schema version, for future migrations
--   settings    user toggles
--   beasts      [npcID] = { seen, lastSeen, lastZone, tamed, tameCount,
--                           firstTamedBy, source }
--   discovered  [npcID] = beasts missing from Data/Beasts.lua that we learned
--                         about in game: { name, family, minLevel, maxLevel,
--                         zones = { [zoneName] = true }, rarity, verified }
--   chars       [charKey] = { pets = { [petGUID] = npcID },
--                             unidentified = { stable pets we couldn't match } }
---------------------------------------------------------------------------
local DB_VERSION = 1
local DEFAULT_SETTINGS = {
    tooltip = true,  -- add PetDex status to beast tooltips
    announce = true, -- chat message for new tames and first rare sightings
    debug = false,
}

local function InitDB()
    PetDexDB = PetDexDB or {}
    local db = PetDexDB
    db.version = db.version or DB_VERSION
    db.settings = db.settings or {}
    for key, value in pairs(DEFAULT_SETTINGS) do
        if db.settings[key] == nil then
            db.settings[key] = value
        end
    end
    db.beasts = db.beasts or {}
    db.discovered = db.discovered or {}
    db.chars = db.chars or {}
    ns.db = db
end

ns:On("ADDON_LOADED", function(_, loaded)
    if loaded == addonName then
        InitDB()
    end
end)

ns:On("PLAYER_LOGIN", function()
    ns.charKey = UnitName("player") .. "-" .. GetRealmName()
    ns.playerClass = select(2, UnitClass("player"))
    if ns.unknownEvents then
        ns:Debug("client does not know events:", table.concat(ns.unknownEvents, ", "))
    end
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- GUIDs look like "Creature-0-serverID-instanceID-zoneUID-npcID-spawnUID".
-- Returns the GUID type ("Creature", "Pet", ...) and the ID in field six.
function ns.ParseGUID(guid)
    if not guid then return end
    local kind, _, _, _, _, id = strsplit("-", guid)
    return kind, tonumber(id)
end

function ns.NPCIDFromGUID(guid)
    local kind, id = ns.ParseGUID(guid)
    if kind == "Creature" then
        return id
    end
end

function ns.GetLocation()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    return GetZoneText(), mapID
end

function ns.GetCharData()
    local chars = ns.db.chars
    local data = chars[ns.charKey]
    if not data then
        data = { pets = {}, unidentified = {} }
        chars[ns.charKey] = data
    end
    return data
end
