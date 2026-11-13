-- Shipped beast data, keyed by creature (NPC) ID.
--
-- SEED DATA FOR TESTING ONLY. These are well-known Classic rares plus a couple
-- of common beasts so every status can be tested. The IDs, levels and zones
-- were written from memory and must be checked against the real data source
-- before release. The full list will be generated from that source.
--
-- Fields:
--   name     creature name (enUS)
--   family   pet family (enUS)
--   level    level, or { min, max }
--   zone     main zone (enUS)
--   rarity   "unique" (one of a kind / summoned), "rare" (rare spawn) or "common"
--   note     optional short collector note
local _, ns = ...

ns.Beasts = {
    -- Rares
    [2850]  = { name = "Broken Tooth",        family = "Cat",    level = 37, zone = "Badlands",         rarity = "rare", note = "1.0 attack speed" },
    [5828]  = { name = "Humar the Pridelord", family = "Cat",    level = 23, zone = "The Barrens",      rarity = "rare" },
    [521]   = { name = "Lupos",               family = "Wolf",   level = 23, zone = "Duskwood",         rarity = "rare", note = "Deals shadow damage" },
    [10200] = { name = "Rak'shiri",           family = "Cat",    level = 57, zone = "Winterspring",     rarity = "rare" },
    [10741] = { name = "Sian-Rotam",          family = "Cat",    level = 60, zone = "Winterspring",     rarity = "rare" },
    [5356]  = { name = "Snarler",             family = "Wolf",   level = 42, zone = "Feralas",          rarity = "rare" },
    [2175]  = { name = "Shadowclaw",          family = "Cat",    level = 13, zone = "Darkshore",        rarity = "rare" },
    [5807]  = { name = "The Rake",            family = "Cat",    level = 10, zone = "Mulgore",          rarity = "rare" },
    [5842]  = { name = "Takk the Leaper",     family = "Raptor", level = 19, zone = "The Barrens",      rarity = "rare" },
    [1130]  = { name = "Bjarn",               family = "Bear",   level = 12, zone = "Dun Morogh",       rarity = "rare" },
    [10077] = { name = "Deathmaw",            family = "Wolf",   level = 53, zone = "Burning Steppes",  rarity = "rare" },
    [12431] = { name = "Gorefang",            family = "Wolf",   level = 13, zone = "Silverpine Forest", rarity = "rare" },

    -- Uniques (summoned or event creatures)
    [3475]  = { name = "Echeyakee",           family = "Cat",    level = 16, zone = "The Barrens",      rarity = "unique", note = "Summoned by a Horn of Echeyakee quest" },
    [3619]  = { name = "Ghost Saber",         family = "Cat",    level = 19, zone = "Darkshore",        rarity = "unique", note = "Summoned at the Cliffspring Falls cave" },

    -- Commons
    [299]   = { name = "Young Wolf",          family = "Wolf",   level = { 1, 2 }, zone = "Elwynn Forest", rarity = "common" },
    [2955]  = { name = "Plainstrider",        family = "Tallstrider", level = { 1, 2 }, zone = "Mulgore",  rarity = "common" },
}
