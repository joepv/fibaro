--[[
%% properties
158 value
158 armed
%% weather
%% events
%% globals
--]]

--[[
  ADVANCED WAKE-UP ROUTINE (script 2)
  WAKE-UP WITH FIBARO HOME CENTER 2 AND PHILIPS HUE
  Script version 1.0
  Copyright(c)1992-2018 Joep Verhaeg
  https://docs.joepverhaeg.nl/wakeup/
--]]

local startSource = fibaro:getSourceTrigger()

-- RUN CODE ONLY IF MOTION DETECTED AND SENSOR IS NOT ARMED! ---
if tonumber(fibaro:getValue(158, "value")) > 0 and tonumber(fibaro:getValue(158, "armed")) == 0 then
  local guestPresent = fibaro:getGlobal("GuestPresent")
  local holidayMode = fibaro:getGlobal("HolidayMode")
  local wakeupReady = fibaro:getGlobal("WakeUpReady")

  -- Run the code below this line only if there is no guest and we are not on holiday.
  if guestPresent == 'false' and holidayMode == 'false' then
    -- Check if Hue wake-up schedule time was triggered by the wake-up scene and start the morning wake routine.
    if wakeupReady == "1" then
      fibaro:setGlobal("WakeUpReady", 0) -- Disable trigger for current wake-up time.
      -- check lux
      local currentLux = tonumber(fibaro:getValue(160, "value")) -- id 160 is sensors light device.
      -- If it's dark then start wake-up routine
      if currentLux < 20 then
        fibaro:debug("Illuminance measuring " .. currentLux .. " lx, starting wake-up routine.")
        fibaro:call(44, "setValue", "8") -- Spots keuken (8%)
        fibaro:call(29, "setValue", "5") -- Tafel eethoek (5%)
        fibaro:call(106 , "turnOn") -- Bolles (aan)
        fibaro:call(118 , "turnOn") -- Spot voordeur (aan)
        fibaro:call(156, "sendPush", "Started wake-up routine. Debug: " .. currentLux .. " lx")
      else
        fibaro:debug("Illuminance measuring " .. currentLux .. " lx, do nothing.")
        fibaro:call(156, "sendPush", "Skipped wake-up routine. Debug: " .. currentLux .. " lx")
      end
    end
  end 
end