-- pgsql_system API
--[[    

    /sys/<table_name>/<col_name>/<col_val>/[<key>=<value]

    methods: "get" or "post"

    TESTS:


        "GET"      curl -s -X "GET" localhost:9999/sys/<...> | jq '.'

    [X]  GET /sys/servers
    [X]  GET /sys/servers/tag
    [X]  GET /sys/servers/tag/BUILD
    [X]  GET /sys/servers/local_port/9092 
    [X]  GET /sys/servers/tag/ub2
    [X]  GET /sys/servers/tag/.scripts


        "POST"      echo '{"qry":"select distinct s_tag from servers"}' | curl --data @- --get localhost:9999/sys

        OLD --> "POST"     curl -s -X "POST" localhost:9999/sys/<...> | jq '.'

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
cjson = require"cjson"
str_u = require"string_utils"

-- ngx.log(ngx.WARN,"-- {pgsql_system.lua}/ : START :>>  <<  ")


function os_capture(cmd, raw)
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    if raw then return s end
    s = string.gsub(s, '^%s+', '')
    s = string.gsub(s, '%s+$', '')
    s = string.gsub(s, '[\n\r]+', ' ')
    return s
end

function make_query(qry)
    -- ngx.log(ngx.WARN,"\n\n\n"..qry.."\n\n\n")
    -- qry = ngx.decode(qry)unescape_uri
    -- qry = ngx.escape_uri( qry )
    qry = ngx.unescape_uri( qry )
    local plain_url = '/query?qry='..qry

    -- local enc_url = ngx.escape_uri(plain_url)
    local resp                  =   ngx.location.capture(plain_url)
    if resp.status~=200 then
        ngx.log(ngx.WARN,"-- {pgsql_system.lua}/ : pgsql_args :>>"      ..qry..                        "<<  ")
        ngx.log(ngx.WARN,"-- {pgsql_system.lua}/ : resp :>>"            ..tostring(resp.status)..   "<<  ")
    end
    -- ngx.log(ngx.WARN,"-- \n{pgsql_system.lua}/ : \nresp :>>\n"            ..cjson.encode(resp)..   "\n\n<<  ")
    return resp.status,resp.body
end

local req_method = ngx.var.request_method
if (not req_method=="GET" and not req_method=="POST") then ngx.exit(ngx.HTTP_METHOD_NOT_IMPLEMENTED) end

local uri_split = str_u.splitter(ngx.var.uri,"/")
table.remove(uri_split,1)
-- ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n uri :>>\n"      ..tostring(ngx.var.uri)..    "\n<< ")

if #uri_split==0 then 
    qry_tbl = nil
else
    qry_tbl = table.remove(uri_split,1)
end

-- FORMAT GET/POST ARGS
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
-- ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n cond :>>\n"      ..cond..    "\n<< ")

-- m=require('mobdebug').start("10.0.0.52")

local t,post_args                 =   {},{}
if req_method=='POST' then
    ngx.req.read_body()
    t = ngx.req.get_post_args()
    for k,v in pairs(t) do 
        ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n post_args(k) :>>\n"      ..k..    "\n<< ")
        post_args = cjson.decode(k) 
        -- ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n post_args :>>\n"      ..cjson.encode({type(post_args),post_args})..    "\n<< ")
        break 
    end
    
    local arg_count = 0
    for k,v in pairs(post_args) do arg_count = arg_count+1 end
    if arg_count==0 then ngx.exit(ngx.HTTP_METHOD_NOT_IMPLEMENTED) end
end

for k,v in pairs(post_args) do
    if type(v)=="table" then
        post_args[k] = cjson.encode(v)
    end
end


--require('mobdebug').start("0.0.0.0")

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

local qry,q_res_status,q_res_body = "","",""
if req_method=="GET" then
    if qry_tbl==nil then
        qry = [[SELECT pg_class.relname
                FROM pg_class, pg_attribute, pg_index
                WHERE pg_class.oid = pg_attribute.attrelid
                AND pg_class.oid = pg_index.indrelid
                AND pg_index.indkey[0] = pg_attribute.attnum
                AND pg_index.indisprimary = 't'
                AND pg_attribute.attname = 'uid'
                ORDER BY pg_class.relname ASC;]]
        qry = qry:gsub('%s%s+'," ")
        qry = ngx.escape_uri(qry)
        _,q_res_body = make_query(qry)
        ngx.say(  os_capture([[echo ']]..q_res_body..[['  | jq -M -c '[.[].relname]' ]])  )
    else
        ngx.log(ngx.WARN,"-- {pgsql_system.lua}/ : \n\nREGULAR GET REQUEST\n\n")
        qry = "SELECT "..cols.." FROM "..qry_tbl..cond..";"
        -- qry = ngx.escape_uri( qry )
        _,q_res_body = make_query(qry)
        _,t = cols:gsub(",","")
        if t==0 then
            local res = os_capture([[echo ']]..q_res_body..[['  | jq -M -c '[.[].]]..cols..[[]' 2>&1 ]])
            if res:find("jq: error:")==1 then ngx.say(q_res_body) end
        else
            ngx.say(q_res_body)
        end
    end   
elseif req_method=="POST" then
    ngx.log(ngx.WARN,"-- {pgsql_system.lua}/ : \n\nREGULAR POST REQUEST\n\n")
    qry = "UPDATE "..qry_tbl.." SET "
    for k,v in pairs(post_args) do
        qry = qry .. k .. [[=']] .. tostring(v) .. [[', ]]
    end
    qry = qry:sub(1,#qry-qry:reverse():find(',')) .. cond .. [[;]]
    -- qry = ngx.escape_uri(qry)
    _,q_res_body = make_query(qry)
    ngx.say(q_res_body)
end

-- ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n\nEND\n\n :>>  <<  ")
-- require('mobdebug').start("10.0.0.53")

ngx.exit(ngx.OK)