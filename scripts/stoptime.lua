FreezeTimeMod = {}
local modDirectory = g_currentModDirectory

local freezeKey = Input.KEY_0  -- You can change this to any desired key
local isFrozen = false

function FreezeTimeMod.update(dt)
    if Input.isKeyPressed(freezeKey) then
        if not FreezeTimeMod.keyHandled then
            isFrozen = not isFrozen
            g_currentMission:setTimeScale(isFrozen and 0 or 1)
            g_currentMission:addExtraPrintText(isFrozen and "Time Frozen" or "Time Resumed")
            FreezeTimeMod.keyHandled = true
        end
    else
        FreezeTimeMod.keyHandled = false
    end
end

addModEventListener(FreezeTimeMod)