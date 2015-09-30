--
-- User: admin
-- Date: 9/21/15
-- Time: 3:52 PM
--
-- Fri Sep 25 04:53:06 UTC 2015
-- Splitting with splitter		2680.300 nsec/call
-- Splitting with splitter_iter	4489.790 nsec/call
--

local u = {}

function u.split_gen2 (_str, div_chars)
    local first,last = _str:find(div_chars,1,true)
    if not first or not last then
        coroutine.yield(_str)
    else
        local res
        if first==1 and _str:sub(last+1,last+1+#div_chars)==div_chars then
            res = div_chars
            coroutine.yield(res)
            last = 2 * #div_chars
        else
            res = _str:sub(1,first-1)
            coroutine.yield(res)
        end
        if last<#_str then
            u.split_gen( _str:sub(last+1), div_chars )
        end
    end
end

function u.split_gen (_str, div_chars)
    local n = _str:find(div_chars,1,true)
    if not n then
        coroutine.yield(_str)
    else
        coroutine.yield(_str:sub(1,n-1))
        u.split_gen( _str:sub(n+1), div_chars )
    end
end

function u.splitter_iter (_str, div_chars)
    return coroutine.wrap(function () u.split_gen(_str, div_chars) end)
end

function u.splitter (_str,div)
    local str_parts = {}
    local i = 1
    while true do
        local next_match = _str:find(div,i,true)
        if not next_match then
            if not str_parts then
                if _str and _str~="" then
                    table.insert(str_parts,1+#str_parts,_str)
                end
            else
                local t = _str:sub(i)
                if t and t~="" then
                    table.insert(str_parts,1+#str_parts,t)
                end
            end
            break
        else
            local t = _str:sub(i,next_match-1)
            if t and t~="" then
                table.insert(str_parts,1+#str_parts,t)
            end
            i = next_match + #div
        end
        if i>=#_str then break end
    end
    return str_parts
end

--function u.test_method()
--
--    --tests splitter_iter
--
--    _tbl = require"tbl_utils"
--
--    local err_catch = function (args)
--
--        if args.verbose then
--            print("\tArgs: ".._tbl.tostring(args))
--        end
--        local t = {}
--        for k in u.splitter_iter(args._str,args.div_str) do
--            table.insert(t,1+#t,k)
--        end
--        assert(#args.expect==#t,"Returned Result has Unexpected Length")
--        for i in pairs(args.expect) do
--            local msg = args.expect[i].." ~= "..t[i]
--            if args.verbose then print(msg) end
--            assert(args.expect[i]==t[i],"Returned Result["..i.."] Unexpected: "..msg)
--        end
--        print("\tPASS\n")
--    end
--
--    local run_test = function (title,args)
--        print("New Test:\t"..title)
--        args.verbose=false
--        err_catch(args)
--    end
--
--    run_test([[general test]],{
--        _str=" ;-;_;/;\\;|;&;",
--        div_str=";",
--        expect={" ","-","_","/","\\","|","&"}
--        })
--    run_test([[testing inclusion of double div_str]],{
--        _str=" ;-;_;/;\\;|;&;;;",
--        div_str=";",
--        expect={" ","-","_","/","\\","|","&",";"}
--        })
--    run_test([[testing when no div_str]],{
--        _str="abd_cvkcv_wlepl",
--        div_str=";",
--        expect={"abd_cvkcv_wlepl"}
--        })
--    run_test([[testing when #div_str>1]],{
--        _str=" <;>-<;>_<;>/<;>\\<;>|<;>&<;><;><;>",
--        div_str="<;>",
--        expect={" ","-","_","/","\\","|","&","<;>"}
--        })
--
--end
--
--function u.test_time()
--
--    local timeit = require"timeit"
--    local _str = " ;-;_;/;\\;|;&;;;"
--    local div_str = ";"
--
--    print("Splitting with splitter\t", timeit(function ()
--        local t = u.splitter(_str,div_str)
--    end))
--
--    print("Splitting with splitter_iter", timeit(function ()
--        for k in u.splitter_iter(_str,div_str) do end
--    end))
--
--end

return u

