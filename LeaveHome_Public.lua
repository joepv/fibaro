--[[
%% properties
%% weather
%% events
%% globals
JoepPresent
MoniquePresent
--]]

--[[
Leave Home
Version 1.0 (Januari 2019)
A LUA scene to control turn off all lights scene and set home state when leaving home.
Copyright (c)1992-2019 Joep Verhaeg <info@joepverhaeg.nl>

Documentation:
https://docs.joepverhaeg.nl/hibernate-home/
--]]

local startSource = fibaro:getSourceTrigger()

if fibaro:countScenes() > 1 then
  fibaro:debug(os.date("%a, %b %d") .. " Scene is already running...");
  --fibaro:abort(); 
end

if fibaro:getGlobalValue("JoepPresent") == "No" and fibaro:getGlobalValue("MoniquePresent") == "No" then
  fibaro:setGlobal("HomeState", "away")
  fibaro:debug(os.date("%a, %b %d") .. " Set HomeState to away.")
  fibaro:setGlobal("TurnOffExclusions", "0") -- no exclusions
  if fibaro:countScenes(33) < 1 then
  	fibaro:startScene(33) -- run Turn All Lights Off Scene
  else
    fibaro:debug(os.date("%a, %b %d") .. " Turn Of All Lights scene already running!")
  end
end