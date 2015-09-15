
-- sites-available/lua_files/aporo_api.lua
module("aporo_api", package.seeall)

--ngx.log(ngx.WARN,"-- {aporo_api.lua}/ : START :>>  <<  ")

local cjson                 =   require "cjson"

function make_query(qry)
    --ngx.log(ngx.WARN,"\n\n\n"..qry.."\n\n\n")
    local resp                  =   ngx.location.capture('/query?qry='..qry)
    if resp.status~=200 then
        ngx.log(ngx.WARN,"-- {aporo_api.lua}/ : pgsql_args :>>"      ..qry..                        "<<  ")
        ngx.log(ngx.WARN,"-- {aporo_api.lua}/ : resp :>>"            ..cjson.encode(resp.status)..   "<<  ")
    end
    --ngx.log(ngx.WARN,"-- \n{aporo_api.lua}/ : \nresp :>>\n"            ..t.res..   "\n\n<<  ")
    return resp.status,resp.body
end



--[[
local h                     =   ngx.req.raw_header()
ngx.log(ngx.WARN,"-- \n{aporo_api.lua} : \nheader :>>\n"      ..cjson.encode(h)..    "\n<< ")
--]]


local r                     =   {}
local args                  =   ngx.req.get_uri_args()
for k, v in pairs(args) do
    if v==true then
        r = cjson.decode(k)
        ngx.log(ngx.WARN,"-- \n{aporo_api.lua} : \nuri_args :>>\n"    ..cjson.encode(r)..    "\n<< ")
        ngx.log(ngx.WARN,"-- \n{aporo_api.lua} : \naction :>>\n"    ..r.action..    "\n<< ")
        break
    end
end


if ngx.var.request_method=='POST' then
    ngx.req.read_body()
    local post_args             =   ngx.req.get_post_args()
    for k,v in pairs(post_args) do
        if v==true then
            r = cjson.decode(k)[1]
            ngx.log(ngx.WARN,"-- \n{aporo_api.lua} : \npost_args :>>\n"    ..cjson.encode(r)..    "\n<< ")
            break
        end
    end
end

ngx.log(ngx.WARN,"#>>>-- \n{aporo_api.lua} : \nuri :>>\n"    ..ngx.var.request_uri..    "\n<<<# ")

if ngx.var.request_uri:find("/api/work/") then
    if ngx.var.request_method=='GET' then
--        q=[[    SELECT z_update_with_geom_from_coords(  ]]..r['idx']..[[,
--                                                        ']]..r['table']..[[',
--                                                        ']]..r['uid_col']..[[',
--                                                        'gc_lat',
--                                                        'gc_lon'  ) res ; ]]
--        _,q_res_body = make_query(q)
--        local q_res = cjson.decode(q_res_body)[1]
--        if q_res.res=="OK" then
--            tag = "complete: added geom by matching with geocoding results"
--        else
--            tag = "complete: process failed (ended after no results from geocoding)"
--        end
        local t = [[{"dg_schedule":[{"start_datetime":"2014-11-11T16:00:00","start_day":"Tue, Nov. 11","start_time":"08:00 PM","hour_period":4,"area":"Murray Hill","check_in_datetime":null,"check_out_datetime":null,"total_breaktime":null,"total_deliveries":null},{"start_datetime":"2014-11-12T08:00:00","start_day":"Wed, Nov. 12","start_time":"12:00 PM","hour_period":4,"area":"Murray Hill","check_in_datetime":null,"check_out_datetime":null,"total_breaktime":null,"total_deliveries":null}]}]]
        local res = cjson.decode(t)
    --    ngx.log(ngx.WARN,"-- \n{aporo_api.lua} : \njson :>>\n"    ..cjson.encode(res)..    "\n<< ")
        ngx.say(cjson.encode(res))
    end
end

if ngx.var.request_uri:find("/api/dg_contracts/") then

    if ngx.var.request_method=='GET' then
        ngx.log(ngx.WARN,"-- \n{aporo_api.lua} : \n\n >>GET TO dg_contract<<\n\n ")

        local t = [[{"contract_id": "4","start_datetime": "2015-04-02T08:00:00","start_day": "Thu,Jul. 17","start_time": "12:00 PM","hour_period": "4","area": "Murray Hill","curriers": [{ "currier_id": 1}]}]]
        local res = cjson.decode(t)
        ngx.log(ngx.WARN,"-- \n{aporo_api.lua} : \njson :>>\n"    ..cjson.encode(res)..    "\n<< ")
        ngx.say(cjson.encode(res))
    end

    if ngx.var.request_method=='POST' then
        ngx.log(ngx.WARN,"-- \n{aporo_api.lua} : \n\n >>POST TO dg_contract<<\n\n ")

        ngx.req.read_body()
        local post_args             =   ngx.req.get_post_args()
        for k,v in pairs(post_args) do
            if v==true then
                r = cjson.decode(k)[1]
                ngx.log(ngx.WARN,"-- \n{aporo_api.lua} : \npost_args :>>\n"    ..cjson.encode(r)..    "\n<< ")
                ngx.log(ngx.WARN,"-- \n{aporo_api.lua} : \naction :>>\n"    ..r.action..    "\n<< ")
                break
            end
        end





        if r.action=="add" then
            local t = [[{"contracts.json":[{ "area": "Murray Hill","contract_id": 36,"curriers": [{"currier_id": 1}],"hour_period": 4,"start_datetime": "2015-07-23T16:00:00","start_day": "Wed,Jul. 23","start_time": "08:00 PM"},{"area": "Murray Hill","contract_id": 70,"curriers": [],"hour_period": 4,"start_datetime": "2014-07-29T08:00:00","start_day": "Tue,Jul. 29","start_time": "12:00 PM" },],"work.json": [{"area": "Murray Hill","check_in_datetime": "","check_out_datetime": "","hour_period": 4,"start_datetime": "2015-07-22T12:00:00","start_day": "Tue,Jul. 22","start_time": "04:00 PM","total_breaktime": "","total_deliveries": "",},],}]]
            local res = cjson.decode(t)
            ngx.log(ngx.WARN,"-- \n{aporo_api.lua} : \nADDED json :>>\n"    ..cjson.encode(res)..    "\n<< ")
            ngx.say(cjson.encode(res))


        elseif r.action=="remove" then
            local t = [[{"contracts.json":"","work.json": [{ "area": "Murray Hill","check_in_datetime": "","check_out_datetime": "","hour_period": 4,"start_datetime": "2015-07-22T12:00:00","start_day": "Tue,Jul. 22","start_time": "04:00 PM","total_breaktime": "","total_deliveries": ""}]}]]
            local res = cjson.decode(t)
            ngx.log(ngx.WARN,"-- \n{aporo_api.lua} : \nREMOVED json :>>\n"    ..cjson.encode(res)..    "\n<< ")
            ngx.say(cjson.encode(res))
        end


    end

end


ngx.exit(ngx.OK)



