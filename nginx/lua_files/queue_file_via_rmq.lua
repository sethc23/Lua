-- sites-available/lua_files/queue_file_via_rmq.lua
module("queue_file_via_rmq", package.seeall)

local strlen =  string.len
local cjson = require "cjson"
local rabbitmq = require "resty.rabbitmqstomp"

local r                     =   {}
local args                  =   ngx.req.get_uri_args()
for key, val in pairs(args) do
    r[key]                  =   val
end
local pdf_id                =   r.pdf_id
local order_tag             =   r.order_tag
local local_document        =   r.local_document
local machine_id            =   r.machine_id
local ip_addr               =   r.ip_addr

local opts                  =   {  username = "ub2",
                                   password = "mq_money",
                                   vhost = "/"      }
local mq, err               =   rabbitmq:new(opts)
if not mq then
      return
end
mq:set_timeout(10000)
local ok, err               =   mq:connect("127.0.0.1",61613)
if not ok then
    ngx.log(ngx.WARN,"-- {queue_file_via_rmq} : connect:  >>" ..cjson.encode(err)..    "<< ")
    return
end

local msg                   =   {}
msg["task"]                 =   "document_processing.queue_file"
msg["id"]                   =   pdf_id
msg["args"]                 =   {pdf_id,order_tag,local_document,machine_id,ip_addr}
msg["kwargs"]               =   {}
msg["retries"]              =   0
-- add delay to execution
--local time                  =   require "time"
--local t                     =   time.nowlocal()+time.seconds(5)
--msg["eta"]                  =   tostring(t)
local headers               =   {}
--                               /exchange/{exchange}/{routing_key}
headers["destination"]      =   "/exchange/ngx/aprinto"
--headers["receipt"]          =   "msg#1"
headers["app-id"]           =   "lua-resty-rabbitmqstomp"
headers["persistent"]       =   "true"
headers["content-type"]     =   "application/json"

local ok, err               =   mq:send(cjson.encode(msg), headers)
if not ok then
    ngx.log(ngx.WARN,"-- {queue_file_via_rmq} : encode:  >>"  ..cjson.encode(err)..    "<< ")
    return
end
