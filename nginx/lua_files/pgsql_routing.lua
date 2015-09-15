
-- sites-available/lua_files/printer_check_in.lua
module("pgsql_routing", package.seeall)

--ngx.log(ngx.WARN,"-- {pgsql_routing.lua}/ : START :>>  <<  ")

local cjson                 =   require "cjson"

function make_query(qry)
    --ngx.log(ngx.WARN,"\n\n\n"..qry.."\n\n\n")
    local resp                  =   ngx.location.capture('/query?qry='..qry)
    if resp.status~=200 then
        ngx.log(ngx.WARN,"-- {pgsql_routing.lua}/ : pgsql_args :>>"      ..qry..                        "<<  ")
        ngx.log(ngx.WARN,"-- {pgsql_routing.lua}/ : resp :>>"            ..cjson.encode(resp.status)..   "<<  ")
    end
    --ngx.log(ngx.WARN,"-- \n{pgsql_routing.lua}/ : \nresp :>>\n"            ..t.res..   "\n\n<<  ")
    return resp.status,resp.body
end

--[[

 TRIGGERS:
    ?table=seamless&trigger=new_address                 ---->
    ?table=yelp&trigger=new_address                     ---->
    ?table=yelp&trigger=get_geom_from_coords            ---->


--]]



--[[
local h                     =   ngx.req.raw_header()
ngx.log(ngx.WARN,"-- \n{pgsql_routing.lua} : \nheader :>>\n"      ..cjson.encode(h)..    "\n<< ")
--]]

local r                     =   {}
local args                  =   ngx.req.get_uri_args()
for k, v in pairs(args) do
    r[k]                  =   v
end
--ngx.log(ngx.WARN,"-- \n{pgsql_routing.lua} : \nuri_args :>>\n"    ..cjson.encode(r)..    "\n<< ")

local qry,q_res_status,q_res_body = "","",""
local tag = r['trigger']
if tag then

    if tag=='get_geom_from_coords' then
        qry = "SELECT z_update_with_geom_from_coords("..r['idx']..",'yelp','uid','latitude','longitude') res;"
        _,q_res_body = make_query(qry)
        if cjson.decode(q_res_body)[1].res=="nothing updated" then
            qry = "update yelp set trigger_step='geom_from_coord_failed' where uid = "..r['idx']..";"
            make_query(qry)
        end
    end

    ngx.log(ngx.WARN,"-- \n{pgsql_routing.lua} : \n TAG:>>\n"..tag.."\n<< ")

    if not tag:find('^MN.') then
        q = [[  select count(*)!=0 res from
                    (select ]]..r['zip_col']..[[ zipcode from ]]..r['table']..[[ where ]]..r['uid_col']..[[ = ]]..r['idx']..[[ ) f1,
                    mn_zipcodes mn
                where mn.zip = zipcode ]]
        _,q_res_body = make_query(q)
        local q_res = cjson.decode(q_res_body)[1]
        if q_res.res then
            tag = "MN."..tag
        else
            tag = "complete: NON MN ZIPCODE"
            q = "update "..r['table'].." set trigger_step = '"..tag.."' where "..r['uid_col'].."="..r['idx']
            make_query(q)
            ngx.exit(ngx.OK)
        end
    end

    ngx.log(ngx.WARN,"-- \n{pgsql_routing.lua} : \n TAG:>>\n"..tag.."\n<< ")

    if tag:find('new_address$') then
        q = [[  select z_update_with_parsed_info(   ]]..r['idx']..[[, ']]..r['table']..[['::text,
                                                        ']]..r['uid_col']..[['::text, ']]..r['addr_col']..[['::text,
                                                        ']]..r['zip_col']..[['::text) res ;]]
        _,q_res_body = make_query(q)
        local q_res = cjson.decode(q_res_body)[1]
        if q_res.res=="OK" then
            tag = tag..".parsed"                    -- CONTINUES DOWN DECODING TRAIN.. CHUGGA CHUGGA WO WOOO
        else
            tag = tag..".parsed.failed"             -- GOES TO GEOCODING
        end
    end

    ngx.log(ngx.WARN,"-- \n{pgsql_routing.lua} : \n TAG:>>\n"..tag.."\n<< ")

    if tag:find(".parsed.failed$") then
        -- STRING DISTANCES AGAINST ALL
        --      BEST MATCH FROM: pad_adr,usps.common_use,usps.usps_abbr,snd.primary_name,snd.variation )
        q=[[select z_update_addr_with_string_dist_on_all(]]..r['idx']..[[,
                ']]..r['table']..[[',
                ']]..r['uid_col']..[[',
                ']]..r['addr_col']..[[',
                ']]..r['zip_col']..[[') res;]]
        _,q_res_body = make_query(q)
        local q_res = cjson.decode(q_res_body)[1]
        if q_res.res=="OK" then
            tag = tag..".string_dist.parsed"
        elseif q_res.res=="nothing updated" then
            tag = tag..".string_dist.and.parsed.failed"
        else
            tag = tag..".string_dist.unknown"
        end
    end

--  TEST SCRIPT
--    if tag:find("MN.new_address.parsed.geom.failed.new_address.parsed") then
--
--        q = [[  select z_update_with_geom_from_parsed(   ]]..r['idx']..[[, ']]..r['table']..[['::text,
--                                                        ']]..r['uid_col']..[['::text) res]]
--        ngx.log(ngx.WARN,"-- \n{pgsql_routing.lua} : \n Q:>>\n\n"..q.."\n\n<< ")
--
--        tag = "PAUSING"
--        q = "update "..r['table'].." set trigger_step = '"..tag.."' where "..r['uid_col'].."="..r['idx']
--        make_query(q)
--        ngx.exit(ngx.OK)
--    end

    ngx.log(ngx.WARN,"-- \n{pgsql_routing.lua} : \n TAG:>>\n"..tag.."\n<< ")

    if tag:find(".parsed$") then
        q = [[  select z_update_with_geom_from_parsed(   ]]..r['idx']..[[, ']]..r['table']..[['::text,
                                                        ']]..r['uid_col']..[['::text) res]]
        _,q_res_body = make_query(q)
        local q_res = cjson.decode(q_res_body)[1]
        if q_res.res=="OK" then
            tag = "complete"
            q = "update "..r['table'].." set trigger_step = '"..tag.."' where "..r['uid_col'].."="..r['idx']
            make_query(q)
            ngx.exit(ngx.OK)
        end

        -- CROSS WITH SND (which will update parsed info on match, if any)
        q = [[select z_update_by_crossing_with_snd( ]]..r['idx']..[[,
                                                    ']]..r['table']..[['::text,
                                                    ']]..r['uid_col']..[['::text);]]
        _,q_res_body = make_query(q)

        -- RE-ATTEMPT TO MATCH
        q = [[  select z_update_with_geom_from_parsed(   ]]..r['idx']..[[, ']]..r['table']..[['::text,
                                                    ']]..r['uid_col']..[['::text) res]]
        _,q_res_body = make_query(q)
        q_res = cjson.decode(q_res_body)[1]
        if q_res.res=="OK" then
            tag = "complete"
            q = "update "..r['table'].." set trigger_step = '"..tag.."' where "..r['uid_col'].."="..r['idx']
            make_query(q)
            ngx.exit(ngx.OK)
        end

        tag = tag..".geom.failed"

    end

    ngx.log(ngx.WARN,"-- \n{pgsql_routing.lua} : \n TAG:>>\n"..tag.."\n<< ")

    if tag:find(".parsed.geom.failed$") then
        -- STRING DISTANCES AGAINST ALL
        --      BEST MATCH FROM: pad_adr,usps.common_use,usps.usps_abbr,snd.primary_name,snd.variation )
        q=[[select z_update_addr_with_string_dist_on_all(]]..r['idx']..[[,
                ']]..r['table']..[[',
                ']]..r['uid_col']..[[',
                ']]..r['addr_col']..[[',
                ']]..r['zip_col']..[[') res;]]
        _,q_res_body = make_query(q)
        local q_res = cjson.decode(q_res_body)[1]
        if q_res.res=="OK" then
            tag = tag..".new_address"
            q = "update "..r['table'].." set trigger_step = '"..tag.."' where "..r['uid_col'].."="..r['idx']
            make_query(q)
            ngx.exit(ngx.OK)
        elseif q_res.res=="nothing updated" then
            tag = tag..".string_dist.failed"
        else
            tag = tag..".string_dist.unknown"
        end
    end

    ngx.log(ngx.WARN,"-- \n{pgsql_routing.lua} : \n TAG (AND CHECKING):>>\n"..tag.."\n<< ")

    if tag:find(".geocoded.") then
        -- Match GEOM to Geocoding Results
        q=[[    SELECT z_update_with_geom_from_coords(  ]]..r['idx']..[[,
                                                        ']]..r['table']..[[',
                                                        ']]..r['uid_col']..[[',
                                                        'gc_lat',
                                                        'gc_lon'  ) res ; ]]
        _,q_res_body = make_query(q)
        local q_res = cjson.decode(q_res_body)[1]
        if q_res.res=="OK" then
            tag = "complete: added geom by matching with geocoding results"
        else
            tag = "complete: process failed (ended after no results from geocoding)"
        end
        q = "update "..r['table'].." set trigger_step = '"..tag.."' where "..r['uid_col'].."="..r['idx']
        make_query(q)
        ngx.exit(ngx.OK)
    end

    if tag:find(".string_dist.failed$") or tag:find(".parsed.failed$") then
        -- Geocoding Results
        q=[[    SELECT z_update_with_geocode_info(  ]]..r['idx']..[[,
                                                ']]..r['table']..[[',
                                                ']]..r['uid_col']..[[',
                                                ']]..r['addr_col']..[[',
                                                ']]..r['zip_col']..[['  ) res ; ]]
        _,q_res_body = make_query(q)
        local q_res = cjson.decode(q_res_body)[1]
        if q_res.res=="OK" then
            q=[[    UPDATE ]]..r['table'].." SET "..r['addr_col']..[[ = gc_addr
                    WHERE ]]..r['uid_col'].." = "..r['idx'].." and "..r['zip_col'].." = gc_zip"
            _,q_res_body = make_query(q)
            tag = tag..".geocoded.new_address"
        else
            tag = "complete: process failed (ended after no results from geocoding)"
        end
        q = "update "..r['table'].." set trigger_step = '"..tag.."' where "..r['uid_col'].."="..r['idx']
        make_query(q)
        ngx.exit(ngx.OK)
    end

    ngx.log(ngx.WARN,"-- \n{pgsql_routing.lua} : \n TAG:>>\n"..tag.."\n<< ")

end

ngx.log(ngx.WARN,"-- \n{pgsql_routing.lua} : \n\nEND\n\n :>>  <<  ")
ngx.exit(ngx.OK)