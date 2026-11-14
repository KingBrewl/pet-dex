-- Model probe (debug): can this client tell us which model a unit is using?
--
-- Dex entries are looks, but GUIDs only carry NPC IDs. If a model frame loaded
-- with a unit reports a display ID or model file ID, PetDex can pin down the
-- exact look for NPCs with several looks and identify renamed pets.
-- Run /petdex probe [unit] (default target) and read the results in chat.
local _, ns = ...

local PROBE_DELAY = 1 -- seconds for the model to load before reading it

local modelFrame, scene, actor

-- Calls obj[method](obj) if it exists and reports what came back.
local function Try(label, obj, method)
    if not obj or type(obj[method]) ~= "function" then
        print(("  %s: |cff888888not available|r"):format(label))
        return
    end
    local ok, value = pcall(obj[method], obj)
    if not ok then
        print(("  %s: |cffff4040error|r %s"):format(label, tostring(value)))
    elseif ns.IsSecret(value) then
        print(("  %s: |cffffd100secret value|r"):format(label))
    else
        print(("  %s: |cff40ff40%s|r"):format(label, tostring(value)))
    end
end

local function CreateProbeFrames()
    -- Models only load while shown, so park a tiny invisible frame on screen.
    modelFrame = CreateFrame("PlayerModel", nil, UIParent)
    modelFrame:SetSize(32, 32)
    modelFrame:SetPoint("BOTTOMLEFT")
    modelFrame:SetAlpha(0)

    local ok, created = pcall(CreateFrame, "ModelScene", nil, UIParent)
    if ok then
        scene = created
        scene:SetSize(32, 32)
        scene:SetPoint("BOTTOMLEFT")
        scene:SetAlpha(0)
        if scene.CreateActor then
            actor = scene:CreateActor()
        end
    end
end

function ns:ProbeModel(unit)
    unit = (unit and unit ~= "") and unit or "target"
    if not UnitExists(unit) then
        self:Print("Nothing to probe: no", unit)
        return
    end
    if not modelFrame then
        CreateProbeFrames()
    end

    local guid = UnitGUID(unit)
    self:Print(("Probing %s: %s, NPC ID %s, GUID %s"):format(unit,
        ns.IsSecret(UnitName(unit)) and "<secret name>" or tostring(UnitName(unit)),
        tostring(ns.NPCIDFromGUID(guid)),
        ns.IsSecret(guid) and "secret" or "readable"))

    modelFrame:ClearModel()
    local okUnit, unitErr = pcall(modelFrame.SetUnit, modelFrame, unit)
    if not okUnit then
        print("  PlayerModel:SetUnit failed:", tostring(unitErr))
    end
    if actor and actor.SetModelByUnit then
        local okActor, actorErr = pcall(actor.SetModelByUnit, actor, unit)
        if not okActor then
            print("  ModelSceneActor:SetModelByUnit failed:", tostring(actorErr))
        end
    end

    C_Timer.After(PROBE_DELAY, function()
        self:Print("Probe results for", unit .. ":")
        Try("PlayerModel:GetDisplayInfo", modelFrame, "GetDisplayInfo")
        Try("PlayerModel:GetModelFileID", modelFrame, "GetModelFileID")
        Try("PlayerModel:GetModel", modelFrame, "GetModel")
        Try("ModelSceneActor:GetModelFileID", actor, "GetModelFileID")
        Try("ModelSceneActor:GetDisplayInfo", actor, "GetDisplayInfo")
        print("  Probe the same beast twice, and two beasts that look different, to see whether the numbers track the look.")
    end)
end
