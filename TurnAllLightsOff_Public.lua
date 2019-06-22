--[[
%% properties
%% weather
%% globals
--]]

--[[
Turn All Lights Off                                                   
Version 1.0 (Januari 2019)
A LUA scene to turn all lights off and save state.
Copyright (c)1992-2019 Joep Verhaeg <info@joepverhaeg.nl>

Documentation:
https://docs.joepverhaeg.nl/hibernate-home/
--]]

local startSource = fibaro:getSourceTrigger()

if fibaro:countScenes() > 1 then
  local currentrunning = fibaro:countScenes()
  fibaro:debug(os.date("%a, %b %d") .. " Scene is already running " .. currentrunning .. " times, aborting...")
  fibaro:abort()
end

-- Function to check if value exists in array --
local function has_value (tab, val)
  for index, value in ipairs(tab) do
    if value == val then
      return true
    end
  end
  return false
end

-- Get info about how to turn off the lights and the exclusions, put these in a table to check when
-- turning lights off!
local exclusionsVar = fibaro:getGlobalValue("TurnOffExclusions")
local exclusions = {}
for match in (exclusionsVar..'|'):gmatch("(.-)"..'|') do
  table.insert(exclusions, match);
end

local roomsWithLightsOn = {}
-- Create a string to set current time and add sleeping lights to a global variable.
-- I add time to check when arriving home, if more than x hours run the normal comming home scene
local devicesOn = os.time(os.date("!*t")) .. '|'

-- Check Z-Wave devices --
local i = 0
local maxNodeID = 1000
for i = 0, maxNodeID do
  if fibaro:getValue(i, "isLight") == "1" then
    if (fibaro:getValue(i, "value") >= "1") then
      local DeviceName = fibaro:getName(i)
      local RoomName = fibaro:getRoomNameByDeviceID(i)
      if not has_value(roomsWithLightsOn, RoomName) and RoomName ~= "unassigned" then
        table.insert(roomsWithLightsOn, RoomName)
      end
      if RoomName ~= "unassigned" then
        devicesOn = devicesOn .. i .. '|'
        fibaro:debug(os.date("%a, %b %d") .. " Device is on: " .. i .. " " .. DeviceName .. " " .. RoomName)
        -- If device if not on the exclusion list, turn it off
        local excluded = has_value(exclusions, tostring(i))
        if not has_value(exclusions, tostring(i)) then
          fibaro:call(i , "turnOff")
        else
          fibaro:debug(os.date("%a, %b %d") .. " Excluded device: " .. i)
        end
      end
    end
  end
end

-- Check Hue devices --
local j = 0
local maxHueID = 1000
for j = 0, maxHueID do
  if fibaro:getType(j) == "com.fibaro.philipsHueLight" then
    if (fibaro:getValue(j, "on") == "1") then
      local DeviceName = fibaro:getName(j)
      local RoomName = fibaro:getRoomNameByDeviceID(j)
      if not has_value(roomsWithLightsOn, RoomName) and RoomName ~= "unassigned" then
        table.insert(roomsWithLightsOn, RoomName)
      end
      devicesOn = devicesOn .. j .. '|'
      fibaro:debug(os.date("%a, %b %d") .. " Hue device is on: " .. j .. " " .. DeviceName .. " " .. RoomName)
      -- If Hue device if not on the exclusion list, turn it off
      if not has_value(exclusions, tostring(j)) then
        fibaro:call(j , "turnOff")
      end
    end
  end
end

fibaro:debug(os.date("%a, %b %d") .. " Write to SleepingLights Global Var: " .. devicesOn)
fibaro:setGlobal("SleepingLights", devicesOn:sub(1, -2)) -- remove last |