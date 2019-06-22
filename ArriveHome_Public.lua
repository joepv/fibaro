--[[
%% properties
176 value
164 value
130 value
160 value
%% weather
%% events
%% globals
--]]

--[[
Leave Home
Version 1.0 (Januari 2019)
A LUA scene to control arrival at home.
Copyright (c)1992-2019 Joep Verhaeg <info@joepverhaeg.nl>

Documentation:
https://docs.joepverhaeg.nl/hibernate-home/
--]]

local startSource = fibaro:getSourceTrigger();

if fibaro:countScenes() > 1 then
  fibaro:debug(os.date("%a, %b %d") .. " Scene is already running, aborting...");
  fibaro:abort(); 
end


if (
 ( tonumber(fibaro:getValue(176, "value")) > 0  or  tonumber(fibaro:getValue(164, "value")) > 0  or  tonumber(fibaro:getValue(130, "value")) > 0 )
or
startSource["type"] == "other"
)
then
  local currentime = tonumber(os.time())
  local lastBreachedBijkeuken = currentime - tonumber(fibaro:getValue(130, "lastBreached"))
  local lastBreachedGarage = currentime - tonumber(fibaro:getValue(164, "lastBreached"))
  --fibaro:debug("current: " .. currentime)
  --fibaro:debug("bijkeuken lastbr: " .. tonumber(fibaro:getValue(130, "lastBreached")))
  --fibaro:debug("garage lastbr: " .. tonumber(fibaro:getValue(164, "lastBreached")))
  --fibaro:debug("Bijkeuken sec: " .. lastBreachedBijkeuken)
  --fibaro:debug("Garage sec: " .. lastBreachedGarage)
  local currentime = os.time(os.date("!*t"))
  local noMovement = 1
  if lastBreachedBijkeuken > 2 and lastBreachedBijkeuken < 310 then -- 10 seconds more than 5 min to bugfix second detection 
    noMovement = 0
  end
  if lastBreachedGarage > 2 and lastBreachedGarage < 310 then
    noMovement = 0
  end
  
  if fibaro:getGlobalValue("HomeState") == "away" and noMovement == 1 then
    fibaro:setGlobal("HomeState", "athome")
    fibaro:debug(os.date("%a, %b %d") .. " Set HomeState to \"athome\".")
    
    local currentLux = fibaro:getValue(160, "value")
    -- if light on overloop less that 10lx
    if ( tonumber(currentLux) < 10 ) then
      fibaro:debug(os.date("%a, %b %d") .. " Welcome home! Illuminance measuring " .. currentLux .. " lx, turn lights back on!")
      
      local sleepinglights = fibaro:getGlobalValue("SleepingLights")
      local lights = {}
      for match in (sleepinglights..'|'):gmatch("(.-)"..'|') do
        table.insert(lights, match);
      end
      
      -- check if there are sleeping lights
      local currentime =  os.time(os.date("!*t"))
      local sleepingtime = lights[1]
      local elapsedtime = currentime - sleepingtime
      
      if elapsedtime < 14400 and lights[2] ~= nill then -- if elapsed time is less than 4 hours.
        fibaro:debug(os.date("%a, %b %d") .. " Last member of the family left less than 4 hours ago, return lights to previous state!")
        for k, v in pairs(lights) do
          if k ~= 1 then -- skip first, is unixtimestamp
            fibaro:call(v , "turnOn")
            fibaro:debug("turn on: " .. v)
          end
        end
      else
        -- elapsed time is more than 4 hours, start normal arrival routine
        fibaro:debug(os.date("%a, %b %d") .. " Last member of the family left more than 4 hours ago, start arrive home scene!")
        
        fibaro:call(49, "setValue", "8") -- Spots garderobe
		    
        fibaro:call(140, "changeHue", "5021") -- Ledstip overloop
        fibaro:call(140, "changeSaturation", "199") -- Ledstip overloop
        fibaro:call(140, "changeBrightness", "114") -- Ledstip overloop
        fibaro:call(140, "turnOn") -- Ledstip overloop
        
        fibaro:call(44, "setValue", "8") -- Spots keuken
        fibaro:call(39, "setValue", "35") -- Kookeiland
        fibaro:call(29, "setValue", "10") -- Tafel
      end     
    else
      fibaro:debug(os.date("%a, %b %d") .. " Welcome home! Illuminance measuring " .. currentLux .. " lx, keep lights off.")
    end
    
    -- Make Coffee part from here
    if fibaro:getGlobalValue("MakeCoffee") == "friday" then
      local currentHour = tonumber(os.date("%H%M"))
      if currentHour > 1415 and currentHour < 1700 then
        fibaro:setGlobal("MakeCoffee", "no")
        fibaro:call(170, "turnOn") -- Koffiezetapparaat
        fibaro:debug(os.date("%a, %b %d") .. " It's a ziekenhuis vrijdag after 14:15, so turn on the coffee machine!")
      end
    end
    
  else
    if noMovement == 0 then
      fibaro:debug(os.date("%a, %b %d") .. " Motion detector active, do nothing for now.")
    end
  end
end