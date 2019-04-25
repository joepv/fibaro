--[[
%% properties
170 value
%% events
%% globals
--]]

--[[
 __            _       _    _               ___            _             _ 
/ _\_ __  _ __(_)_ __ | | _| | ___ _ __    / __\___  _ __ | |_ _ __ ___ | |
\ \| '_ \| '__| | '_ \| |/ / |/ _ \ '__|  / /  / _ \| '_ \| __| '__/ _ \| |
_\ \ |_) | |  | | | | |   <| |  __/ |    / /__| (_) | | | | |_| | | (_) | |
\__/ .__/|_|  |_|_| |_|_|\_\_|\___|_|    \____/\___/|_| |_|\__|_|  \___/|_|
   |_|                                                                     
Version 1.0 (April 2019)
A virtual device to control your garden watering
Copyright (c)1992-2019 Joep Verhaeg <info@joepverhaeg.nl>

Documentation:
https://docs.joepverhaeg.nl/sprinklercontrol/
--]]

local sprinklerVirtualDevice = 182  -- virtual device id
local sprinklerWallplugId    = 174  -- garden wall plug
local phoneNotificationId    = 156  -- Joep's Phone
local sprinkerTimeInMinutes  = 15   -- default sprinkler timeout.

local sprinklerState = fibaro:getValue(sprinklerWallplugId, "value")
local startSource = fibaro:getSourceTrigger()

if startSource['type'] == 'property' then -- triggered by device.
  if tonumber(fibaro:getValue(sprinklerWallplugId, "value")) > 0 then
    fibaro:debug(os.date("%a, %b %d") .. " Sprinklers turned on.")
    fibaro:call(sprinklerVirtualDevice, "setProperty", "ui.lblStatus.value", "Watering the garden!")
    if fibaro:countScenes() > 1 then
        fibaro:abort()
    end
  else
    fibaro:debug(os.date("%a, %b %d") .. " Sprinklers turned off.")
    fibaro:call(sprinklerVirtualDevice, "setProperty", "ui.lblStatus.value", "Off")
    fibaro:call(sprinklerVirtualDevice, "setProperty", "ui.lblTimeOut.value", "--:--")
    if fibaro:countScenes() > 1 then
      fibaro:debug(os.date("%a, %b %d") .. " Killing scene to abort timer!")
      fibaro:killScenes(__fibaroSceneId) -- kill running scene to abort timer
    end
  end
elseif startSource['type'] == 'other' then -- triggered by virtual device/manual scene start.
  if fibaro:args() ~= nil then
    arguments = fibaro:args()
    sprinkerTimeInMinutes = arguments[1]
  end
  now=os.time()
  local runUntilTime = os.date("%H:%M",now+sprinkerTimeInMinutes*60)
  fibaro:call(sprinklerWallplugId, "turnOn")
  fibaro:debug(os.date("%a, %b %d") .. " Set timeout to " .. sprinkerTimeInMinutes .. " minutes.")
  fibaro:call(sprinklerVirtualDevice, "setProperty", "ui.lblTimeOut.value", runUntilTime)
  
  fibaro:sleep(sprinkerTimeInMinutes*60*1000) -- wait time before turn off
  
  fibaro:call(sprinklerWallplugId, "turnOff")
  fibaro:call(sprinklerVirtualDevice, "setProperty", "ui.lblTimeOut.value", "--:--")
  
  if phoneNotificationId > 0 then
    local phoneNotificationText = "Turned off watering (after " .. sprinkerTimeInMinutes .. " minutes)."
    fibaro:call(phoneNotificationId, "sendPush", phoneNotificationText)
  end
end