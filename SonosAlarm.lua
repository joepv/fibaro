--[[
%% properties
%% events
%% globals
--]]

function getAlarms(xml)
  local b = 0
  local e = 0
  local x = ''
  local alarmId = ''
  local alarmTime = ''
  local alarmRecurrence = ''
  local alarmEnabled = ''

  while b ~= nill do 
    -- find the first <Alarm ID... /> tag char number...
    b = string.find(xml, "&lt;Alarm ID", e)
    if b ~= nill then
      -- find the closing tag tag char number...
      e = string.find(xml, "/&gt;", b)
      -- substring the whole <Alarm .. /> tag...
      x = string.sub(xml, b, e+3)
      -- replace the html quote chars with real quotes for string.match
      x = x:gsub("&quot;", "\"")
      alarmId         = string.match(x, [[Alarm%sID="([^"]+)]])
      alarmTime       = string.match(x, [[StartTime="([^"]+)]])
      alarmRecurrence = string.match(x, [[Recurrence="([^"]+)]])
      alarmEnabled    = string.match(x, [[Enabled="([^"]+)]])
      --fibaro:debug(alarmId)
      --fibaro:debug(alarmTime)
      --fibaro:debug(alarmRecurrence)
      --fibaro:debug(alarmEnabled)
      --fibaro:debug('----------')
      -- get the current day of the week
      local dayofweek = os.date("*t").wday-1
      -- remap ONCE/WEEKDAYS to day numbers for check later on
      if alarmRecurrence == 'ONCE' then
        alarmRecurrence = 'ONCE_' .. dayofweek
      elseif alarmRecurrence == 'WEEKDAYS' then
        alarmRecurrence = 'WEEKDAYS_12345'
      end
      -- check if the alarm is enabled
      if tonumber(alarmEnabled) == 1 and alarmRecurrence:match(dayofweek) then
        fibaro:debug('alarm enabled at: ' .. alarmTime)
      end
    end
  end
end

local body   = '<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"><s:Body><u:ListAlarms xmlns:u=\"urn:schemas-upnp-org:service:AlarmClock:1\"><InstanceID>0</InstanceID></u:ListAlarms></s:Body></s:Envelope>'
local action = 'urn:schemas-upnp-org:service:AlarmClock:1#ListAlarms'
local path   = 'AlarmClock/Control'
local host   = '192.168.2.10:1400'

--[[
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:ListAlarms xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1">
    <InstanceID>0</InstanceID>
    </u:ListAlarms>
  </s:Body>
</s:Envelope>
--]]

HC2 = net.HTTPClient()
HC2:request(
  'http://' .. host .. '/' .. path, {
    success = function(resp) getAlarms(resp.data) end,
    error = function(err)
              fibaro:debug(err.data)
            end,
    options = {
      headers = {
        ['Content-Type'] = 'text/xml',
        ['charset'] = 'UTF-8',
        ['Host'] = host,
        ['SOAPAction'] = action
      },
      data = body,
      method = 'POST'
    }
  }
)
