
-- FAF Caster - Milestone 2
-- Structured observer telemetry
-- UI-only mod

local CALLBACK_ID = "FAFCasterM2"
local PREFIX = "[FAFCASTER] "
local PLAYER_PREFIX = "[FAFCASTER:PLAYER] "

local updateCount = 0
local active = false
local gameOverReported = false
local commanderDiagnosticReported = false

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
    -- FAF score.lua sets Defeated to a timestamp on defeat, then -1.
    -- Only explicit defeat data marks an army eliminated.
    if Get(score, "Defeated") ~= nil and Get(score, "Defeated") ~= false then
        table.insert(fields, '"defeated":true')
    else
        table.insert(fields, '"defeated":false')
    end
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

-- One-shot, read-only observer diagnostic. Does not change focus or emit player telemetry.
local function ProbeCommanderAccess()
    if commanderDiagnosticReported then
        return
    end
    commanderDiagnosticReported = true

    local ok, avatars = pcall(GetArmyAvatars)
    if not ok or type(avatars) ~= "table" then
        Log("Commander diagnostic: GetArmyAvatars unavailable (" .. tostring(avatars) .. ")")
        return
    end

    local total = 0
    local commanders = 0
    local armyIds = {}
    for _, unit in pairs(avatars) do
        total = total + 1
        local isCommanderOk, isCommander = pcall(function()
            return unit:IsInCategory("COMMAND")
        end)
        if isCommanderOk and isCommander then
            commanders = commanders + 1
            local armyOk, army = pcall(function() return unit:GetArmy() end)
            local healthOk, health = pcall(function() return unit:GetHealth() end)
            local maxOk, maxHealth = pcall(function() return unit:GetMaxHealth() end)
            local shieldOk, shield = pcall(function() return unit:GetShieldRatio() end)
            if armyOk then
                armyIds[tostring(army)] = true
            end
            Log("Commander diagnostic: army=" .. tostring(armyOk and army or "unavailable") ..
                " health=" .. tostring(healthOk and health or "unavailable") ..
                " maxHealth=" .. tostring(maxOk and maxHealth or "unavailable") ..
                " shieldRatio=" .. tostring(shieldOk and shield or "unavailable"))
        end
    end

    local armyCount = 0
    for _, _ in pairs(armyIds) do
        armyCount = armyCount + 1
    end
    Log("Commander diagnostic: avatars=" .. tostring(total) ..
        " commanders=" .. tostring(commanders) .. " distinctArmies=" .. tostring(armyCount) ..
        " focusArmy=" .. tostring(GetFocusArmy()))
end

-- Read-only diagnostic: inspect observer-visible synced entity IDs, without changing focus.
local function ProbeSyncedCommanderIds(sync)
    if updateCount ~= 10 then
        return
    end

    local data = Get(sync, "UnitData")
    local syncedCount = 0
    local resolvedCount = 0
    local commanderCount = 0
    local sampleCount = 0

    if type(data) == "table" then
        for entityId, _ in pairs(data) do
            syncedCount = syncedCount + 1
            local unitOk, unit = pcall(GetUnitById, tonumber(entityId))
            if unitOk and unit then
                resolvedCount = resolvedCount + 1
                local categoryOk, isCommander = pcall(function()
                    return unit:IsInCategory("COMMAND")
                end)
                if categoryOk and isCommander then
                    commanderCount = commanderCount + 1
                    if sampleCount < 8 then
                        sampleCount = sampleCount + 1
                        local armyOk, army = pcall(function() return unit:GetArmy() end)
                        local hpOk, hp = pcall(function() return unit:GetHealth() end)
                        local maxOk, maxHp = pcall(function() return unit:GetMaxHealth() end)
                        Log("Synced commander diagnostic: id=" .. tostring(entityId) ..
                            " army=" .. tostring(armyOk and army or "unavailable") ..
                            " health=" .. tostring(hpOk and hp or "unavailable") ..
                            " maxHealth=" .. tostring(maxOk and maxHp or "unavailable"))
                    end
                end
            end
        end
    end

    Log("Synced commander diagnostic: syncIds=" .. tostring(syncedCount) ..
        " resolved=" .. tostring(resolvedCount) ..
        " commanders=" .. tostring(commanderCount) ..
        " focusArmy=" .. tostring(GetFocusArmy()))
end

local function OnSync(sync)
    local success, err = pcall(function()
        if not active then
            return
        end

        if type(sync) ~= "table" then
            return
        end

        -- UI session state is an explicit game-over signal; never infer a winner from army counts.
        local stateOk, isOver = pcall(SessionIsGameOver)
        if stateOk and isOver and not gameOverReported then
            gameOverReported = true
            LOG("[FAFCASTER:MATCH] {\"event\":\"ended\",\"gameTime\":" .. JsonNumber(GetGameTimeSeconds()) .. "}")
        end

        if sync.Score then
            ProcessScore(sync.Score)
            if updateCount == 10 then
                local syncOk, syncErr = pcall(ProbeSyncedCommanderIds, sync)
                if not syncOk then
                    Log("Synced commander diagnostic failed: " .. tostring(syncErr))
                end
            end
            local diagnosticOk, diagnosticErr = pcall(ProbeCommanderAccess)
            if not diagnosticOk then
                commanderDiagnosticReported = true
                Log("Commander diagnostic failed: " .. tostring(diagnosticErr))
            end
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
    gameOverReported = false
    commanderDiagnosticReported = false

    AddOnSyncCallback(OnSync, CALLBACK_ID)

    Log("Structured telemetry callback registered")
    Log("Waiting for player statistics...")
end

function Stop()
    active = false
    RemoveOnSyncCallback(CALLBACK_ID)
    Log("Telemetry stopped")
end
