-- ALARM NOTIFICATION SCENE -----------------------------------------------------------------------
-- Version 1.0 (June 2022)
-- Copyright (c)2022 Joep Verhaeg <info@joepverhaeg.nl>

-- DESCRIPTION

-- SETUP
-- Fill in the user variables below.

-- Full documentation you can find at:
-- https://docs.joepverhaeg.nl/hc3-alarm/

-- USER VARIABLES ---------------------------------------------------------------------------------
local messageBird = { -- messagebird settings
    ["apikey"] = "disabled",
    ["language"] = "nl-nl",
    ["originator"] = "10",
    ["recipients"] = "31612345678",
    ["repeat"] = 2
}
local mobileDevices = {[1] = 2}  -- id(s) of the user to send a push message to.
                                 -- use the Lua table format, for example:
                                 -- 1 phone with id 15         -> {[1] = 15}
                                 -- 2 phones with id 15 and 25 -> {[1] = 15, [2] = 25}

-- DON'T EDIT BELOW THIS LINE IF YOU DON'T KNOW WHAT YOU'RE DOING! --------------------------------
function sendVoiceMessage(message)
    local apikey = messageBird["apikey"]
    messageBird['apikey'] = nil -- remove key from json data...
    messageBird['body'] = message
    net.HTTPClient():request("https://rest.messagebird.com/voicemessages", {
        options={
            method = 'POST',
            headers = {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "AccessKey " .. apikey
            },
            timeout = 5000,
            data = json.encode(messageBird)
        },
        success = function(response)
            hub.debug("AlarmNotificationScene", response.data)
        end,
        error = function(errorMessage)
            hub.debug("AlarmNotificationScene", "HTTPClient error" .. errorMessage)
        end
    })
end

-- Retrieve the breached zone(s)...
local breachedZones = api.get("/alarms/v1/partitions/breached")
if #breachedZones > 0 then
    -- Extract the breached device(s) in the breached zones...
    local breachedDevices = {}
    local breachedZoneCount = 0
    for _,a in ipairs(breachedZones) do
        local zoneInfo = api.get("/alarms/v1/partitions/" .. a)
        for _,b in ipairs(zoneInfo.devices) do
            if hub.getValue(b, "value") then
                --local zoneName = zoneInfo['name']
                local deviceName = hub.getName(b)
                local roomName = hub.getRoomNameByDeviceID(b)
                if breachedDevices[roomName] == nil then
                    breachedDevices[roomName] = {}
                    breachedZoneCount = breachedZoneCount + 1
                end
                -- Inbraak gedetecteerd in de zone BENEDEN bij het RAAM in de KEUKEN!
                table.insert(breachedDevices[roomName], deviceName)
            end
        end
    end

    local message = ""
    if breachedZoneCount == 1 then
        for k,v in pairs(breachedDevices) do
            message = string.format("Inbraak gedetecteerd bij %s in de %s!", string.lower(v[1]), string.lower(k))
        end
    else
        local breachedRooms = {}
        --hub.debug("AlarmNotificationScene", json.encode(breachedRooms))
        for room,devices in pairs(breachedDevices) do
            table.insert(breachedRooms, room)
        end
        message = string.format("Inbraak gedetecteerd in de ruimtes %s!", string.lower(table.concat(breachedRooms, " en ")))
    end
    
    -- Send an push message...
    hub.alert("push", mobileDevices, message)
    --hub.debug("AlarmNotificationScene", message)

    -- Send an MessageBird voice message...
    if messageBird['apikey'] ~= "disabled" then
        sendVoiceMessage(message)
    else
        hub.debug("AlarmNotificationScene", "MessageBird is disabled!")
    end
end

-- Todo; check for MessageBird errors:
-- {"errors":[{"code":25,"description":"Not enough balance","parameter":null}]}