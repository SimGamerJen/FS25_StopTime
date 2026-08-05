-- Stop Time
-- Vehicle-safe input handling based on the original working implementation.

FreezeTimeMod = {}

local MOD_VERSION = "1.1.0.7"
local MESSAGE_DURATION_MS = 4000
local MESSAGE_X = 0.985
local MESSAGE_Y = 0.855
local MESSAGE_TEXT_SIZE = 0.020
local freezeKey = Input.KEY_0
local isFrozen = false

FreezeTimeMod.keyHandled = false
FreezeTimeMod.lastTimeScale = 1
FreezeTimeMod.messageText = nil
FreezeTimeMod.messageRemainingMs = 0

local function logInfo(formatString, ...)
    local message = string.format(formatString, ...)

    if Logging ~= nil and Logging.info ~= nil then
        Logging.info("[FS25_StopTime] %s", message)
    else
        print(string.format("[FS25_StopTime] %s", message))
    end
end

local function getCurrentTimeScale()
    if g_currentMission == nil or g_currentMission.missionInfo == nil then
        return nil
    end

    return tonumber(g_currentMission.missionInfo.timeScale)
end

local function getMissionRoleState()
    local mission = g_currentMission
    if mission == nil then
        return false, false, false
    end

    local isClient = mission.getIsClient ~= nil and mission:getIsClient()
    local isServer = mission.getIsServer ~= nil and mission:getIsServer()
    local isMasterUser = mission.isMasterUser == true

    return isClient, isServer, isMasterUser
end

function FreezeTimeMod:getCanChangeTimeScale()
    local isClient, isServer, isMasterUser = getMissionRoleState()
    return isClient and (isServer or isMasterUser)
end

function FreezeTimeMod:showText(textKey)
    if g_currentMission == nil then
        return
    end

    local text = textKey
    if g_i18n ~= nil then
        text = g_i18n:getText(textKey)
    end

    self.messageText = text
    self.messageRemainingMs = MESSAGE_DURATION_MS
end

function FreezeTimeMod:updateMessage(dt)
    if self.messageText == nil or self.messageRemainingMs <= 0 then
        return
    end

    self.messageRemainingMs = math.max(self.messageRemainingMs - dt, 0)
    if self.messageRemainingMs == 0 then
        self.messageText = nil
    end
end

function FreezeTimeMod:draw()
    if self.messageText == nil
            or self.messageRemainingMs <= 0
            or renderText == nil
            or setTextAlignment == nil
            or setTextColor == nil
            or RenderText == nil then
        return
    end

    setTextAlignment(RenderText.ALIGN_RIGHT)
    if setTextBold ~= nil then
        setTextBold(true)
    end

    -- A small shadow keeps the message readable without putting it in a HUD panel.
    setTextColor(0, 0, 0, 0.8)
    renderText(MESSAGE_X + 0.001, MESSAGE_Y - 0.0015, MESSAGE_TEXT_SIZE, self.messageText)

    -- Match the original Stop Time message: independent green text at upper right.
    setTextColor(0.35, 0.90, 0.10, 1)
    renderText(MESSAGE_X, MESSAGE_Y, MESSAGE_TEXT_SIZE, self.messageText)

    if setTextBold ~= nil then
        setTextBold(false)
    end
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function FreezeTimeMod:toggleTime()
    local isClient, isServer, isMasterUser = getMissionRoleState()
    if not self:getCanChangeTimeScale() then
        logInfo(
            "toggle blocked by multiplayer permissions (client=%s, server=%s, masterUser=%s)",
            tostring(isClient),
            tostring(isServer),
            tostring(isMasterUser)
        )
        self:showText("stoptime_adminOnly")
        return
    end

    isFrozen = not isFrozen

    if isFrozen then
        local currentTimeScale = getCurrentTimeScale()
        if currentTimeScale ~= nil and currentTimeScale > 0 then
            self.lastTimeScale = currentTimeScale
        end

        g_currentMission:setTimeScale(0)
        self:showText("stoptime_timeStopped")
        logInfo("time stopped (previousScale=%s, appliedScale=0)", tostring(self.lastTimeScale))
    else
        local resumeTimeScale = tonumber(self.lastTimeScale) or 1
        if resumeTimeScale <= 0 then
            resumeTimeScale = 1
        end

        g_currentMission:setTimeScale(resumeTimeScale)
        self:showText("stoptime_timeResumed")
        logInfo("time resumed (appliedScale=%s)", tostring(resumeTimeScale))
    end
end

function FreezeTimeMod:loadMap(mapName)
    local currentTimeScale = getCurrentTimeScale()
    if currentTimeScale ~= nil and currentTimeScale > 0 then
        self.lastTimeScale = currentTimeScale
    else
        self.lastTimeScale = 1
    end

    isFrozen = false
    self.keyHandled = false
    self.messageText = nil
    self.messageRemainingMs = 0

    local isClient, isServer, isMasterUser = getMissionRoleState()
    logInfo(
        "loaded version %s (map=%s, client=%s, server=%s, masterUser=%s, keyApi=%s)",
        MOD_VERSION,
        tostring(mapName),
        tostring(isClient),
        tostring(isServer),
        tostring(isMasterUser),
        tostring(Input ~= nil and Input.isKeyPressed ~= nil and freezeKey ~= nil)
    )
end

function FreezeTimeMod:update(dt)
    if g_currentMission == nil
            or Input == nil
            or Input.isKeyPressed == nil
            or freezeKey == nil then
        self:updateMessage(dt)
        return
    end

    if Input.isKeyPressed(freezeKey) then
        if not self.keyHandled then
            self.keyHandled = true

            local isClient, isServer, isMasterUser = getMissionRoleState()
            logInfo(
                "KEY_0 detected (vehicle=%s, client=%s, server=%s, masterUser=%s)",
                tostring(g_currentMission.controlledVehicle ~= nil),
                tostring(isClient),
                tostring(isServer),
                tostring(isMasterUser)
            )

            self:toggleTime()
        end
    else
        self.keyHandled = false
    end

    self:updateMessage(dt)
end

function FreezeTimeMod:deleteMap()
    isFrozen = false
    self.keyHandled = false
    self.lastTimeScale = 1
    self.messageText = nil
    self.messageRemainingMs = 0
    logInfo("unloaded version %s", MOD_VERSION)
end

logInfo("script initialized (version %s)", MOD_VERSION)
addModEventListener(FreezeTimeMod)
