-- sites-available/lua_files/authentication_socket.lua
module("authentication_socket", package.seeall)

--ngx.log(ngx.WARN,"-- {auth_socket}/ : START :>> -- <<  ")

local cjson             =   require "cjson"

local h                 =   ngx.req.raw_header()
local req_method        =   string.gsub(h,"(.*)(req_method): (%w+)(.*)","%3")

if req_method == "GET" then
    ngx.exit(ngx.HTTP_OK)
end

local tmp               =   string.match(h,"(machine_id)")
local t,machine_id      =   "",""
if tmp ~= nil then
    t                   =   string.gsub(h,"%\r%\n",",")
    machine_id          =   string.gsub(t,"(.*)(machine_id):([^%w]*)([^,}]+)(.*)","%4")
end


local capt_url          =   "/auth_check?ip_addr="..ngx.var.http_x_real_ip.."&machine_id="..machine_id
local auth_res_orig     =   ngx.location.capture(capt_url)

local auth_res          =   string.gsub(auth_res_orig.body,"%[","")
auth_res                =   string.gsub(auth_res,"%]","")
auth_res                =   cjson.decode(auth_res).res

--[[
ngx.log(ngx.WARN,"-- {auth_socket}/ : header :>>"      ..h..                       "<<  ")
ngx.log(ngx.WARN,"-- {auth_socket}/ : method :>>"      ..req_method..              "<<  ")
ngx.log(ngx.WARN,"-- {auth_socket}/ : machine_id :>>"  ..cjson.encode(machine_id).."<<  ")
ngx.log(ngx.WARN,"-- {auth_socket}/ : t :>>"           ..t..                       "<<  ")
ngx.log(ngx.WARN,"-- {auth_socket}/ : auth_res :>>"    ..auth_res..                "<<  ")
--]]

if auth_res == "ok" then
    --ngx.log(ngx.WARN,"-- {sock}/ : auth_res_orig :>>"   ..cjson.encode(auth_res_orig).. "<<  ")
    --ngx.log(ngx.WARN,"-- {sock}/ : machine_id :>>"      ..cjson.encode(machine_id)..    "<<  ")
    --return ngx.exit(ngx.HTTP_OK)
    return
else
    --ngx.log(ngx.WARN,"-- {sock}/ : auth_res :>>"    ..auth_res..                "<<  ")
    return ngx.exit(ngx.HTTP_FORBIDDEN)
end