-- sites-available/lua_files/printer_check_in.lua
module("printer_check_in", package.seeall)


local cjson                 =   require "cjson"

--ngx.log(ngx.WARN,"-- {printer_check_in.lua}/ : START :>>  <<  ")

function make_tag()
    local INCL_CHARS        =   "ACEFGHJKLNPSTXZ347"
    local e                 =   string.len(INCL_CHARS)
    local sock              =   require "socket"
    math.randomseed(            sock.gettime()*1000)
    local n,c               =   0,""
    local tag               =   ""
    for i=1, 4 do
        n                   =   math.random(1, e)
        c                   =   INCL_CHARS:sub(n,n)
        tag                 =   tag .. c
    end
    return tag
end


--local h                     =   ngx.req.raw_header()
--ngx.log(ngx.WARN,"-- {printer_check_in.lua} : header :>>"      ..cjson.encode(h)..    "<< ")

--[[
local r                     =   {}
local args                  =   ngx.req.get_uri_args()
for key, val in pairs(args) do
    r[key]                  =   val
end
ngx.log(ngx.WARN,"-- {printer_check_in.lua} : uri_args :>>"    ..cjson.encode(r)..    "<< ")
--]]

ngx.req.read_body()
local post_args             =   cjson.encode(ngx.req.get_post_args())
--ngx.log(ngx.WARN,"-- {printer_check_in.lua} : post_args :>>"    ..post_args..          "<< ")
local s                     =   post_args:gsub("%[","")
s                           =   s:gsub("%]","")
s                           =   s:gsub("\\\"","")
s                           =   s:gsub(" ","")
s                           =   "{"..s:gsub("(.*)(\"{)(.*)(}\")(.*)","%3").."}"

pgsql_args                  =   "?"
for k,v in string.gmatch(s,'([^:{,]+):([^,}]+)') do
    pgsql_args              =   pgsql_args..k.."="..v.."&"
end


local order_tag             =   make_tag()

pgsql_args                  =   pgsql_args.."order_tag"     .."="..     order_tag               .."&"
pgsql_args                  =   pgsql_args.."status"        .."=U&"
pgsql_args                  =   pgsql_args.."ip_addr"       .."="..     ngx.var.remote_addr     .."&"
local resp                  =   ngx.location.capture('/new_order'..pgsql_args)

if resp.status~=200 then
    ngx.log(ngx.WARN,"-- {printer_check_in.lua}/ : pgsql_args :>>"      ..pgsql_args..                  "<<  ")
    ngx.log(ngx.WARN,"-- {printer_check_in.lua}/ : resp :>>"            ..cjson.encode(resp.status)..   "<<  ")
end

local j = [[{
"doc_post_url": "http://printer.aporodelivery.com",
"order_tag": "ORDER_TAG_REPL",
"qr_code_scale": 0.001,
"qr_code_x": 5,
"qr_code_y": 1,
"qr_url": "http://printer.aporodelivery.com",
"tag_scale": 0.001,
"tag_x": 5,
"tag_y": 1
}]]

-- "qr_url" MUST NOT BE EMPTY!! else printer driver will not send PDF
j                           =   j:gsub("ORDER_TAG_REPL",order_tag)

--ngx.log(ngx.WARN,"---->> printer_check_in complete <<----")

ngx.status                  =   ngx.HTTP_CREATED
ngx.say(j)
ngx.exit(ngx.HTTP_CREATED)
