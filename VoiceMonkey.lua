-- SAMPLE VOICEMONKEY SCENE ---------------------------------------------------
-- Version 1.0 (April 2023)
-- Copyright (c)2023 Joep Verhaeg <info@joepverhaeg.nl>
-- https://docs.joepverhaeg.nl

net.HTTPClient():request("https://api.voicemonkey.io/trigger", {
    options = {
        method = 'POST',
        timeout = 5000,
        headers= {['Content-Type'] = 'application/json'},
        data = '{"access_token":"INSERT HERE","secret_token":"INSERT HERE","monkey":"monkey1","announcement":"Hello%20monkey"}'
    },
    success = function(response)
        hub.debug ("Scene1", response.status .. " " .. response.data)
    end,
    error = function(message)
        hub.debug("Scene1", "HTTPClient error: " .. message)
    end
})