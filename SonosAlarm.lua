function parseXml(xml)
    local function dec2char(code)
        code = tonumber(code)
        return string.char(code > 255 and 0 or code)
    end

    local function hex2char(code)
        code = tonumber(code, 16)
        return string.char(code > 255 and 0 or code)
    end

    unescapeCache = {}
    local function xmlUnescape(s)
        local r = unescapeCache[s]
        if not r then
            local g = string.gsub
            r = g(s, "&quot;", '"')
            r = g(r, "&apos;", "'")
            r = g(r, "&lt;", "<")
            r = g(r, "&gt;", ">")
            r = g(r, "&#(%d%d?%d?%d?);", dec2char)
            r = g(r, "&#x(%x%x?%x?%x?);", hex2char)
            r = g(r, "&amp;", "&")
            unescapeCache[s] = r
        end
        return r
    end

    escapeCache = {}
    local function xmlEscape(s)
        local r = escapeCache[s]
        if not r then
            local g = string.gsub
            r = g(s, "&", "&amp;")
            r = g(r, '"', "&quot;")
            r = g(r, "'", "&apos;")
            r = g(r, "<", "&lt;")
            r = g(r, ">", "&gt;")
            escapeCache[s] = r
        end
        return r
    end

    local namePattern = "[%a_:][%w%.%-_:]*"

    xml = string.gsub(xml, "<!%[CDATA%[(.-)%]%]>", xmlEscape) -- replace CDATA with escaped text
    xml = string.gsub(xml, "<%?.-%?>", "") -- remove processing instructions
    xml = string.gsub(xml, "<!%-%-.-%-%->", "") -- remove comments
    xml = string.gsub(xml, "<!.->", "")

    local root = {}
    local parents = {}
    local element = root
    for closing, name, attributes, empty, text in string.gmatch(
        xml,
        "<(/?)(" .. namePattern .. ")(.-)(/?)>%s*([^<]*)%s*"
    ) do
        if closing == "/" then
            local parent = parents[element]
            if parent and name == element.name then
                element = parent
            end
        else
            local child = {name = name, attribute = {}}
            table.insert(element, child)
            parents[child] = element
            if empty ~= "/" then
                element = child
            end
            for name, value in string.gmatch(attributes, "(" .. namePattern .. ')%s*=%s*"(.-)"') do
                child.attribute[name] = xmlUnescape(value)
            end
        end
        if text ~= "" then
            local child = {text = xmlUnescape(text)}
            table.insert(element, child)
            parents[child] = element
        end
    end
    return root[1]
end

function getXmlPath(nodes, ...)
    nodes = {nodes}
    local arg = {...}
    for i, name in ipairs(arg) do
        local match = {}
        for i, node in ipairs(nodes) do
            if node.name == name then
                match = nodes
            else
                for i, child in ipairs(node) do
                    if child.name == name then
                        table.insert(match, child)
                    end
                end
            end
        end
        nodes = match
    end
    return nodes
end
 
function getAlarms(xml)
    local dom = parseXml(xml)
    local results = getXmlPath(dom, "s:Envelope", "s:Body", "u:ListAlarmsResponse", "CurrentAlarmList")

    for _, result in ipairs(results) do
        -- Sonos store alarm list as XML in XML
        local alarms = getXmlPath(parseXml(result[1].text), "Alarms", "Alarm")
        for _, alarm in ipairs(alarms) do
            for k, v in pairs(alarm.attribute) do
                print(k, v)
            end
            print("-------------------------------------")
        end
    end
end

function sonosRequest()
    local body =
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:ListAlarms xmlns:u="urn:schemas-upnp-org:service:AlarmClock:1"><InstanceID>0</InstanceID></u:ListAlarms></s:Body></s:Envelope>'
    local action = "urn:schemas-upnp-org:service:AlarmClock:1#ListAlarms"
    local path = "AlarmClock/Control"
    local host = "192.168.2.33:1400"

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
        "http://" .. host .. "/" .. path,
        {
            success = function(resp)
                getAlarms(resp.data)                
            end,
            error = function(err)
                print(err.data)
            end,
            options = {
                headers = {
                    ["Content-Type"] = "text/xml",
                    ["charset"] = "UTF-8",
                    ["Host"] = host,
                    ["SOAPAction"] = action
                },
                data = body,
                method = "POST"
            }
        }
    )
end

sonosRequest()
