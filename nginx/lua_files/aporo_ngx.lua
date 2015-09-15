
-- sites-available/lua_files/aporo_ngx.lua
module("aporo_ngx", package.seeall)

--ngx.log(ngx.WARN,"#>>> {aporo_ngx.lua}: START <<<#")

local cjson                 =   require "cjson"

function make_query(qry)
    --ngx.log(ngx.WARN,"\n\n\n"..qry.."\n\n\n")
    local resp                  =   ngx.location.capture('/query?'..ngx.encode_args({qry=qry}))
    if resp.status~=200 then
        ngx.log(ngx.WARN,"#>>> {aporo_ngx.lua}:pgsql_args "      ..qry..                        "<<<#")
        ngx.log(ngx.WARN,"#>>> {aporo_ngx.lua}:pgsql_resp "      ..cjson.encode(resp.status)..  "<<<#")
    end
    --ngx.log(ngx.WARN,"-- \n{aporo_ngx.lua}/ : \nresp :>>\n"            ..t.res..   "\n\n<<  ")
    return resp.status,resp.body
end



--[[
local h                     =   ngx.req.raw_header()
ngx.log(ngx.WARN,"-- \n{aporo_ngx.lua} : \nheader :>>\n"      ..cjson.encode(h)..    "\n<< ")
--]]



local uri_args                  =   ngx.req.get_uri_args()
--ngx.log(ngx.WARN,"#>>> {aporo_ngx.lua}:uri_args "    ..cjson.encode({type(uri_args),uri_args})..    "<<<#")

local post_args                 =   {}
if ngx.var.request_method=='POST' then
    ngx.req.read_body()
    post_args                   =   ngx.req.get_post_args()
--    ngx.log(ngx.WARN,"#>>> {aporo_ngx.lua}:post_args "    ..cjson.encode({type(post_args),post_args})..    "<<<#")
end

--ngx.log(ngx.WARN,"#>>> {aporo_ngx.lua}:uri "    ..ngx.var.request_uri..    "<<<#")
if uri_args.trigger then
--    ngx.log(ngx.WARN,"#>>> {aporo_ngx.lua}: --TRIGGER-- <<<#")

    if uri_args.trigger=='vend_sched_insert' then
--        ngx.log(ngx.WARN,"#>>> {aporo_ngx.lua}: --vend_sched_insert-- <<<#")
        local days_year = uri_args.new
        days_year = days_year:gsub('"',"")


        local qry = [[  SELECT  distribute_normalize_dg_vend_reqs(to_char(vc.start_datetime,'DDD YYYY'))
                        FROM    vend_sched vc
                        WHERE   to_char(start_datetime,'DDD YYYY') = ]].."'"..days_year.."'"
        qry = qry:gsub("\n"," ")
        make_query(qry)
    end
end




ngx.exit(ngx.OK)



