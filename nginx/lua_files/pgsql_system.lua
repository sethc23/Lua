
--[[    pgsql_system API

 /sys/<action>/<table_name>/<col_name>/<col_val>/[<key>=<value]

methods: "get" or "post"

examples:

    GET /sys/servers
    
    GET /sys/servers/tag/ub2

    POST /sys/servers/tag/ub2?local_addr=10.0.0.52&ext_addr=x.x.x.x


--]]


-- sites-available/lua_files/pgsql_system.lua
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
ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n uri :>>\n"      ..tostring(ngx.var.uri)..    "\n<< ")
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
ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n qry_tbl :>>\n"      ..tostring(qry_tbl)..    "\n<< ")
if #qry_tbl==0 then ngx.exit(ngx.HTTP_NOT_FOUND) end
--    curl -s -X "GET" localhost:9999/ <...> | jq '.'
-- [X]  GET /sys/servers
-- [X]  GET /sys/servers/tag
-- [X]  GET /sys/servers/tag/BUILD (checking letters)
-- [X]  GET /sys/servers/local_port/9092 (checking numbers)
-- [X]  GET /sys/servers/tag/ub2 (checking letters,numbers)
-- [ ]  POST /sys/servers/tag/ub2?local_addr=10.0.0.52&ext_addr=x.x.x.x 

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
elseif #uri_split==1 then cols = uri_split[1]
elseif #uri_split==2 then 
    cols = "*"
    if uri_split[2]:match('^%d+$') then
        cond = " WHERE "..uri_split[1].."="..uri_split[2]
    else
        cond = " WHERE "..uri_split[1]..[[=]]..[[']]..uri_split[2]..[[']]
    end
else ngx.exit(ngx.HTTP_NOT_FOUND)
end

--require('mobdebug').start("0.0.0.0")

local qry,q_res_status,q_res_body = "","",""
if req_method=="GET" then

    qry = ngx.escape_uri( "SELECT "..cols.." FROM "..qry_tbl..cond..";" )
    _,q_res_body = make_query(qry)


    
    
    

    -- ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n q_res_body :>>\n"      ..cjson.(q_res_body)[1].res..    "\n<< ")

    -- if cjson.decode(q_res_body)[1].res=="nothing updated" then
    --     qry = "update yelp set trigger_step='geom_from_coord_failed' where uid = "..r['idx']..";"
    --     make_query(qry)
    -- end

    ngx.say(q_res_body)

--  TEST SCRIPT
--    if tag:find("MN.new_address.parsed.geom.failed.new_address.parsed") then
--
--        q = [[  select z_update_with_geom_from_parsed(   ]]..r['idx']..[[, ']]..r['table']..[['::text,
--                                                        ']]..r['uid_col']..[['::text) res]]
--        ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n Q:>>\n\n"..q.."\n\n<< ")
--
--        tag = "PAUSING"
--        q = "update "..r['table'].." set trigger_step = '"..tag.."' where "..r['uid_col'].."="..r['idx']
--        make_query(q)
--        ngx.exit(ngx.OK)
--    end


end

ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n\nEND\n\n :>>  <<  ")

-- require('mobdebug').start("10.0.0.53")


ngx.exit(ngx.OK)