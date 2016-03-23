-- pgsql_system API
--[[    

    /sys/<action>/<table_name>/<col_name>/<col_val>/[<key>=<value]

    methods: "get" or "post"

    TESTS:


        "GET"      curl -s -X "GET" localhost:9999/sys/<...> | jq '.'

    [X]  GET /sys/servers
    [X]  GET /sys/servers/tag
    [X]  GET /sys/servers/tag/BUILD
    [X]  GET /sys/servers/local_port/9092 
    [X]  GET /sys/servers/tag/ub2
    [X]  GET /sys/servers/tag/.scripts


        "POST"     curl -s -X "POST" localhost:9999/sys/<...> | jq '.'

    curl -H "Content-Type: application/json" -X POST -d \
        '{"test_text":"ok","test_bool":true}' http://localhost:9999/sys/servers
        --> {"errcode":0,"affected_rows":13}
    curl -H "Content-Type: application/json" -X POST -d \
        '{"test_text":"N","test_bool":true}' http://localhost:9999/sys/servers/
        --> {"errcode":0,"affected_rows":13}
    curl -H "Content-Type: application/json" -X POST -d \
        '{"test_text":"ok","test_bool":true}' http://localhost:9999/sys/servers/tag
        --> errors out
    curl -H "Content-Type: application/json" -X POST -d \
        '{"test_text":"ok","test_bool":true}' http://localhost:9999/sys/servers/tag/ubx
        --> {"errcode":0}
    curl -H "Content-Type: application/json" -X POST -d \
        '{"test_text":"ok","test_bool":true}' http://localhost:9999/sys/servers/tag/ub2
        --> {"errcode":0,"affected_rows":1}
--]]

-- lua_files/pgsql_system.lua
module("pgsql_system", package.seeall)
package.loaded.string_utils=nil
str_u = require"string_utils"

--ngx.log(ngx.WARN,"-- {pgsql_system.lua}/ : START :>>  <<  ")

local cjson                 =   require "cjson"

function make_query(qry)
    --ngx.log(ngx.WARN,"\n\n\n"..qry.."\n\n\n")
    local plain_url = '/query?qry='..qry
    -- local enc_url = ngx.escape_uri(plain_url)
    local resp                  =   ngx.location.capture(plain_url)
    if resp.status~=200 then
        ngx.log(ngx.WARN,"-- {pgsql_system.lua}/ : pgsql_args :>>"      ..qry..                        "<<  ")
        ngx.log(ngx.WARN,"-- {pgsql_system.lua}/ : resp :>>"            ..cjson.encode(resp.status)..   "<<  ")
    end
    --ngx.log(ngx.WARN,"-- \n{pgsql_system.lua}/ : \nresp :>>\n"            ..t.res..   "\n\n<<  ")
    return resp.status,resp.body
end

local req_method = ngx.var.request_method
if (not req_method=="GET" and not req_method=="POST") then ngx.exit(ngx.HTTP_METHOD_NOT_IMPLEMENTED) end

local uri_split = str_u.splitter(ngx.var.uri,"/")
table.remove(uri_split,1)
-- ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n uri :>>\n"      ..tostring(ngx.var.uri)..    "\n<< ")
if #uri_split==0 then ngx.exit(ngx.HTTP_NOT_FOUND) end

local update,qry_tbl = false,""
if uri_split[1]=="update" then 
    update=true
    table.remove(uri_split,1)
    qry_tbl=table.remove(uri_split,1)
else
    update=false
    qry_tbl=table.remove(uri_split,1)
end
-- ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n qry_tbl :>>\n"      ..tostring(qry_tbl)..    "\n<< ")
if #qry_tbl==0 then ngx.exit(ngx.HTTP_NOT_FOUND) end

--require('mobdebug').start("0.0.0.0")

local t,post_args                 =   {},{}
if req_method=='POST' then
    ngx.req.read_body()
    t                   =   ngx.req.get_post_args()
    for k,v in pairs(t) do post_args = cjson.decode(k) break end
    -- ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n post_args :>>\n"      ..cjson.encode({type(post_args),post_args})..    "\n<< ")
    local arg_count = 0
    for k,v in pairs(post_args) do arg_count = arg_count+1 end
    if arg_count==0 then ngx.exit(ngx.HTTP_METHOD_NOT_IMPLEMENTED) end
end

--[[
    local h                     =   ngx.req.raw_header()
    ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \nheader :>>\n"      ..cjson.encode(h)..    "\n<< ")
--]]


--[[
    local r                     =   {}
    local args                  =   ngx.req.get_uri_args()
    for k, v in pairs(args) do
        r[k]                  =   v
    end
    ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \nuri_args :>>\n"    ..cjson.encode(r)..    "\n<< ")
--]]

local cols,cond = "",""
if #uri_split==0 then cols = "*"
elseif #uri_split==1 then 
    if req_method=="POST" then ngx.exit(ngx.HTTP_NOT_FOUND) end
    cols = uri_split[1]
elseif #uri_split==2 then 
    cols = "*"
    if uri_split[2]:match('^%d+$') then
        cond = " WHERE "..uri_split[1].."="..uri_split[2]
    else
        cond = " WHERE "..uri_split[1]..[[=]]..[[']]..uri_split[2]..[[']]
    end
else ngx.exit(ngx.HTTP_NOT_FOUND)
end

local qry,q_res_status,q_res_body = "","",""
if req_method=="GET" then
    qry = ngx.escape_uri( "SELECT "..cols.." FROM "..qry_tbl..cond..";" )
    _,q_res_body = make_query(qry)
    ngx.say(q_res_body)
elseif req_method=="POST" then
    qry = "UPDATE "..qry_tbl.." SET "
    for k,v in pairs(post_args) do
        qry = qry .. k .. [[=']] .. tostring(v) .. [[', ]]
    end
    qry = qry:sub(1,#qry-qry:reverse():find(',')) .. cond .. [[;]]
    qry = ngx.escape_uri(qry)
    _,q_res_body = make_query(qry)
    ngx.say(q_res_body)
end

-- ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n\nEND\n\n :>>  <<  ")
-- require('mobdebug').start("10.0.0.53")

ngx.exit(ngx.OK)