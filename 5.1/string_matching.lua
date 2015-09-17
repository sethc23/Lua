--
-- User: sethc23
-- Date: 9/16/15
-- Time: 10:05 PM
--

local _res = {}

function round(n)
    return math.floor((math.floor(n*2) + 1)/2)
end

function cjson_encode(tbl, verbose)
    local res
    if verbose then
        local cjson         =   require "cjson"
        res                 =   cjson.encode(tbl)
    else
        res                 =   " "
    end
    return res
end

function to_log(msg, verbose)
    if verbose then             
        local t = ""
        for i,v in ipairs(msg) do
            if v then t = t..v end
        end
        log(t) 
    end
end

function _res.jaro_score(s1,s2,winklerize,long_tolerance,verbose)
    to_log(                         {"NEW EXECUTION\\n\\n"}, verbose)

    if #s1==0 or #s2==0 then
        log(                        "s1 or s2 has no length!")
    end

    -- set #a>#b
    local a,b,m                 =   "","",0
    if #s1<#s2 then     b,a     =   s1,s2
    else                a,b     =   s1,s2   end
    a,b                         =   a:upper(),b:upper()
    to_log(                         {"a: ",a}, verbose)

    -- define max distance where character will be considered matching (despite tranposition)
    local match_dist            =   round( (#a/2) - 1 )
    if match_dist<0 then            match_dist=0 end
    to_log(                         {"match_dist=",match_dist}, verbose)

    -- create letter and flags tables
    local a_tbl,b_tbl           =   {},{}
    local a_flags,b_flags       =   {},{}
    for i=1,#a do
        table.insert(               a_tbl,a:sub(i,i))
        table.insert(               a_flags,false)

        table.insert(               b_tbl,b:sub(i,i))
        table.insert(               b_flags,dfalse)
    end
    for i=#a+1, #b do
        table.insert(               b_tbl,b:sub(i,i))
        table.insert(               b_flags,false)
    end
    to_log(                         {"a_tbl ",cjson_encode(a_tbl)}, verbose)
    to_log(                         {"b_tbl ",cjson_encode(b_tbl)}, verbose)
    to_log(                         {"b_tbl[3] ",b_tbl[3]}, verbose)

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
        to_log(                     {"cursor_1=",cursor}, verbose)

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

        to_log(                     {"low_hi ",low," ",hi}, verbose)

        for _j=low+1, hi+1 do
            j                   =   _j-1

            to_log(                 {"ij ",i," ",j}, verbose)
            to_log(                 {"cursor ",cursor}, verbose)
            to_log(                 {{"b_tbl[j+1] "},b_tbl[j+1]}, verbose)

            if not b_flags[j+1] and b_tbl[j+1]==cursor then
                to_log(             {"BREAK_HERE"}, verbose)
                a_flags[i+1]    =   true
                b_flags[j+1]    =   true
                common          =   common+1
                break
            end
        end
    end
    to_log(                         {"a_flags=",cjson_encode(a_flags)}, verbose)
    to_log(                         {"b_flags=",cjson_encode(b_flags)}, verbose)

    -- return nil if no exact or transpositional matches
    if common==0 then               return nil end
    to_log(                         {"common = ",common}, verbose)

    -- count transpositions
    local first,k,trans_count   =   true,1,0
    local _j
    for _i,v in ipairs(a_tbl) do
        i                       =   _i - 1

        if a_flags[i+1] then

            for j=k, #b do
                _j              =   j - 1

                to_log(            {"i},j,_j= ",i,",",j,",",_j}, verbose)
                to_log(            {"b_flags[j]= ",cjson_encode({b_flags[j]})}, verbose)

                if b_flags[j] then
                    k           =   j+1
                    break
                end
            end

            to_log(                 {"k= ",k}, verbose)
            to_log(                 {"a_tbl[i+1]= ",a_tbl[i+1]}, verbose)

            if not j and first then
                _j,first        =   1,false
            else
                _j              =   _j + 1
            end

            to_log(                 {"b_tbl[_j]= ",b_tbl[_j]}, verbose)
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
    to_log(                         {"trans_count = ",trans_count}, verbose)

    -- adjust for similarities in nonmatched characters
    local weight                =   0
    weight                      =   ( ( common/#a + common/#b +
                                        (common-trans_count)/common ) )/3
    to_log(                         {"weight = ",weight}, verbose)

    -- winkler modification: continue to boost if strings are similar
    local i,_i,j                =   0,0,0
    if winklerize and weight>0.7 and #a>3 and #b>3 then

        -- adjust for up to first 4 chars in common

        if #a<4 then                j = #a
        else                        j = 4 end
        to_log(                     {"i},j_1= ",i,",",j}, verbose)

        for _i=1, j-1 do
            if _i==1 then           i = _i-1 end
            if a_tbl[_i]==b_tbl[_i] and #b>=_i then
                if not i then       i = 1
                else                i = i+1 end
                to_log(             {"i},_i,j_2= ",i,",",_i,",",j}, verbose)
            end
            if i>j then             break end
        end
        to_log(                     {"i},_i,j_3= ",i,",",_i,",",j}, verbose)

        if i-1>0 then
            i = i-1
            weight              =   weight + ( i * 0.1 * (1.0 - weight) )
        end
        to_log(                     {"new weight_1 = ",weight}, verbose)

        -- optionally adjust for long strings
        -- after agreeing beginning chars, at least two or more must agree and
        -- agreed characters must be > half of remaining characters
        if ( long_tolerance and
             #a>4 and
             common>i+1 and
             2*common>=#a+i ) then
            weight              =   weight + ((1.0 - weight) * ( (common-i-1) / (#a+#b-i*2+2)))
        end

        to_log(                     {"new weight_2 = ",weight}, verbose)

    end

    return weight

end


function _res.iter_jaro(qry)


    --end
    --do
--    package.loaded.string_matching = nil
--    package.loaded.cjson = nil
--    package.loaded.tbl_utils = nil

    local m_str = require "string_matching"
    local cj = require "cjson"
    local tbl = require "tbl_utils"
    --
    _U = {}
    --    z_string_matching = coroutine.wrap( z_string_matching )


    function update_jaro_score(row,res_tbl)
        local s1, s2, a_idx, b_idx, j_score
        s1,s2 = row.a_str, row.b_str
        a_idx,b_idx = row.a_idx, row.b_idx
        j_score = m_str.jaro_score(s1, s2, false, false, false)

        --os.execute("echo 'a_idx: "..a_idx.."' >> /tmp/tmpfile")

        if not res_tbl[a_idx] or j_score>=res_tbl[a_idx].jaro_score then

            if res_tbl[a_idx] and j_score==res_tbl[a_idx].jaro_score then
                res_tbl[a_idx].other_matches = cj.encode({res_tbl[a_idx].other_matches,b_idx})

            else
                if not res_tbl[a_idx] then res_tbl[a_idx] = {} end
                res_tbl[a_idx].a_idx = a_idx
                res_tbl[a_idx].a_str = s1
                res_tbl[a_idx].jaro_score = j_score
                res_tbl[a_idx].other_matches = {}
                res_tbl[a_idx].b_str = s2
                res_tbl[a_idx].b_idx = b_idx
            end

        end

        return res_tbl
    end

    function process_rows()
        os.execute("echo 'processing' >> /tmp/tmpfile")
        local cnt = 0
        for r in _U.qry:rows{qry,_U.offset,_U.limit} do
            _U.results = update_jaro_score(r,_U.results)

            os.execute("echo '_U.results: "..tbl.tostring( _U.results ).."' >> /tmp/tmpfile")
            --os.execute("echo '_U: "..table.tostring( _U ).."' >> /tmp/tmpfile")
            --if true then return _U.results end

            cnt = cnt + 1
        end

        _U.offset = _U.offset + _U.limit

        if cnt==_U.limit then
            _U.offset = _U.offset + _U.limit
            _U.results = process_rows()
        else
            return _U.results
        end
    end

    if not _U.qry then
        --os.execute("echo 'TEST' >> /tmp/tmpfile")
        local _qry = [[  select pllua_f1.* from ( ]]..qry..[[ ) pllua_f1
                         order by pllua_f1.a_idx asc,pllua_f1.b_idx asc
                         OFFSET $2 LIMIT $3; ]]
        --os.execute("echo '".._qry.."' >> /tmp/tmpfile")
        _U.qry = server.prepare(_qry, {"text","int4","int4"}):save()
        _U.offset,_U.limit = 0,1000
        _U.results = {}
    end


    _U.results = process_rows(qry)

    os.execute("echo '\\n\\nFINAL RESULT: "..tbl.tostring(_U.results).."\\n\\n' >> /tmp/tmpfile")

    for _,v in pairs(_U.results) do
        os.execute("echo 'v.a_idx : \""..v.a_idx.."\"' >> /tmp/tmpfile")
        os.execute("echo 'v.a_str : \""..v.a_str.."\"' >> /tmp/tmpfile")
        os.execute("echo 'v.jaro_score : \""..v.jaro_score.."\"' >> /tmp/tmpfile")
        os.execute("echo 'v.b_str : \""..v.b_str.."\"' >> /tmp/tmpfile")
        os.execute("echo 'v.b_idx : \""..v.b_idx.."\"' >> /tmp/tmpfile")
        os.execute("echo 'v.other_matches : \""..cj.encode(v.other_matches).."\"' >> /tmp/tmpfile")
        coroutine.yield{ a_idx=tostring(v.a_idx), a_str=v.a_str, jaro_score=tostring(v.jaro_score), b_str=v.b_str, b_idx=tostring(v.b_idx), other_matches=cj.encode(v.other_matches) }
        --coroutine.yield( v.a_idx, v.a_str, v.jaro_score, v.b_str, v.b_idx, cj.encode(v.other_matches) )
    end


    --for _,v in ipairs(_U.results) do
    --z=cj.encode(v)
    --v=z
    --os.execute("echo 'v.a_idx : "..v.a_idx.."' >> /tmp/tmpfile")
    --local t = {a_idx=v.a_idx,a_str=v.a_str,jaro_score=v.jaro_score,
    --                    b_str=v.b_str,b_idx=v.b_idx,other_matches=v.other_matches}
       --os.execute("echo 't : "..cj.encode(t).."' >> /tmp/tmpfile")
       --os.execute("echo 't.a_str : "..t.a_str.."' >> /tmp/tmpfile")
       --os.execute("echo 'v : "..cj.encode(v).."' >> /tmp/tmpfile")
       --os.execute("echo 'v.a_str : "..v.a_str.."' >> /tmp/tmpfile")
    --    coroutine.yield{a_idx=v.a_idx, a_str=v.a_str, jaro_score=v.jaro_score, b_str=v.b_str, b_idx=v.b_idx, other_matches=v.other_matches}
    --end


    --local res = ""
    --res = cj.encode(table.tostring( _U.results ))

    --os.execute("echo 'DONE' >> /tmp/tmpfile")
    --os.execute("echo 'showing all: "..res.."' >> /tmp/tmpfile")
    --local t = {}
    --local x = {}
    --res = _U.results
    function send_results(res)
        os.execute("echo '_U.results: "..table.tostring(_U.results).."' >> /tmp/tmpfile")
        local res_order = {"a_idx","a_str","jaro_score","b_str","b_idx","other_matches"}
        for k,v in pairs(res) do
            os.execute("echo '\\nres[k]: "..cj.encode(res[k]).."' >> /tmp/tmpfile")
            --os.execute("echo '\\nv: "..cj.encode(v).."' >> /tmp/tmpfile")
            if res[k] then

                for _,_v in ipairs(res_order) do
                    os.execute("echo '\\nv[_v]: "..cj.encode(v[_v]).."' >> /tmp/tmpfile")
                    t[_v]=v[_v]
                    os.execute("echo '\\nx1: "..table.tostring(x).."' >> /tmp/tmpfile")
                    x = table.insert(x,tostring(v[_v]))
                    os.execute("echo '\\nx2: "..table.tostring(x).."' >> /tmp/tmpfile")
                end

                os.execute("echo '\\nreturning: "..x.."' >> /tmp/tmpfile")
                --coroutine.yield(x)
                --coroutine.yield(t)
                --os.execute("echo 'STILL GOING' >> /tmp/tmpfile")
            end
        end
    end

    --send_results(res)

    --return _U.results

    --local tmp = {}
    --tmp["a_idx"] = _U.results[1527].a_idx
    --tmp["a_str"] = _U.results[1527].a_str
    --tmp["jaro_score"] = _U.results[1527].jaro_score
    --tmp["b_str"] = _U.results[1527].b_str
    --tmp["b_idx"] = _U.results[1527].b_idx

    --tmp["other_matches"] = _U.results[1527].other_matches
    --

    --coroutine.yield(cj.encode(tmp))

end

return _res