--
-- User: sethc23
-- Date: 9/16/15
-- Time: 10:05 PM
--
--module("string_matching", package.seeall)
package.loaded.string_matching = nil
package.loaded.utility = nil

local util = require "utility"
to_log = util.to_log
-- _debug = util.debug
round = util.round
cjson_encode = util.cjson_encode --only produces output when verbose=true
cj = require "cjson"

local u = {}

function u.jaro_score(s1,s2,winklerize,long_tolerance,verbose)
    local log_to_file           =   false
    -- _debug(                         {msg={"NEW JARO SCORE\\n\\n"},verbose=verbose,to_file=log_to_file})

    --if #s1==0 or #s2==0 then
    --    _debug(                     {msg={"s1 or s2 has no length!"},verbose=verbose,to_file=log_to_file})
    --end

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

    function get_div_tbl_from_str (t)
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

    function split_str_with_div (str,div)

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

    function split_str_with_div_tbl (str,div_tbl)

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

--    package.loaded.mobdebug = nil
--    require('mobdebug').start("10.0.1.53")

--    assert(type(t)~="table",[[
--        Expected table as first argument, e.g.,
--            ( div_str, { jaro_score vars } )
--        Use ';;' for ';' splitter.
--        Default is ' ;_;/;\;|;&'
--    ]])

    local div_str
    div_str = t.with_permutations

    if type(div_str)~="string" or div_str=="" then
        div_str = " ;-;_;/;\\;|;&;;"
    end

    local div_tbl = get_div_tbl_from_str(div_str)
    local a_str_normalized = split_str_with_div_tbl( t.s1, div_tbl )
    local a_norm = table.concat(a_str_normalized," ")
    local split_str_to_tbl = split_str_with_div_tbl( t.s2, div_tbl )


    local perm_str
    local j_score,new_j_score = 0
    for k in t.p.perm( split_str_to_tbl ) do

        perm_str = table.concat(k," ")
        --t.prof.start()
        new_j_score = t.jaro_score(a_norm, perm_str, false, false, false)
        --t.prof.stop()
        if new_j_score and new_j_score>j_score then 
            j_score=new_j_score 
        end

    end

    return j_score

end

function u.iter_jaro(qry_a,qry_b,with_permutations)

    --package.loaded.mobdebug = nil
    --require('mobdebug').start("10.0.1.53")

    local process_b_rows = function (_L)
        local new_j_score
        local cnt = 0
        for b_row in _L.qry_b:rows{_L.b_q_offset,_L.b_q_lim} do
            _L.i2,_L.s2 = b_row.b_idx,b_row.b_str
            if _L.i2=="281" or _L.i2=="1139" or _L.i2=="1140" or _L.i2=="1141" or _L.i2=="1771" or _L.i2=="1772" or _L.i2=="1833" then
               local a = 0
            end
            if _L.with_permutations==false then
                new_j_score = _L.jaro_score(_L.s1, _L.s2, false, false, false)
            else
                --_L.prof.start()
                new_j_score = _L.perm_jaro( _L )
                --_L.prof.stop()
            end


            if new_j_score and new_j_score>0 then
                if new_j_score>_L.j_score then
                    _L.j_score = new_j_score
                    _L.res_i2,_L.res_s2 = _L.i2,_L.s2
                    _L.other_matches = {}
                elseif new_j_score==_L.j_score then
                    table.insert(_L.other_matches,b_row.b_idx)
                end
            end
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
            coroutine.yield{ a_idx=_L.i1, a_str=_L.s1, jaro_score=tostring(_L.j_score), b_str=_L.res_s2, b_idx=_L.res_i2, other_matches=cj.encode(_L.other_matches) }
        end
        if cnt==_L.a_q_lim then
            _L.a_q_offset = _L.a_q_offset + _L.a_q_lim
            _L.results = _L.process_a_rows(_L)
        end

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
    if with_permutations==false 
        or tostring(with_permutations):lower()=="false" then
        _L.with_permutations = false
    else
        _L.p = require"permutations"
        _L.with_permutations = with_permutations
    end
    _L.qry_max = max_qry_result_cnt
    
    

    --os.execute("echo '\\n\\n\\nSTARTING - '`date --utc` >> /tmp/tmpfile")
    
    _L = query_prep(_L)
    _L.prof=require"profiler"
    
    --_L.prof.start()
    _L.process_a_rows,_L.process_b_rows = process_a_rows,process_b_rows
    --_L.prof.stop()
    
    --ProFi = require 'ProFi'
		--ProFi:start()
    
    process_a_rows(_L)
    
    --ProFi:stop()
		--ProFi:writeReport( 'process_a_rows_report.txt' )
    

end

return u