function getActiveProfileName()
    local profiles = api.get("/profiles")
    for _, profile in ipairs(profiles.profiles) do
        if (profile.id == profiles.activeProfile) then
            return profile.name
        end
    end
end

function generateTime(realtime, min, max)
    local r    = math.random(min,max)
    local h, m = realtime:match("(%d+):(%d+)")
    local cdt  = os.date("*t")
    local adt  = os.time({year=cdt.year, month=cdt.month, day=cdt.day, hour=h, min=m})
    local ldt  = adt + r
    return os.date('%H:%M', ldt)
end

function awayTimer()
    local activeProfile = getActiveProfileName()
    if (activeProfile ~= "Away") then
        fibaro.debug("Scene30", "Stop Away Timer")
    else
        local awayTime = fibaro.getSceneVariable("awayTime")
        awayTime = awayTime + 1
        fibaro.setSceneVariable("awayTime", awayTime)
        if (awayTime == 600) then -- Set vacation profile automatically after 10 hours away!
            fibaro.profile(3, "activateProfile") -- Set vacation profile active.
            runSimulation()
        else
            local s = os.date("%S")
            local timeout = 60000 - (s * 1000)
            fibaro.setTimeout(timeout, function() -- wait 1 minute
                awayTimer()
            end)
        end
    end
end


function runSimulation()
    local timeNow = os.date("%H:%M")

    -- Run evening routine here!
    if (timeNow == evening) then
        fibaro.debug("Scene30", "Run the evening scene now!")
        fibaro.scene("execute", {25}) -- Run TV scene..
    end

    -- Run go to bed routine here! DO NOT PUT SYSTEM IN NIGHT PROFILE!
    if (timeNow == bedtime) then
        fibaro.debug("Scene30", "Run go to bed routine now!")
        fibaro.setGlobalVariable('LightsOffExclusions', '39;142')
        fibaro.scene("execute", {50}) -- Run everything off scene..
        fibaro.call(123, "setValue", "25") -- Plafonnière hallway (25%)
    end

    -- Turn lights out and go to sleep routine!
     if (timeNow == sleeptime) then
        fibaro.debug("Scene30", "Run the going to sleep routine now (turn everything off)!")
        fibaro.setGlobalVariable("LightsOffExclusions", "0")
        fibaro.scene("execute", {50}) -- Run everything off scene..
     end

    -- Run checks if still on vacation.
    local activeProfile = getActiveProfileName()
    if (activeProfile ~= "Vacation") then
        fibaro.debug("Scene30", "Stop Simulation")
    else
        local s = os.date("%S")
        local timeout = 60000 - (s * 1000)
        fibaro.setTimeout(timeout, function() -- wait 1 minute
            runSimulation()
        end)
    end
end

fibaro.debug("Scene30", "Presence Simulation scene started...")
fibaro.setSceneVariable("awayTime", 0)

sunset    = fibaro.getValue(1, "sunsetHour")
evening   = generateTime(sunset,-900,300) -- 15 mins before and 5 mins after sunset.
bedtime   = generateTime("22:30",-900,2700) -- 15 mins before and 45 mins after 22:30.
sleeptime = generateTime(bedtime,900,1800) -- between 15 mins and max 30 mins after bedtime.

awayTimer()