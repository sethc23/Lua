--
-- User: admin
-- Date: 10/19/15
-- Time: 3:42 AM
--

local client = require "resty.websocket.client"
local wb, err = client:new{
    timeout = 10000,                            -- in milliseconds
    max_payload_len = 1048576,
}
local uri = "ws://10.0.1.51:12401/"

--ngx.say("uri: ", uri)


-- Make Connect and Error Check:
local ok, err = wb:connect(uri)
if not ok then
    ngx.say("failed to connect: " .. err)
    return
end
local data, typ, err = wb:recv_frame()
if not data then
    ngx.say("failed to receive 1st frame: ", err)
    return
end

--ngx.say("1: received: ", data, " (", typ, ")")

-- JSON Encode Post and Send:
local cjson = require "cjson"
local r={}
local args = ngx.req.get_uri_args()
for key, val in pairs(args) do
    r[key] = val
end
local res = cjson.encode(r)

ngx.say(res)

local bytes, err = wb:send_text(res)
if not bytes then
    ngx.say("failed to send frame: ", err)
    return
end

data, typ, err = wb:recv_frame()
if not data then
    ngx.say("failed to receive 2nd frame: ", err, " (",data, ")")
    return
end

local tmp = string.gsub(data,"\\\\","")
local status_code_resp = cjson.decode(data).status
local resp_id = cjson.decode(cjson.decode(data).body)._id

ngx.say(resp_id)

