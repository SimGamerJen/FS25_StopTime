-- Stop Time
-- FS25-compatible time-scale toggle with multiplayer host/admin protection.

StopTime = StopTime or {}

StopTime.FROZEN_TIME_SCALE = 0.0001
StopTime.STOPPED_THRESHOLD = 0.001
StopTime.DEFAULT_RESUME_TIME_SCALE = 1
StopTime.actionEventId = nil
StopTime.lastTimeScale = StopTime.DEFAULT_RESUME_TIME_SCALE

local function getCurrentTimeScale()
    if g_currentMission == nil or g_currentMission.missionInfo == nil then
        return nil
    end

    return tonumber(g_currentMission.missionInfo.timeScale)
end

function StopTime:getIsTimeStopped()
    local timeScale = getCurrentTimeScale()
    return timeScale ~= nil and timeScale <= self.STOPPED_THRESHOLD
end

function StopTime:getCanChangeTimeScale()
    local mission = g_currentMission
    if mission == nil or not mission:getIsClient() then
        return false
    end

    return mission:getIsServer() or mission.isMasterUser == true
end

function StopTime:showNotification(textKey)
    if g_currentMission == nil or g_i18n == nil then
        return
    end

    local text = g_i18n:getText(textKey)
    if g_currentMission.addIngameNotification ~= nil
            and FSBaseMission ~= nil
            and FSBaseMission.INGAME_NOTIFICATION_OK ~= nil then
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_OK, text)
    elseif g_currentMission.addExtraPrintText ~= nil then
        g_currentMission:addExtraPrintText(text)
    end
end

function StopTime:onToggleTime(actionName, inputValue, callbackState, isAnalog)
    if g_currentMission == nil or g_gui == nil or g_gui.currentGui ~= nil then
        return
    end

    if not self:getCanChangeTimeScale() then
        self:showNotification("stoptime_adminOnly")
        return
    end

    if self:getIsTimeStopped() then
        local resumeTimeScale = tonumber(self.lastTimeScale) or self.DEFAULT_RESUME_TIME_SCALE
        if resumeTimeScale <= self.STOPPED_THRESHOLD then
            resumeTimeScale = self.DEFAULT_RESUME_TIME_SCALE
        end

        g_currentMission:setTimeScale(resumeTimeScale)
        self:showNotification("stoptime_timeResumed")
    else
        local currentTimeScale = getCurrentTimeScale()
        if currentTimeScale ~= nil and currentTimeScale > self.STOPPED_THRESHOLD then
            self.lastTimeScale = currentTimeScale
        end

        -- A very small positive value behaves as stopped time while avoiding
        -- simulation problems that can occur when the time scale is exactly 0.
        g_currentMission:setTimeScale(self.FROZEN_TIME_SCALE)
        self:showNotification("stoptime_timeStopped")
    end
end

function StopTime:registerActionEvent()
    if self.actionEventId ~= nil
            or g_inputBinding == nil
            or InputAction == nil
            or InputAction.STOPTIME_TOGGLE == nil then
        return
    end

    local registered, actionEventId = g_inputBinding:registerActionEvent(
        InputAction.STOPTIME_TOGGLE,
        self,
        self.onToggleTime,
        false,
        true,
        false,
        true
    )

    if registered and actionEventId ~= nil then
        self.actionEventId = actionEventId

        if g_inputBinding.setActionEventTextPriority ~= nil and GS_PRIO_VERY_LOW ~= nil then
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
        end
        if g_inputBinding.setActionEventTextVisibility ~= nil then
            g_inputBinding:setActionEventTextVisibility(actionEventId, true)
        end
    end
end

function StopTime:removeActionEvent()
    if self.actionEventId ~= nil and g_inputBinding ~= nil then
        g_inputBinding:removeActionEvent(self.actionEventId)
    end

    self.actionEventId = nil
end

function StopTime:loadMap(mapName)
    local currentTimeScale = getCurrentTimeScale()
    if currentTimeScale ~= nil and currentTimeScale > self.STOPPED_THRESHOLD then
        self.lastTimeScale = currentTimeScale
    else
        self.lastTimeScale = self.DEFAULT_RESUME_TIME_SCALE
    end
end

function StopTime:update(dt)
    -- Keep every connected client aware of the latest running time scale so
    -- either the host or a logged-in administrator can resume it correctly.
    local currentTimeScale = getCurrentTimeScale()
    if currentTimeScale ~= nil and currentTimeScale > self.STOPPED_THRESHOLD then
        self.lastTimeScale = currentTimeScale
    end
end

function StopTime:deleteMap()
    self:removeActionEvent()
    self.lastTimeScale = self.DEFAULT_RESUME_TIME_SCALE
end

local function onRegisterGlobalPlayerActionEvents(playerInputComponent)
    if playerInputComponent ~= nil
            and playerInputComponent.player ~= nil
            and playerInputComponent.player.isOwner then
        StopTime:registerActionEvent()
    end
end

local function onRemoveGlobalPlayerActionEvents(playerInputComponent)
    if playerInputComponent ~= nil
            and playerInputComponent.player ~= nil
            and playerInputComponent.player.isOwner then
        StopTime:removeActionEvent()
    end
end

if PlayerInputComponent ~= nil
        and PlayerInputComponent.registerGlobalPlayerActionEvents ~= nil
        and Utils ~= nil
        and Utils.appendedFunction ~= nil then
    PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
        PlayerInputComponent.registerGlobalPlayerActionEvents,
        onRegisterGlobalPlayerActionEvents
    )
end

if PlayerInputComponent ~= nil
        and PlayerInputComponent.removeGlobalPlayerActionEvents ~= nil
        and Utils ~= nil
        and Utils.appendedFunction ~= nil then
    PlayerInputComponent.removeGlobalPlayerActionEvents = Utils.appendedFunction(
        PlayerInputComponent.removeGlobalPlayerActionEvents,
        onRemoveGlobalPlayerActionEvents
    )
end

addModEventListener(StopTime)
