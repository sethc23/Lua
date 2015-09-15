-- sites-available/lua_files/rabbitmq_downstream.lua

local strlen =  string.len
local cjson = require "cjson"
local rabbitmq = require "resty.rabbitmqstomp"


local opts = { username = "ub2",
               password = "mq_money",
               vhost = "/" }

local mq, err = rabbitmq:new(opts)
if not mq then
      return
end

mq:set_timeout(10000)

local ok, err = mq:connect("127.0.0.1",61613)

if not ok then
    ngx.log(ngx.WARN,"connect:  "..err)
    return
end

local msg                   = {}
msg["task"]                 = "document_processing.test"
msg["id"]                   = "54086c5e-6193-4575-8308-dbab76798756"
msg["args"]                 = ""--""[2,2]"
msg["kwargs"]               = {}
local headers               = {}
headers["destination"]      = "/exchange/ngx/ngx_celery"
headers["receipt"]          = "msg#1"
headers["app-id"]           = "lua-resty-rabbitmqstomp"
headers["persistent"]       = "true"
headers["content-type"]     = "application/json"

local ok, err = mq:send(cjson.encode(msg), headers)
if not ok then
    ngx.log(ngx.WARN,"encode:  "..cjson.encode(err))
    return
end
ngx.log(ngx.WARN, "Published: " .. cjson.encode(msg))

--[[
local headers = {}
headers["destination"] = "/amq/queue/queuename"
headers["persistent"] = "true"
headers["id"] = "123"

local ok, err = mq:subscribe(headers)
if not ok then
    return
end


local data, err = mq:receive()
if not ok then
    ngx.log(ngx.WARN,"receive:  "..err)
    return
end
ngx.log(ngx.WARN, "Consumed: " .. data)


local headers = {}
headers["persistent"] = "true"
headers["id"] = "123"

local ok, err = mq:unsubscribe(headers)

local ok, err = mq:set_keepalive(10000, 10000)
if not ok then
    ngx.log(ngx.WARN,"keepalive:  "..err)
    return
end

--]]