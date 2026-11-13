
-- FAF Caster - Milestone 2
-- Structured observer telemetry
-- UI-only mod

local CALLBACK_ID = "FAFCasterM2"
local PREFIX = "[FAFCASTER] "
local PLAYER_PREFIX = "[FAFCASTER:PLAYER] "

local updateCount = 0
local active = false

local function Log(message)
    LOG(PREFIX .. tostring(message))
end

local function Number(value)
    return tonumber(value) or 0
end

local function Get(parent, key)
    if type(parent) ~= "table" then
        return nil
    end

    return parent[key]
end

local function N(parent, key)
    return Number(Get(parent, key))
end

local function EscapeJson(value)
    local str = tostring(value or "")

    str = string.gsub(str, "\\", "\\\\")
    str = string.gsub(str, '"', '\\"')
    str = string.gsub(str, "\n", "\\n")
    str = string.gsub(str, "\r", "\\r")
    str = string.gsub(str, "\t", "\\t")

    return str
end

local function JsonString(value)
    return '"' .. EscapeJson(value) .. '"'
end

local function JsonNumber(value)
    return tostring(Number(value))
end

local function BuildPlayerRecord(armyId, score, gameTime, armyColor)
    local resources = Get(score, "resources") or {}
    local general = Get(score, "general") or {}
    local units = Get(score, "units") or {}

    local massIn = Get(resources, "massin") or {}
    local massOut = Get(resources, "massout") or {}
    local energyIn = Get(resources, "energyin") or {}
    local energyOut = Get(resources, "energyout") or {}
    local storage = Get(resources, "storage") or {}

    local kills = Get(general, "kills") or {}
    local lost = Get(general, "lost") or {}
    local built = Get(general, "built") or {}

    local fields = {}

    local function AddNumber(key, value)
        table.insert(
            fields,
            '"' .. key .. '":' .. JsonNumber(value)
        )
    end

    local function AddString(key, value)
        table.insert(
            fields,
            '"' .. key .. '":' .. JsonString(value)
        )
    end

    AddNumber("version", 2)
    AddNumber("update", updateCount)
    AddNumber("gameTime", gameTime)
    AddNumber("armyId", armyId)

    AddString("name", Get(score, "name"))
    AddString("type", Get(score, "type"))
    AddNumber("faction", Get(score, "faction"))
    if type(armyColor) == "string" and (string.match(armyColor, "^#?%x%x%x%x%x%x$") or string.match(armyColor, "^#?%x%x%x%x%x%x%x%x$")) then
        AddString("armyColor", armyColor)
    end

    -- Economy: mass
    AddNumber("massIncome", N(massIn, "rate"))
    AddNumber("massSpent", N(massOut, "rate"))
    AddNumber("massStored", N(storage, "storedMass"))
    AddNumber("massCapacity", N(storage, "maxMass"))
    AddNumber("massReclaimed", N(massIn, "reclaimed"))
    AddNumber("massReclaimRate", N(massIn, "reclaimRate"))
    AddNumber("massIncomeTotal", N(massIn, "total"))
    AddNumber("massSpentTotal", N(massOut, "total"))

    -- Economy: energy
    AddNumber("energyIncome", N(energyIn, "rate"))
    AddNumber("energySpent", N(energyOut, "rate"))
    AddNumber("energyStored", N(storage, "storedEnergy"))
    AddNumber("energyCapacity", N(storage, "maxEnergy"))
    AddNumber("energyReclaimed", N(energyIn, "reclaimed"))
    AddNumber("energyIncomeTotal", N(energyIn, "total"))
    AddNumber("energySpentTotal", N(energyOut, "total"))

    -- Army statistics
    AddNumber("units", N(general, "currentunits"))
    AddNumber("unitCap", N(general, "currentcap"))
    AddNumber("kills", N(kills, "count"))
    AddNumber("losses", N(lost, "count"))
    AddNumber("built", N(built, "count"))
    AddNumber("killMass", N(kills, "mass"))
    AddNumber("lostMass", N(lost, "mass"))
    AddNumber("score", N(general, "score"))

    -- Unit categories: cumulative built/lost/kills
    local categories = {
        "land",
        "air",
        "naval",
        "structures",
        "experimental",
        "cdr"
    }

    for _, category in ipairs(categories) do
        local stats = Get(units, category) or {}

        AddNumber(category .. "Built", N(stats, "built"))
        AddNumber(category .. "Lost", N(stats, "lost"))
        AddNumber(category .. "Kills", N(stats, "kills"))
    end

    return "{" .. table.concat(fields, ",") .. "}"
end

local function ProcessScore(score)
    if type(score) ~= "table" then
        return
    end

    updateCount = updateCount + 1

    local gameTime = GetGameTimeSeconds()
    local playerCount = 0
    local armyTable = GetArmiesTable()
    local armies = type(armyTable) == "table" and armyTable.armiesTable or nil

    for armyId, armyScore in pairs(score) do
        if type(armyScore) == "table" then
            local record = BuildPlayerRecord(
                armyId,
                armyScore,
                gameTime,
                type(armies) == "table" and type(armies[armyId]) == "table" and armies[armyId].color or nil
            )

            LOG(PLAYER_PREFIX .. record)
            playerCount = playerCount + 1
        end
    end

    Log(
        "Update " .. tostring(updateCount) ..
        ": " .. tostring(playerCount) ..
        " army records at " ..
        tostring(gameTime) .. " seconds"
    )
end

local function OnSync(sync)
    local success, err = pcall(function()
        if not active then
            return
        end

        if type(sync) ~= "table" then
            return
        end

        if sync.Score then
            ProcessScore(sync.Score)
        end

        if sync.Events and sync.Events.ACUDestroyed then
            Log("ACU destruction event received")
        end
    end)

    if not success then
        WARN(PREFIX .. "Telemetry error: " .. tostring(err))
    end
end

function Start(isReplay)
    Log("================================")
    Log("FAF CASTER MILESTONE 2 STARTED")
    Log("Replay mode: " .. tostring(isReplay))
    Log("Focus army: " .. tostring(GetFocusArmy()))
    Log("================================")

    if not IsObserver() then
        Log("Not an observer - telemetry disabled")
        return
    end

    Log("Observer detected")

    local success, armyInfo = pcall(GetArmiesTable)

    if success and type(armyInfo) == "table" then
        Log("Army table entries: " .. tostring(armyInfo.numArmies))
    end

    RemoveOnSyncCallback(CALLBACK_ID)

    active = true
    updateCount = 0

    AddOnSyncCallback(OnSync, CALLBACK_ID)

    Log("Structured telemetry callback registered")
    Log("Waiting for player statistics...")
end

function Stop()
    active = false
    RemoveOnSyncCallback(CALLBACK_ID)
    Log("Telemetry stopped")
end
