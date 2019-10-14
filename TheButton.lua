--[[
%% properties
%% events
194 CentralSceneEvent
%% globals
--]]

--[[
TheButton.lua
Version 1.0 (October 2019)
A LUA scene to rock your Fibaro Button!
Copyright (c)1992-2019 Joep Verhaeg <info@joepverhaeg.nl>

Documentation:
https://docs.joepverhaeg.nl/button/
--]]

local buttonData = fibaro:getSourceTrigger()["event"]["data"]
local pressCount = tostring(buttonData["keyAttribute"])

if (pressCount == "Pressed") then
  -- BEGIN 1x pressed
  fibaro:debug("Button 1x pressed.")
elseif (pressCount == "Pressed2") then
  -- BEGIN 2x pressed
  fibaro:debug("Button 2x pressed.")
elseif (pressCount == "Pressed3") then
  -- BEGIN 3x pressed
  fibaro:debug("Button 3x pressed.")
elseif (pressCount == "Pressed4") then
  -- BEGIN 4x pressed
  fibaro:debug("Button 4x pressed.")
elseif (pressCount == "Pressed5") then
  -- BEGIN 5x pressed
  fibaro:debug("Button 5x pressed.")
elseif (pressCount == "HeldDown") then
  -- Held down
  fibaro:debug("Button held down.")
elseif (pressCount == "Released") then
  -- Released
  fibaro:debug("Button released.")
else
  fibaro:debug("Error: unknown event data received!")
end
