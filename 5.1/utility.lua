--
-- User: admin
-- Date: 9/17/15
-- Time: 10:19 AM
--
--module("utility", package.seeall)
--package.loaded.tbl_utils = nil

local u = {}
u.tbl = require "tbl_utils"


function u.round(n)
    return math.floor((math.floor(n*2) + 1)/2)
end

function u.cjson_encode(tbl, verbose)
    local res
    if verbose then
        local cjson         =   require "cjson"
        res                 =   cjson.encode(tbl)
    else
        res                 =   " "
    end
    return res
end

function u.to_log(msg, verbose)
    if verbose then
        local t = ""
        for i,v in ipairs(msg) do
            if v then t = t..v end
        end
        log(t)
    end
end

function u.getfield (f)
      local v = _G    -- start with the table of globals
      for w in string.gfind(f, "[%w_]+") do v = v[w] end
      return v
end

function u.log_env ()
    for n in pairs(_G) do
        log(n)
    end
end

function u.debug(tbl_in)
    -- whether to send msg --> boolean: verbose
    -- where to send msg --> boolean: to_log (default); to_file
    -- outfile = "/tmp/tmpfile" (default)
    -- msg is concat
    -- first msg element is title unless "msg_title"
    
    -- skip function execution if verbose = false
    local verbose_idx = 0
    verbose_idx = u.tbl.index(tbl_in,"verbose")
    if verbose_idx then
        if not tbl_in.verbose then return end
    end

    local msg = ""
    if tbl_in.msg then
        local i,v
        for i,v in ipairs(tbl_in.msg) do
            if v then
                if type(v)=="table" then msg = msg..u.tbl.tostring(v)
                else msg = msg..v end
            end
            if i==1 and not tbl_in.msg_title then
                msg = msg..": "
            elseif tbl_in.msg_title then
                msg = tbl_in.msg_title..": "
            end
        end
    end
    if tbl_in.to_file then
        if not tbl_in.out_file then tbl_in.out_file="/tmp/tmpfile" end
        os.execute("echo '"..msg.."' >> "..tbl_in.out_file)
    else
        log(msg)
    end
end

function u.show (_var,_how)
    if _var=="globals" then
        for n in pairs(_G) do
            if _how=="log" then log(n)
            elseif _how=="print" then print(n) end
        end
    end
    if _var=="packages" then
        for k,v in pairs(package.loaded) do
            if _how=="log" then log(k)
            elseif _how=="print" then print(k) end
        end
    end
    if _var=="path" then
        if _how=="log" then log(package.path)
        elseif _how=="print" then print(package.path) end
    end
    if _var=="pwd" then
        if _how=="log" then log(os.execute("echo `pwd`"))
        elseif _how=="print" then print(os.execute("echo `pwd`"))
        end
    end
    if _var=="datetime" then
        if _how=="log" then log(os.execute("echo `date --utc`"))
        elseif _how=="print" then print(os.execute("echo `date --utc`"))
        end
    end
end



return u