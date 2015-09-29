--
-- User: sethc23
-- Date: 9/16/15
-- Time: 10:05 PM
--
--module("string_matching", package.seeall)
package.loaded.string_matching = nil
package.loaded.utility = nil

local util = require "utility"
-- _debug = util.debug
round = util.round
--cjson_encode = util.cjson_encode --only produces output when verbose=true
cj = require "cjson"
local str_util = require"string_utils"
split_str_with_div = str_util.split_gen

local u = {}

function u.jaro_score(s1,s2,winklerize,long_tolerance,numeric_lcs,verbose)
    --package.loaded.mobdebug = nil
    --require('mobdebug').start("10.0.1.53")
    
    local log_to_file           =   false
    -- _debug(                         {msg={"NEW JARO SCORE\\n\\n"},verbose=verbose,to_file=log_to_file})

    --if #s1==0 or #s2==0 then
    --    _debug(                     {msg={"s1 or s2 has no length!"},verbose=verbose,to_file=log_to_file})
    --end

    -- require matching numeric LCS (lowest common substring)
    if numeric_lcs then
        --package.loaded.mobdebug = nil
        --require('mobdebug').start("10.0.1.53")
        local n1 = s1:gsub("[^%d]*","")
        local n2 = s2:gsub("[^%d]*","")
        if n1~=n2 then return 0 end
    end


    -- set #a>#b
    local a,b                 =   "",""
    if #s1<#s2 then     b,a     =   s1,s2
    else                a,b     =   s1,s2   end
    a,b                         =   a:upper(),b:upper()
    -- _debug(                         {msg={"a: ",a}, verbose=verbose, to_file=log_to_file})

    -- define max distance where character will be considered matching (despite tranposition)
    local match_dist            =   round( (#a/2) - 1 )
    if match_dist<0 then            match_dist=0 end
    -- _debug(                         {msg={"match_dist=",match_dist}, verbose=verbose, to_file=log_to_file})

    -- create letter and flags tables
    local a_tbl,b_tbl           =   {},{}
    local a_flags,b_flags       =   {},{}
    for i=1,#a do
        table.insert(               a_tbl,a:sub(i,i))
        table.insert(               a_flags,false)

        table.insert(               b_tbl,b:sub(i,i))
        table.insert(               b_flags,false)
    end
    for i=#a+1, #b do
        table.insert(               b_tbl,b:sub(i,i))
        table.insert(               b_flags,false)
    end
    -- _debug(                         {msg={"a_tbl ",cjson_encode(a_tbl)}, verbose=verbose, to_file=log_to_file})
    -- _debug(                         {msg={"b_tbl ",cjson_encode(b_tbl)}, verbose=verbose, to_file=log_to_file})
    -- _debug(                         {msg={"b_tbl[3] ",b_tbl[3]}, verbose=verbose, to_file=log_to_file})

    -- verify tables are proper length
    if (not #a==#a_tbl==#a_flags) or (not #b==#b_tbl==#b_flags) then
        log(                        "issue with length of string/tbl/flags: "..#a.."/"..#a_tbl.."/"..#a_flags)
    end

    -- looking only within the match distance, count & flag matched pairs
    local low,hi,common         =   0,0,0
    local i,j
    for _i,v in ipairs(a_tbl) do
        i = _i-1

        local cursor            =   v
        -- _debug(                     {msg={"cursor_1=",cursor}, verbose=verbose, to_file=log_to_file})

        if i>match_dist then
            low                 =   i-match_dist
        else
            low                 =   0
        end
        if i+match_dist<=#b then
            hi                  =   i+match_dist
        else
            hi                  =   #b
        end

        -- _debug(                     {msg={"low_hi ",low," ",hi}, verbose=verbose, to_file=log_to_file})

        for _j=low+1, hi+1 do
            j                   =   _j-1

            -- _debug(                 {msg={"ij ",i," ",j}, verbose=verbose, to_file=log_to_file})
            -- _debug(                 {msg={"cursor ",cursor}, verbose=verbose, to_file=log_to_file})
            -- _debug(                 {msg={{"b_tbl[j+1] "},b_tbl[j+1]}, verbose=verbose, to_file=log_to_file})

            if not b_flags[j+1] and b_tbl[j+1]==cursor then
                -- _debug(             {msg={"BREAK_HERE"}, verbose=verbose, to_file=log_to_file})
                a_flags[i+1]    =   true
                b_flags[j+1]    =   true
                common          =   common+1
                break
            end
        end
    end
    -- _debug(                         {msg={"a_flags=",cjson_encode(a_flags)}, verbose=verbose, to_file=log_to_file})
    -- _debug(                         {msg={"b_flags=",cjson_encode(b_flags)}, verbose=verbose, to_file=log_to_file})

    -- return nil if no exact or transpositional matches
    if common==0 then               return nil end
    -- _debug(                         {msg={"common = ",common}, verbose=verbose, to_file=log_to_file})

    -- count transpositions
    local first,k,trans_count   =   true,1,0
    local _j
    for _i,_ in ipairs(a_tbl) do
        i                       =   _i - 1

        if a_flags[i+1] then

            for j=k, #b do
                _j              =   j - 1

                -- _debug(            {msg={"i},j,_j= ",i,",",j,",",_j}, verbose=verbose, to_file=log_to_file})
                -- _debug(            {msg={"b_flags[j]= ",cjson_encode({b_flags[j]})}, verbose=verbose, to_file=log_to_file})

                if b_flags[j] then
                    k           =   j+1
                    break
                end
            end

            -- _debug(                 {msg={"k= ",k}, verbose=verbose, to_file=log_to_file})
            -- _debug(                 {msg={"a_tbl[i+1]= ",a_tbl[i+1]}, verbose=verbose, to_file=log_to_file})

            if not j and first then
                _j,first        =   1,false
            else
                _j              =   _j + 1
            end

            -- _debug(                 {msg={"b_tbl[_j]= ",b_tbl[_j]}, verbose=verbose, to_file=log_to_file})
            if a_tbl[i+1]~=b_tbl[_j] then
                if (not trans_count or trans_count==0) then
                    trans_count =   1
                else
                    trans_count =   trans_count+1
                end
            end

        end
    end
    trans_count                 =   trans_count/2
    -- _debug(                         {msg={"trans_count = ",trans_count}, verbose=verbose, to_file=log_to_file})

    -- adjust for similarities in nonmatched characters
    local weight                =   0
    weight                      =   ( ( common/#a + common/#b +
                                        (common-trans_count)/common ) )/3
    -- _debug(                         {msg={"weight = ",weight}, verbose=verbose, to_file=log_to_file})

    -- winkler modification: continue to boost if strings are similar
    local _i                    =   0
    if winklerize and weight>0.7 and #a>3 and #b>3 then

        -- adjust for up to first 4 chars in common

        if #a<4 then                j = #a
        else                        j = 4 end
        -- _debug(                     {msg={"i},j_1= ",i,",",j}, verbose=verbose, to_file=log_to_file})

        for _i=1, j-1 do
            if _i==1 then           i = _i-1 end
            if a_tbl[_i]==b_tbl[_i] and #b>=_i then
                if not i then       i = 1
                else                i = i+1 end
                -- _debug(             {msg={"i},_i,j_2= ",i,",",_i,",",j}, verbose=verbose, to_file=log_to_file})
            end
            if i>j then             break end
        end
        -- _debug(                     {msg={"i},_i,j_3= ",i,",",_i,",",j}, verbose=verbose, to_file=log_to_file})

        if i-1>0 then
            i = i-1
            weight              =   weight + ( i * 0.1 * (1.0 - weight) )
        end
        -- _debug(                     {msg={"new weight_1 = ",weight}, verbose=verbose, to_file=log_to_file})

        -- optionally adjust for long strings
        -- after agreeing beginning chars, at least two or more must agree and
        -- agreed characters must be > half of remaining characters
        if ( long_tolerance and
             #a>4 and
             common>i+1 and
             2*common>=#a+i ) then
            weight              =   weight + ((1.0 - weight) * ( (common-i-1) / (#a+#b-i*2+2)))
        end

        -- _debug(                     {msg={"new weight_2 = ",weight}, verbose=verbose, to_file=log_to_file})

    end

    return weight

end

function u.perm_jaro(t)

    local get_div_tbl_from_str = function  (t)
        local div_str,sep_mark
        if type(t)=="string" then div_str,sep_mark=t,";"
        else setmetatable(t,{__index={div_str=t[1], sep_mark=t[2] or ";"}}) end
        local div,sep_tbl = "",{}
        for _sep in div_str:gmatch(".") do
            if _sep==sep_mark then
                if div=="" then
                    table.insert(sep_tbl,1+#sep_tbl,sep_mark)
                else
                    table.insert(sep_tbl,1+#sep_tbl,div)
                    div=""
                end
            else
                div = div.._sep
            end
        end
        if div~="" then table.insert(sep_tbl,1+#sep_tbl,div) end
        return  sep_tbl
    end

    local split_str_with_div = function (str,div)

        local str_parts = {}
        local i,next_match = 1,0,0
        while true do
            next_match = str:find(div,i,true)
            if not next_match then
                if not str_parts then
                    table.insert(str_parts,1+#str_parts,str)
                else
                    table.insert(str_parts,1+#str_parts,str:sub(i))
                end
                break
            else
                table.insert(str_parts,1+#str_parts,str:sub(i,next_match-1))
                i = next_match + #div
            end
            if i>=#str then break end
        end
        return str_parts

    end

    local split_str_with_div_tbl = function (str,div_tbl)

        local str_parts = {str}
        local cnt_a,cnt_b=1,1
        while true do

            cnt_a = #str_parts

            local new_str_parts = {}
            for i,v in ipairs(str_parts) do
                table.insert(new_str_parts,i,v)
            end

            for i,_part in ipairs(new_str_parts) do

                local cnt = 0
                local split_parts
                for _,div in ipairs(div_tbl) do
                    split_parts = split_str_with_div(_part,div)
                    if #split_parts>1 then
                        break
                    else
                        cnt = cnt + 1
                    end
                end
                if cnt~=#div_tbl then

                    for j=1,#split_parts do
                        table.insert(str_parts,i-1+j,split_parts[j])
                    end
                    table.remove(str_parts,i+#split_parts)
                    break

                end

            end

            cnt_b = #str_parts

            if cnt_a==cnt_b then break end

        end

        return str_parts

    end

    local _normalize = function(_str)
        if type(_str)=="table" then
            return table.concat( _str, t.concat_str )
        else
            local tbl = split_str_with_div_tbl( _str, t.div_tbl )
            return table.concat( tbl, t.concat_str )
        end
    end

    local b_perm = function(concat_str,div_str,div_tbl,a_str,b_str)
        local a_str_norm = _normalize(a_str,div_tbl,concat_str)
        local b_str_split_to_tbl = split_str_with_div_tbl( b_str, div_tbl )
        local j_score,new_j_score = 0
        local match_str
        for k in t.p.perm( b_str_split_to_tbl ) do
            b_str = table.concat(k, concat_str)
            new_j_score = u.jaro_score( a_str_norm, b_str, false, false, t.numeric_lcs, false )
            if new_j_score and new_j_score>j_score then
                j_score = new_j_score
                match_str = b_str
            end
        end
        return j_score,match_str
    end

    local b_iter = function(concat_str,div_str,div_tbl,a_str,b_str)
        local a_str_norm = _normalize(a_str,div_tbl,concat_str)
        local b_str_split_to_tbl = split_str_with_div_tbl( b_str, div_tbl )
        local j_score,new_j_score = 0
        local match_str
        for i in pairs( b_str_split_to_tbl ) do
            new_j_score = u.jaro_score(a_str_norm, b_str_split_to_tbl[i], false, false, t.numeric_lcs, false)
            if new_j_score and new_j_score>j_score then
                j_score=new_j_score
                match_str=b_str_split_to_tbl[i]
            end
        end
        return j_score,match_str
    end

    -- TODO: need to develop feature for div_type="all" (current) vs. div_type="each" (best match after iterating each div_str)

    --package.loaded.mobdebug = nil
    --require('mobdebug').start("10.0.1.53")

--    assert(type(t)~="table",[[
--        Expected table as first argument, e.g.,
--            ( div_str, { jaro_score vars } )
--        Use ';;' for ';' splitter.
--        Default is ' ;_;/;\;|;&'
--    ]])



    if type(t)=="string" then
        local tmp = t
        t = {}
        t.div_str = tmp
    end

    if not t.div_str or t.div_str=="" then t.div_str = " ;-;_;/;\\;|;&;;" end
    if not t.concat_str then t.concat_str=" " end

    t.div_tbl = get_div_tbl_from_str(t.div_str)
    local a_str_split_to_tbl = split_str_with_div_tbl( t.s1, t.div_tbl )
    local a_str
    local b_str = t.s2
    
    
    local a_str_mod,b_str_mod
    if t.a_str_mod=="iter" then a_str_mod = pairs
    elseif t.a_str_mod=="perm" then a_str_mod = t.p.perm
    elseif not t.a_str_mod or t.a_str_mod=="" or t.a_str_mod=="norm" then
        a_str_mod = function(in_str) return pairs({_normalize(in_str)}) end
    else
        a_str_mod =   function(in_str) return pairs({in_str}) end
    end

    if t.b_str_mod=="iter" then b_str_mod = pairs 
    elseif t.b_str_mod=="perm" then b_str_mod = t.p.perm 
    elseif not t.b_str_mod or t.b_str_mod=="norm" then
        b_str = _normalize(b_str)
    else
        b_str_mod =  nil
    end
    
   
    local iter_res = {}
    local return_res = {}
    iter_res.j_score = 0
    return_res.j_score = 0
    local new_j_score
    for k in a_str_mod( a_str_split_to_tbl ) do

        if type(k)=="table" then 
            a_str = table.concat(k,t.concat_str)
        else a_str = a_str_split_to_tbl[k] end
        iter_res.a_str = a_str
        
        if type(b_str_mod)=="function" then
            local new_b_str
            new_j_score,new_b_str = b_str_mod(t.concat_str,t.div_str,t.div_tbl,a_str,b_str)
            iter_res.b_str = new_b_str
        else
            new_j_score = u.jaro_score(a_str, b_str, false, false, t.numeric_lcs, false)
            iter_res.b_str = b_str
        end

        if new_j_score and new_j_score>return_res.j_score then  -- nil return when no matches
            return_res.j_score = new_j_score
            return_res.a_str = iter_res.a_str
            return_res.b_str = iter_res.b_str
        end

    end

    return return_res

end

function u.iter_jaro(qry_a,qry_b,params)

    --package.loaded.mobdebug = nil
    --require('mobdebug').start("10.0.1.53")

    local process_b_rows = function (_L)
        local iter_res,return_res = {},{}
        local new_j_score
        local cnt = 0
        for b_row in _L.qry_b:rows{_L.b_q_offset,_L.b_q_lim} do
            _L.i2,_L.s2 = b_row.b_idx,b_row.b_str
            if _L.a_str_mod or _L.b_str_mod then
                iter_res = _L.perm_jaro( _L )
            else
                new_j_score = _L.jaro_score(_L.s1, _L.s2, false, false, _L.numeric_lcs, false)
                iter_res.a_str = _L.s1
                iter_res.b_str = _L.s2
                iter_res.j_score = new_j_score
            end


            --if new_j_score and new_j_score>0 then
            if iter_res.j_score and iter_res.j_score>_L.j_score then
                _L.j_score = iter_res.j_score
                _L.res_i2,_L.res_s2 = _L.i2,_L.s2
                _L.res_m1,_L.res_m2 = iter_res.a_str,iter_res.b_str
                _L.other_matches = {}
            elseif new_j_score==_L.j_score then
                table.insert(_L.other_matches,b_row.b_idx)
            end
            --end
            cnt = cnt + 1
        end
        if cnt==_L.b_q_lim then
            _L.b_q_offset = _L.b_q_offset + _L.b_q_lim
            _L.process_b_rows(_L)
        end
    end

    local process_a_rows = function (_L)
        local cnt = 0
        _L.a_rows = {}
        for a_row in _L.qry_a:rows{_L.a_q_offset,_L.a_q_lim} do
            table.insert(_L.a_rows,{i1=a_row.a_idx,s1=a_row.a_str,j_score=0})
            cnt = cnt + 1
        end
        for _,a_row in ipairs(_L.a_rows) do
            _L.i1,_L.s1 = a_row.i1,a_row.s1
            _L.j_score = a_row.j_score
            
            --_L.prof.start()
            process_b_rows(_L)
            --_L.prof.stop()

            if _L.caller then
                if _L.caller:lower()=="lua" then
                    coroutine.yield{ 
                      a_idx=_L.i1,
                      a_str=_L.s1,
                      a_match=_L.res_m1,
                      jaro_score=_L.j_score,
                      b_match=_L.res_m2,
                      b_str=_L.res_s2,
                      b_idx=_L.res_i2,
                      other_matches=_L.other_matches
                      }
                end
            else
                coroutine.yield{ 
                  a_idx=_L.i1, 
                  a_str=_L.s1,
                  a_match=_L.res_m1,
                  jaro_score=tostring(_L.j_score),
                  b_match=_L.res_m2,
                  b_str=_L.res_s2, 
                  b_idx=_L.res_i2, 
                  other_matches=cj.encode(_L.other_matches) 
                  }
            end
                
        end
        if cnt==_L.a_q_lim then
            _L.a_q_offset = _L.a_q_offset + _L.a_q_lim
            _L.results = _L.process_a_rows(_L)
        end
        return _L
    end

    local query_prep = function (_L)

        local qry_b_cnt,b_cnt
        qry_b_cnt = "SELECT COUNT(*)::TEXT pllua_cnt FROM (".._L.orig_qry_b..") pllua_f1;"

        for r in server.rows(qry_b_cnt) do
            b_cnt = r["pllua_cnt"]
            break
        end

        _L.b_q_lim = _L.qry_max
        _L.a_q_lim = _L.qry_max
        _L.a_q_offset,_L.b_q_offset = 0,0

        local _qry_a = [[SELECT a_str::text,a_idx::text
                         FROM (]].._L.orig_qry_a..[[) pllua_f
                         ORDER BY pllua_f.a_idx ASC
                         OFFSET $1 LIMIT $2;]]
        _L.qry_a = server.prepare(_qry_a, {"int4","int4"}):save()

        local _qry_b = [[SELECT b_str::text,b_idx::text
                         FROM (]].._L.orig_qry_b..[[) pllua_f
                         ORDER BY pllua_f.b_idx ASC
                         OFFSET $1 LIMIT $2;]]
        _L.qry_b = server.prepare(_qry_b, {"int4","int4"}):save()
        return _L

    end



    --package.loaded.mobdebug = nil
    --package.loaded.string_matching = nil
    --package.loaded.cjson = nil
    --package.loaded.tbl_utils = nil
    --package.loaded.permutations = nil

    
    
    --cj = require "cjson"
    --tbl = require "tbl_utils"
    local max_qry_result_cnt = 1000

    _L = {}
    for k,v in pairs(u) do _L[k]=v end
    _L.orig_qry_a = qry_a
    _L.orig_qry_b = qry_b



    if type(params)=="string" and params~="" then 
        params = cj.decode(params)
    end
    for k,v in pairs(params) do
        if tostring(v):lower()=="false" then params[k]=false end
        if tostring(v):lower()=="true" then params[k]=true end
    end
    if params.numeric_lcs==nil then params.numeric_lcs=false end
    _L = setmetatable(_L, {__index = params})
    if params.a_str_mod or params.b_str_mod then 
        if params.a_str_mod~="" or params.b_str_mod~="" then
          _L.p = require"permutations"
          _L.with_string_mods = true
        end
    end
    if params.func_caller then
        _L.caller = params.func_caller
    end



    _L.qry_max = max_qry_result_cnt

    --os.execute("echo '\\n\\n\\nSTARTING - '`date --utc` >> /tmp/tmpfile")
    
    _L = query_prep(_L)
--    _L.prof=require"profiler"

    _L.process_a_rows,_L.process_b_rows = process_a_rows,process_b_rows

    process_a_rows(_L)
    
--    return _L

end

function u.manage_iter_jaro(input_params)

    package.loaded.mobdebug = nil
    require('mobdebug').start("10.0.1.53")

    local decode_json = function(_input)
        assert(type(_input)=="string", "expected string input for decoding json into table")
        if cj==nil then cj=require"json" end
        return cj.decode(_input)
    end

    local set_params = function (_inputs,_defaults)
        local _res = {}
        local _i
        if #_inputs==0 then 
          _i=1
          local tmp = _inputs
          _inputs = {}
          _inputs[1] = tmp
        else _i=#_inputs end
        for i=1, _i do
            _res[i] = setmetatable(_defaults, {__index=_defaults})
            for k,v in pairs(_inputs[i]) do
                if not _res[i][k] or _res[i][k]==nil then
                    assert(false,"'"..k.."' is not an known parameter")
                else
                    local _k = k:lower()
                    if type(v)=="number" or _k:find("^min") or _k:find("^max") then
                        _res[i][k]=tonumber(v)
                    elseif v:lower()=="true" then
                        _res[i][k]=true
                    elseif v:lower()=="false" then
                        _res[i][k]=false
                    else
                        _res[i][k]=v
                    end
                end
            end
        end
        return _res
    end

    local make_inner_qry = function (qry_prefix,params)

        assert(params[qry_prefix.."_cols"],"input columns missing but required")
        assert(params[qry_prefix.."_tbl"],"input table missing but required")

        if params[qry_prefix.."_related_cols"]~="" then
            params[qry_prefix.."_related_cols"] = "," .. params[qry_prefix.."_related_cols"]
        end

        if params[qry_prefix.."_idx_conditions"]~="" and not params[qry_prefix.."_str_conditions"]~="" then
            params[qry_prefix.."_conditions"] = " WHERE " .. params[qry_prefix.."_idx_conditions"]
        elseif params[qry_prefix.."_str_conditions"]~="" and not params[qry_prefix.."_idx_conditions"]~="" then
            params[qry_prefix.."_conditions"] = " WHERE " .. params[qry_prefix.."_str_conditions"]
        elseif params[qry_prefix.."_idx_conditions"]~="" and params[qry_prefix.."_str_conditions"]~="" then
            params[qry_prefix.."_conditions"] = " WHERE ("..params[qry_prefix.."_idx_conditions"]..") and ("..params[qry_prefix.."_str_conditions"]..")"
        else
            params[qry_prefix.."_conditions"] = ""
        end

        return "SELECT UPPER(CONCAT_WS('"..params.concat_str.."'," ..
                                params[qry_prefix.."_cols"] ..
                                ")) " ..qry_prefix.. "_str," ..
                            params[qry_prefix.."_uid"] .. " " ..qry_prefix.. "_idx" ..
                            params[qry_prefix.."_related_cols"] ..
                        " FROM " .. params[qry_prefix.."_tbl"] .." "..qry_prefix..
                        params[qry_prefix.."_conditions"] ..
                        " ORDER BY " .. params[qry_prefix.."_uid"]
    end

    local get_query_count = function (qry)
        return tonumber(server.execute("WITH _sel AS ("..qry..
                ") SELECT COUNT(*) FROM _sel")[1].count)
    end

    local run_query = function (qry_a, qry_b, params)
        return coroutine.wrap(function () u.iter_jaro(qry_a, qry_b, params) end)
    end

    local first_match_only = function(qry_a, qry_b, params)
        for k in run_query(qry_a, qry_b, params) do
            coroutine.yield(k)
        end
    end

    local func_defaults = {
            a_cols                          =   "",
            a_uid                           =   "",
            a_tbl                           =   "",
            a_related_cols                  =   "",
            a_cols_as_prefix                =   "",
            a_cols_as_suffix                =   "",
            a_str_mod                       =   "norm",  --false,"iter","perm"
            a_idx_conditions                =   "",
            a_str_conditions                =   "",
            b_cols                          =   "",
            b_uid                           =   "",
            b_tbl                           =   "",
            b_related_cols                  =   "",
            b_cols_as_prefix                =   "",
            b_cols_as_suffix                =   "",
            b_str_mod                       =   "norm",  --false,"iter","perm"
            b_idx_conditions                =   "",
            b_str_conditions                =   "",
            match_conditions                =   "",
            update_conditions               =   "",
            do_update                       =   false,
            first_match_only                =   true,
            concat_str                      =   "_",
            div_str                         =   " ;-;_;/;\\;|;&;;",
            min_jaro                        =   0.95,
            func_caller                     =   "lua",
            numeric_lcs                     =   true
        }

    local update_query = function(r,params)

        local update_mapping = {
            a_idx       =   "ts_uid",
            a_str       =   "ts_str",
            jaro_score  =   "jaro_score",
            b_match     =   "match_str",
            b_str       =   "sub_station",
            b_idx       =   "sub_idx"
        }

        params.update_mapping = update_mapping

        local qry = "WITH new AS ( SELECT "..
                            "'"..r.a_idx.."'::INTEGER a_idx, "..
                            "'"..r.a_str.."'::TEXT a_str, "..
                            "'"..r.a_match.."'::TEXT a_match, "..
                            "'"..r.jaro_score.."'::DOUBLE PRECISION jaro_score, "..
                            "'"..r.b_match.."'::TEXT b_match, "..
                            "'"..r.b_str.."'::TEXT b_str, "..
                            "'"..r.b_idx.."'::INTEGER b_idx, "..
                            "'"..r.other_matches.."'::TEXT[] other_matches "..
                        " )"..
                        " UPDATE "..params.a_tbl .." a "..
                        " SET "

        for k,v in pairs(params.update_mapping) do
            qry = qry..v.."=".."new."..k..", "
        end
        qry = qry:sub(1,#qry-2).." "

        if params.update_conditions and params.update_conditions~="" then
            if params.update_conditions:match("%w+")~='AND' then
                params.update_conditions = ' AND '..params.update_conditions
            end
        end

        qry = qry.." FROM new  "..
                   " WHERE new.a_idx=old."..params.update_mapping.a_idx.." "..
                   params.update_conditions..";"
        local a=0
        server.execute(qry)

    end

    local _L = {}
    _L.params = set_params(decode_json(input_params), func_defaults)

    --[[

        most specific to least specific


        numbers exact
        iter_a
        skip_if_one

    --]]

    local u = {}
    local iter_rules = function (u,res,iter_params, n)
        local run_params = iter_params[n]

        _L.qry_a = make_inner_qry("a",run_params)
        _L.qry_b = make_inner_qry("b",run_params)
--        _L.qry_a_cnt = get_query_count(_L.qry_a)
--        _L.qry_b_cnt = get_query_count(_L.qry_b)

        if run_params.first_match_only then
            return first_match_only(_L.qry_a, _L.qry_b, run_params)
        end

        for k in run_query(_L.qry_a, _L.qry_b, run_params) do

            if k.jaro_score>=run_params.min_jaro then
                k.jaro_score = tostring(k.jaro_score)
                k.other_matches = cj.encode(k.other_matches)
                if run_params.do_update or run_params.update_conditions then
                    u.update_query(k,run_params)
                else
                    coroutine.yield(k)
                end
            else
                -- add result if first pass
                if not res[k.a_idx] then
                    res[k.a_idx] = setmetatable(k, {__index=k})
                    res[k.a_idx] = setmetatable(k, {__index=k})

                    if #iter_params>=n+1 then
                        local prefix = " OR "
                        if iter_params[n+1].a_idx_conditions=="" then prefix="" end
                        iter_params[n+1].a_idx_conditions = iter_params[n+1].a_idx_conditions..prefix..iter_params[n+1].a_uid.."="..k.a_str.." "
                    end

                -- if old and new both not exist in the other, go with higher value
                -- if choice between (lower score but exists entirely inside of match) or higher value, chose lower value
                -- if old and new both exist in each other, go with higher value
                elseif

                -- if old/new (both not inside match) or (both inside match), go by score
                    (not res[k.a_idx].a_in_b and not res[k.a_idx].b_in_a)
                        or
                            ( (res[k.a_idx].a_in_b or res[k.a_idx].b_in_a) and
                               (k.a_str:find(k.b_str) or k.b_str:find(k.a_str) ) )
                               then
                        if k.jaro_score>=res[k.a_idx].jaro_score then
                            if k.jaro_score>res[k.a_idx].jaro_score then
                                res[k.a_idx] = setmetatable(k, {__index=k})
                            else
                                local tmp = cj.encode(k.other_matches)
                                table.insert(tmp,1+#tmp,k.b_idx)
                                res[k.a_idx].other_matches = tmp
                            end
                            if k.a_str:find(k.b_str) then res[k.a_idx].a_in_b=true end
                            if k.b_str:find(k.a_str) then res[k.a_idx].b_in_a=true end
                        end


                -- if choice between (no inside match) and (inside match), go by inside match
                elseif (not res[k.a_idx].a_in_b or not res[k.a_idx].b_in_a)
                        and ( k.a_str:find(k.b_str) or k.b_str:find(k.a_str) )
                            then
                            res[k.a_idx] = setmetatable(k, {__index=k})
                            if k.a_str:find(k.b_str) then res[k.a_idx].a_in_b=true end
                            if k.b_str:find(k.a_str) then res[k.a_idx].b_in_a=true end
                end
                
                -- if choice between (lower/inside match) and (higher/no inside match), go by inside match
--                elseif k.jaro_score>=res[k.a_idx].jaro_score then

--                        if (not res[k.a_idx].a_in_b or not res[k.a_idx].b_in_a)
--                            and ( k.a_str:find(k.b_str) or k.b_str:find(k.a_str) )
--                                then
--                            res[k.a_idx] = setmetatable(k, {__index=k})
--                            if k.a_str:find(k.b_str) then res[k.a_idx].a_in_b=true end
--                            if k.b_str:find(k.a_str) then res[k.a_idx].b_in_a=true end
--                        end
--                    end
            end

            if #iter_params>=n+1 then
                coroutine.yield( u.iter_rules(u,res,iter_params, n+1) )
            else
                if run_params.do_update or run_params.update_conditions then
                    for _,v in ipairs(res) do
                        u.update_query(v,run_params)
                    end
                else
                    coroutine.yield( res )
                end
            end
        end

    end


    
    u.update_query = update_query
    u.iter_rules = iter_rules
    iter_rules(u,{},_L.params,1)

--    return "done"
    
end

return u