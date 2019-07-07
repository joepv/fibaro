--[[
%% autostart
%% properties
%% events
%% globals
--]]

--[[
  __  __                           _____            _             _ 
 |  \/  |                         / ____|          | |           | |
 | \  / | _____      _____ _ __  | |     ___  _ __ | |_ _ __ ___ | |
 | |\/| |/ _ \ \ /\ / / _ \ '__| | |    / _ \| '_ \| __| '__/ _ \| |
 | |  | | (_) \ V  V /  __/ |    | |___| (_) | | | | |_| | | (_) | |
 |_|  |_|\___/ \_/\_/ \___|_|     \_____\___/|_| |_|\__|_|  \___/|_|                                                        
Version 1.0 (June 2019)
A LUA scene to control your robot mower when it rains.
Copyright (c)1992-2019 Joep Verhaeg <info@joepverhaeg.nl>

Documentation:
https://docs.joepverhaeg.nl/mowercontrol/
--]]

if fibaro:countScenes() > 1 then
    log("Scene is already running, aborting...", 1);
    fibaro:abort(); 
  end
  
  function round(num, numDecimalPlaces)
      local mult = 10^(numDecimalPlaces or 0)
      return math.floor(num * mult + 0.5) / mult
  end
  
  function log(message, severity)
      local color = "#BDBDBD" -- off white
      if (tonumber(severity) == 1) then
          color = "#DE1F1F" -- red
      end
      if (tonumber(severity) == 2) then
          color = "#4D5DFF" -- Buienradar blue
      end
      if (tonumber(severity) == 71) then
          color = "#FF5716" -- gardena logo orange
      end
      if (tonumber(severity) == 3) then
          color = "#FF5716" -- gardena logo orange
      end
      if (tonumber(severity) == 83) then
          color = "#00AEBD" -- gardena sileno green
      end
      if (debug == true or tonumber(severity) == 1 or tonumber(severity) == 3) then
          fibaro:debug("<span style=\"color: " .. color .. "\">" .. os.date("%a, %b %d") .. " " .. message .. "</span>")
      end
  end
  
  function convertTime(mowerTime)
      --local mowerTime = "2019-06-21T06:00Z"
      mowerTime = string.sub(mowerTime, 1, 16)
      local xyear, xmonth, xday, xhour, xminute = mowerTime:match("(%d+)%-(%d+)%-(%d+)T(%d+):(%d+)")
      local mowerStatusTime = tonumber(os.time{year = xyear, month = xmonth, day = xday, hour = xhour, min = xminute})
      local summerClock = os.date("*t", mowerStatusTime)
      if (summerClock.isdst == true) then
          mowerStatusTime = mowerStatusTime + 7200
      else
          mowerStatusTime = mowerStatusTime + 3600
      end
      if (not xyear == "1969") then
          return os.date("%d-%m-%Y om %H:%M", mowerStatusTime)
      else
          return "n.v.t."
      end
  end
  
  function updateVirtualDevice(status, time)
      local statusTable = {
          uninitialised = "uninitialised",
          paused = "Gepauzeerd",
          ok_cutting = "Bezig met maaien",
          ok_searching = "Zoekt basisstation",
          ok_charging = "Laden",
          ok_leaving = "Verplaatsen naar startpunt",
          wait_updating = "wait_updating",
          wait_power_up = "wait_power_up",
          parked_timer = "Geparkeerd tot volgende start",
          parked_park_selected = "Geparkeerd",
          off_disabled = "off_disabled",
          off_hatch_open = "off_hatch_open",
          unknown = "unknown",
          error = "error",
          error_at_power_up = "error_at_power_up",
          off_hatch_closed = "off_hatch_closed",
          ok_cutting_timer_overridden = "ok_cutting_timer_overridden",
          parked_autotimer = "parked_autotimer",
          parked_weathertimer = "parked_weathertimer",
          parked_daily_limit_reached = "Voltooid",
          undefined = "undefined",
      }
      fibaro:call(mowerVirtualDevice, "setProperty", "ui.lblStatus.value", statusTable[status])
      fibaro:call(mowerVirtualDevice, "setProperty", "ui.lblNextStart.value", convertTime(time))
      if (status == "ok_cutting") then 
          fibaro:call(mowerVirtualDevice, "setProperty", "currentIcon", 1010) -- mowing icon
      else
          fibaro:call(mowerVirtualDevice, "setProperty", "currentIcon", 1009)  -- parked icon
      end
  end
  
  function sendMowerCommand(command)
      local payload = "{\"name\":\"" .. command .. "\"}"
      HC2:request(
          "https://sg-api.dss.husqvarnagroup.net/sg-1/devices/" .. mowerDeviceId .. "/abilities/mower/command?locationId=" .. gardenaLocation, {
              success = function(resp)
                          if resp.status ~= 200 and resp.status ~= 201 and resp.status ~= 204 then
                              log("Failed to send -" .. command .. "- command to the Gardena Smart System API!", 1)
                              -- send push
                          else
                              log("Succesfully send -" .. command .. "- command to the Gardena Smart System API!", 3)
                          end 
                        end,
              error =  function(resp) log("Error sending command to the Gardena Smart System API!", 1) end,
              options = {
                  headers = {['Content-Type'] = 'application/json', ['X-Session'] = gardenaToken, ['charset'] = 'UTF-8'}, data = payload,
                  method = 'POST',
                  timeout = 5000
              }
          }
      )
  end
  
  function processGardenaDevices(response)
      local mowerState = "unknown"
      local mowerSourceForNextStart = "unknown"
      local mowerTimestampNextStart = "unknown"
        local gardenaLocationId = json.decode(response)
      local gardenaDeviceName = gardenaLocationId.devices[2].name
      mowerDeviceId = gardenaLocationId.devices[2].id
      --local gardenaDeviceState = gardenaLocationId.devices[2].abilities[5].properties[2].value
      --log(response, 0)
      --log("GardenaDeviceName: " .. gardenaDeviceName, 0)
      --log("mowerDeviceId: " .. mowerDeviceId, 0)
      --log("gardenaDeviceState: " .. gardenaDeviceState, 0)
  
        -- Find mower in device list!
      for k,v in pairs(gardenaLocationId.devices) do
          if (v.category == "mower") then
              --log(v.id, 0)
              -- find other things
              for a, b in pairs(v.abilities) do
                  for c, d in pairs(b.properties) do
                      if (d.name == "status") then
                          mowerState = d.value
                      end
                      if (d.name == "source_for_next_start") then
                          mowerSourceForNextStart = d.value
                      end
                      if (d.name == "timestamp_next_start") then
                          mowerTimestampNextStart = d.value
                      end  
                  end
              end
          end
      end
      log("<strong>" .. gardenaDeviceName .. "</strong> status: " .. mowerState .. " | " .. mowerSourceForNextStart .. " | " .. mowerTimestampNextStart, 83)
      updateVirtualDevice(mowerState, mowerTimestampNextStart)
      getBuitenRadarData(mowerState, mowerSourceForNextStart, mowerTimestampNextStart, mowerDeviceId)
  end
  
  function getGardenaDevices(gardeneLocation, gardenaToken)
      --log(gardenaLocation .. "|" .. gardenaToken, 0)
      --log("GardenaLocations: " .. gardenaLocations, 0)
      --log("GardenaName: " .. gardenaName, 0)
      --log("GardenaLocation: " .. gardenaLocation, 0)
  
      -- Get Gardena Smart System device information...
      HC2:request(
          "https://sg-api.dss.husqvarnagroup.net/sg-1/devices?locationId=" .. gardenaLocation, {
              success = function(resp) processGardenaDevices(resp.data) end,
              error =  function(resp) log("Error retrieving device information from the Gardena Smart System API!", 1) end,
              options = {
                  headers = {['Content-Type'] = 'application/json',['X-Session'] = gardenaToken},
                  method = 'GET',
                  timeout = 5000
              }
          }
      )
  end
  
  function getGardenaLocation(response)
      local gardenaSession = json.decode(response)
      gardenaToken = gardenaSession.sessions.token
      local gardenaUserId = gardenaSession.sessions.user_id
      --log("GardenaSession:" .. gardenaSession, 0)
      log("Got token from server: " .. gardenaToken, 83)
      --log("GardenaUserId: " .. gardenaUserId, 0)
  
      -- Get Gardena Smart System location information...
      HC2:request(
          "https://sg-api.dss.husqvarnagroup.net/sg-1/locations/?user_id=" .. gardenaUserId, {
              success = function(resp)
                          gardenaLocations = json.decode(resp.data)
                          --local gardenaName = gardenaLocations.locations[1].name
                          gardenaLocation = gardenaLocations.locations[1].id
                          getGardenaDevices(gardenaLocation, gardenaToken)
                        end,
              error =  function(resp) log("Error retrieving location information from the Gardena Smart System API!", 1) end,
              options = {
                  headers = {['Content-Type'] = 'application/json',['X-Session'] = gardenaToken},
                  method = 'GET',
                  timeout = 5000
              }
          }
      )
  end
  
  function getGardenaSession()
      -- Login to Gardena Smart System API...
      if (gardenaToken == "" and gardenaLocation == "") then
          log("Login to Gardena Smart System API...", 71)
          HC2:request(
              "https://sg-api.dss.husqvarnagroup.net/sg-1/sessions", { 
                  success = function(resp) getGardenaLocation(resp.data) end,
                  error =  function(resp) log("Error logging on to the Gardena Smart System API!", 1) end,
                  options = {
                      method = "POST",
                      headers = { 
                          ['Content-Type'] = 'application/json'
                      },
                      data = '{"sessions":{"email":"' .. gardenaEmail .. '","password":"' .. gardenaPassword ..'"}}'
                  }
              }
          )
      else
          log("Use existing token with Gardena Smart System API...", 71)
          getGardenaDevices(gardeneLocation, gardenaToken)
      end
      -- Repeat function every 5 minutes.
      setTimeout(getGardenaSession, 300000)
  end
  
  function getBuitenRadarData(mowerState, mowerSourceForNextStart, mowerTimestampNextStart, mowerDeviceId)
      -- Get BuienRadar data...s
      HC2:request(
          "https://gpsgadget.buienradar.nl/data/raintext/?" .. latlon, {
              success = function(resp) processBuienRadarData(resp.data, mowerState) end,
              error =  function(resp) log("Error logging on to BuienRadar API!", 1) end,
              options = {
                  method = "GET",
                  checkCertificate = false
              }
          }
      )
  end
  
  function processBuienRadarData(response, mowerState, mowerSourceForNextStart, mowerTimestampNextStart, mowerDeviceId)
      -- create a lookup table from the buienradar data.
      -- local buienTabel = {}
      -- for line in buienData:gmatch("([^\n]*)\n?") do
      --     local mm, time = line:match("(.*)|(.*)")
      --     buienTabel[time] = mm
      -- end
      -- local neerslag = buienTabel['22:40']
  
      -- get global variables...
      local rainDelayVar = fibaro:getGlobalValue("MowerRainDelay")
      local prevIntensity, delayUntilTime = rainDelayVar:match("(.*)|(.*)")
      -- if global variable is never used set the variables to zero.
      if (prevIntensity == nil) then
          prevIntensity = 0
      end
      if (delayUntilTime == nil) then
          delayUntilTime = 0
      end
      delayUntilTime = tonumber(delayUntilTime)
  
      -- get first line of buien data and calculate to mm/u.
      local neerslag, tijd = response:match("([^\n]*)\n?"):match("(.*)|(.*)")
      if (neerslag == nil) then -- sometimes buienradar sends a blank page, why? workaround for this!
          neerslag = 0
          tijd = "n/a"
          log("Error reading BuienRadar data, got blank page...", 1)
      end
      local intensiteit = round(10^((neerslag-109)/32), 1)
      local currentime = tonumber(os.time())
      
      local rainloglevel = 2
      if (tonumber(neerslag) > 0) then
        local rainloglevel = 3
      end
      log("<strong>BuitenRadar</strong>: rain: " .. neerslag .. " | time: " .. tijd .. " | intensity: " .. intensiteit, rainloglevel)
  
      if (currentime < delayUntilTime) then
          -- rain delay is active...
          if (intensiteit == 0) then
              -- het regent niet meer, doe niets tot tijd is verstreken...
              -- zet vd label dat de regen stop actief is?
          elseif (intensiteit*10 <=50) then -- ***** DIT NAKIJKEN, WANT WAAROM KIJK IK NAAR PREVIOUS?
              rainDelayVar = intensiteit .. "|" .. currentime+7200
              fibaro:setGlobal("MowerRainDelay", rainDelayVar)
              -- mower is parked, do nothing
          else
              -- just park until tomorrow, rain is getting worse...
              rainDelayVar = intensiteit .. "|0"
              fibaro:setGlobal("MowerRainDelay", rainDelayVar)
              -- park mower until tomorrow
              if (tonumber(fibaro:getGlobalValue("MowerPushSend")) ~= 5) then
                  fibaro:call(phoneId, "sendPush", "Maaier wordt tot morgen geparkeerd i.v.m. aanhoudende zware buien.")
                  sendMowerCommand("park_until_next_timer")
                  fibaro:setGlobal("MowerPushSend", 5)
              end
          end
      else
          -- if mower is parked do nothing
          if (not mowerState:match("parked")) then
              -- rain delay is not active...
              -- check if rain delay was active...
              if (delayUntilTime > 0 ) then
                  -- rain delay was active but it is dry for two hours now
                  -- start mowing again!
                  rainDelayVar = intensiteit .. "|0"
                  fibaro:setGlobal("MowerRainDelay", rainDelayVar)
                  if (tonumber(fibaro:getGlobalValue("MowerPushSend")) ~= 0) then 
                       fibaro:call(phoneId, "sendPush", "Het is droog, het maaien wordt hervat.")
                       sendMowerCommand("start_resume_schedule")
                       fibaro:setGlobal("MowerPushSend", 0)
                  end
              else
                  -- rain delay is not active, do check for rain!
                  if (intensiteit == 0) then
                      -- no rain!
                  elseif ((intensiteit*10) <= 20) then -- muliply by 10 because of stupid float and if statement.
                      rainDelayVar = intensiteit .. "|0"
                      fibaro:setGlobal("MowerRainDelay", rainDelayVar)
                      if (tonumber(fibaro:getGlobalValue("MowerPushSend")) ~= 1) then 
                          fibaro:call(phoneId, "sendPush", "Maaier wordt niet geparkeerd ondanks " .. intensiteit .. " mm/u neerslag om " .. tijd)
                          fibaro:setGlobal("MowerPushSend", 1)
                      end
                  elseif ((intensiteit*10) <= 50) then
                      rainDelayVar = intensiteit .. "|" .. currentime+7200
                      fibaro:setGlobal("MowerRainDelay", rainDelayVar)
                      -- park mower
                      if (tonumber(fibaro:getGlobalValue("MowerPushSend")) ~= 2) then 
                          fibaro:call(phoneId, "sendPush", "Maaier wordt tijdelijk geparkeerd i.v.m. " .. intensiteit .. " mm/u neerslag om " .. tijd)
                          sendMowerCommand("park_until_further_notice")
                          fibaro:setGlobal("MowerPushSend", 2)
                      end
                  else
                      -- just park until tomorrow, its raining a lot...
                      rainDelayVar = intensiteit .. "|0"
                      fibaro:setGlobal("MowerRainDelay", rainDelayVar)
                      -- park mower until tomorrow
                      if (tonumber(fibaro:getGlobalValue("MowerPushSend")) ~= 5) then 
                          fibaro:call(phoneId, "sendPush", "Maaier wordt tot morgen geparkeerd i.v.m. " .. intensiteit .. " mm/u neerslag om " .. tijd)
                          sendMowerCommand("park_until_next_timer")
                          fibaro:setGlobal("MowerPushSend", 5)
                      end
                  end
              end
          else
              -- mower is already parked, do nothing
              log("Mower is parked, do nothing for now.", 83)
          end
      end
  end
  
  gardenaEmail    = "user@domain.com"
  gardenaPassword = "mysecretpassword"
  latlon = "lat=52.37&lon=4.89"
  mowerVirtualDevice = 184  -- virtual device id
  phoneId = 156

  -- Do not change these variables!
  gardenaToken    = ""
  gardenaLocation = ""
  mowerDeviceId   = ""
  
  debug = false
  fibaro:setGlobal("MowerPushSend", 0) -- reset saved status, start at zero
  HC2 = net.HTTPClient()
  
  local sourceTrigger = fibaro:getSourceTrigger();  
    
  if (sourceTrigger["type"] == "autostart") then
      fibaro:debug("Mower Control automatically started by the Fibaro System...")
      getGardenaSession()
  elseif (sourceTrigger["type"] == "other") then
      fibaro:debug("Mower Control manually started by user...")
      getGardenaSession()
  end
