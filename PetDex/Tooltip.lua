-- Tooltip: adds collection status to beast tooltips for hunters.
local _, ns = ...

local STATUS_TEXT = {
    tamed = "|cff40ff40Tamed|r",
    seen = "|cffffd100Seen, not yet tamed|r",
}
local UNTAMED_TEXT = "|cff9d9d9dNot yet tamed|r"
local RARITY_TEXT = {
    rare = "  |cff0070ddRare|r",
    unique = "  |cffa335eeUnique|r",
}

local function AddStatus(tooltip, guid, unit)
    if tooltip ~= GameTooltip or not ns.db or not ns.db.settings.tooltip then return end
    if ns.playerClass ~= "HUNTER" and not ns.db.settings.debug then return end

    local npcID = ns.NPCIDFromGUID(guid or (unit and UnitGUID(unit)))
    if not npcID then return end
    local beast = ns:GetBeast(npcID)
    if not beast then return end

    -- Status is about the look: "Tamed" means you own this look, even if it
    -- came from a different NPC.
    local looks = ns:GetLooks(npcID)
    local text
    if #looks == 1 then
        local look = ns:GetLook(looks[1])
        text = (STATUS_TEXT[ns:GetLookStatus(looks[1])] or UNTAMED_TEXT)
            .. (RARITY_TEXT[look and look.rarity] or "")
    else
        -- We can't tell which look this one is wearing, so summarise them all.
        local tamed = 0
        for _, lookID in ipairs(looks) do
            if ns:GetLookStatus(lookID) == "tamed" then
                tamed = tamed + 1
            end
        end
        text = ("%d/%d looks tamed"):format(tamed, #looks)
    end
    tooltip:AddLine("|cff33ff99PetDex|r: " .. text)
    if beast.note then
        tooltip:AddLine(beast.note, 0.7, 0.7, 0.7, true)
    end
end

-- The modern engine uses TooltipDataProcessor; older clients use OnTooltipSetUnit.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        AddStatus(tooltip, data and data.guid)
    end)
else
    GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
        local _, unit = tooltip:GetUnit()
        AddStatus(tooltip, nil, unit)
        tooltip:Show()
    end)
end
