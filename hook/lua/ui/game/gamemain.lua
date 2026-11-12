
-- FAF Caster M1 Test
-- Main game UI hook

local OriginalCreateUI = CreateUI

function CreateUI(isReplay)
    OriginalCreateUI(isReplay)

    LOG("[FAFCASTER] Game UI initialised")

    local probePath = "/mods/m1-test/lua/ui/caster/probe.lua"

    LOG("[FAFCASTER] Loading probe: " .. probePath)

    local success, probe = pcall(import, probePath)

    if not success then
        WARN("[FAFCASTER] Failed to import probe: " .. tostring(probe))
        return
    end

    LOG("[FAFCASTER] Probe imported successfully")

    local started, err = pcall(probe.Start, isReplay)

    if not started then
        WARN("[FAFCASTER] Failed to start probe: " .. tostring(err))
        return
    end

    LOG("[FAFCASTER] Probe started successfully")
end
