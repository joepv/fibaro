--[[
%% autostart
%% properties
%% weather
%% events
%% globals
--]]

--[[
  ADVANCED WAKE-UP ROUTINE (script 1)
  WAKE-UP WITH FIBARO HOME CENTER 2 AND PHILIPS HUE
  Script version 1.0
  Copyright(c)1992-2018 Joep Verhaeg
  https://docs.joepverhaeg.nl/wakeup/
--]]

local sourceTrigger = fibaro:getSourceTrigger();
local hueIP  = '' -- IPv4 address like 192.168.1.1
local hueAPI = '' -- Philips Hue API key.

-- Function to convert decimal to binary number, because the Hue bridge uses a bitmask
-- to indicate which days in a 7 day cycle are chosen when you use recurring times.
-- Source: https://developers.meethue.com/documentation/datatypes-and-time-patterns
function bin(dec)
    local result = ""
    repeat
        local divres = dec / 2
        local int, frac = math.modf(divres)
        dec = int
        result = math.ceil(frac) .. result
    until dec == 0
    local StrNumber
    StrNumber = string.format(result, "s")
    local nbZero
    nbZero = 8 - string.len(StrNumber)
    local Sresult
    Sresult = string.rep("0", nbZero)..StrNumber
    return Sresult
end

function getHueSchedules(response)
  local hueSchedules = json.decode(response.data)
  local wakeUpAlarms = '' -- create an empty string to fill wake-up times as | seperated values.
  
  -- Loop thought the retrieved schedules.
  for k, v in pairs(hueSchedules) do
    local name        = v["name"]
    local timepattern = v["localtime"]
    local status      = v["status"]
    -- Check for schedules with the "Wake" string in it.
    if name:find('Wake') and status == 'enabled' then
      -- I only support weekly schedules at the moment. One-time of random schedules are ignored.
      local huedays, huetime = string.match(timepattern, 'W(.*)/T(.*)')
      -- Determine the day of the week (minus one, because Lua first week day starts at
      -- Sunday, and Hue bridge first week day starts at monday).
      local dayofweek = os.date("*t").wday-1
      if dayofweek == 0 then dayofweek = 7 end
      local humandayofweek = os.date("%a")
      local scheduleddays = bin(huedays)
      -- dayofweek+1 because a week is 7 days and binary is 8 digits, so
      -- a have a pre 0
      local waketoday = string.sub(scheduleddays, dayofweek+1, dayofweek+1)
      if waketoday == '1' then
        wakeUpAlarms =  wakeUpAlarms .. huetime:sub(1, -4) .. '|'
      end
      fibaro:debug("name:  " .. name)
      fibaro:debug("scheduleddays: " .. scheduleddays)
      fibaro:debug("dayofweek: " .. dayofweek)
      fibaro:debug("scheduledtime: " .. huetime:sub(1, -4))
      fibaro:debug("waketoday: " .. waketoday)
      fibaro:debug("----------------------------------------")
      -- Check if one or more schedules are set for today and store them in a global variable.
      if wakeUpAlarms ~= '' then
        fibaro:setGlobal("WakeUpTime", wakeUpAlarms:sub(1, -2)) -- remove last |
      else
        -- If no schedules are set, write disabled to the global variable.
        fibaro:setGlobal("WakeUpTime", "disabled")
      end
    end
  end
end

function tempFunc()
  -- At 4 o'clock read the wake-up schedules from the Hue bridge and set
  -- retreived data in the Fibaro system to trigger wake-up actions.
  if os.date("%H:%M") == "04:00" then
    local httpClient = net.HTTPClient()
    httpClient:request(
      "http://" .. hueIP .. "/api/" .. hueAPI .. "/schedules", {
        options = {method = "GET"},
        success = function(response) getHueSchedules(response) end,
        error = function(err)
          fibaro:debug("HTTP call error: " .. err)
          -- implement error here
        end
      })
  end
  
  -- Get global variables for nothing other than some check
  local wakeupReady = fibaro:getGlobal("WakeUpReady")
  local wakeupTime  = fibaro:getGlobal("WakeUpTime")
  
  if wakeupTime ~= "disabled" then
    local waketimes = {}
    for match in (wakeupTime..'|'):gmatch("(.-)"..'|') do
      table.insert(waketimes, match);
    end
    for k, v in pairs(waketimes) do
      if os.date("%H:%M") == v then
        fibaro:setGlobal("WakeUpReady", 1)
        fibaro:debug("It's wake-up time! Set motion detector ready!")
      end
    end
  --else
  --  fibaro:setGlobal("WakeUpReady", 0) 
  --  fibaro:debug("No wake-up schedule set for now.")
  end 
  
  -- Repeat function every minute.
  setTimeout(tempFunc, 60*1000)
end
  
if (sourceTrigger["type"] == "autostart") then
  fibaro:debug('auto start')
  tempFunc()
else
  local startSource = fibaro:getSourceTrigger();
  if (startSource["type"] == "other") then
    fibaro:debug('manual start')
    tempFunc()
  end
end