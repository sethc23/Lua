
module("fs_tmp", package.seeall)

--require('mobdebug').start("10.0.0.53")

-- a=0

-- a='{"ocr": {"original_move_folder": "originals", "watch": {"scan_interval": 3}, "inbox_dir": "inbox", "server_host": "ocr_server.sanspaper.com", "target_folder": "docs", "server_port": 12501, "preprocess": {"threads": 8}, "tesseract": {"threads": 8}, "default_folder": "outbox", "base_dir": "/home/ub2/SERVER1/file_server"}, "email": {"username": "seth.t.chase@gmail.com", "pw": "nowhwbczcxhvqvbx", "service": "gmail", "attachments_dir": "/home/ub2/.gmail/attachments/"}, "indexer": {"server_host": "50.176.131.26", "server_port": 12501}, "database": {"project_sql_files": "pgsql/sql_files", "service": "postgresql", "DB_PORT": 8800, "server_host": "65.96.175.247", "DB_NAME": "system", "DB_HOST": "localhost", "server_port": 12501, "DB_USER": "postgres", "base_dir": "/home/ub2/SERVER2/file_server", "base_sql_files": "pgsql/pgsql_base/sql_files", "DB_PW": ""}}'

-- cj=require"cjson"
-- local res = cj.decode(a)

-- local D = {}
-- for k,v in pairs(res) do
--     print(k.." = "..v)
-- end

-- echo "{\"qry\":\"SELECT _json res FROM __config__\"}" | curl -s -d @- --get http://localhost:12501/query


function parse_tbl (_tbl, _key, _tag)
    if _key then
        local _val = _tbl[_key]
        if _tag then _key=_tag..":".._key end
        if type(_val)=="table" then
            parse_tbl(_val,nil,_key)
        else
            local t={}
            t[_key]=_val
            coroutine.yield(t)
        end
    else
        for _k,_v in pairs(_tbl) do
            if type(_v)=="table" then 
                parse_tbl (_tbl, _k, _tag)
            else
                if _tag then _k=_tag..":".._k end
                local t={}
                t[_k]=_v
                coroutine.yield(t)
            end
        end
    end
    
    -- if _tbl==nil or not _tbl then pass = "" end
    
    -- local _val = _tbl[_key]
    -- if not _val and not _key then 
    --     pass = ""
    -- elseif type(_val)=="table" then
    --     if _tag then _key=_tag..":".._key else _tag=_key end
    --     parse_tbl(_val,nil,_tag)
    -- else
    --     local t={}
    --     if _tag then _key=_tag..":".._key end
    --     -- print(_key)
    --     t[_key]=_val
    --     coroutine.yield(t)
    -- end
end

function parse_iter (_tbl)
    return coroutine.wrap(function () parse_tbl(_tbl) end)
end

res=[[{"ocr": {"watch": {"scan_interval": 3}, "base_dir": "\/home\/ub2\/SERVER1\/file_server", "inbox_dir": "inbox", "tesseract": {"threads": 8}, "preprocess": {"threads": 8}, "server_host": "ocr_server.sanspaper.com", "server_port": 12501, "target_folder": "docs", "default_folder": "outbox", "original_move_folder": "originals"}, "email": {"pw": "nowhwbczcxhvqvbx", "service": "gmail", "username": "seth.t.chase@gmail.com", "attachments_dir": "\/home\/ub2\/.gmail\/attachments\/"}, "indexer": {"server_host": "50.176.131.26", "server_port": 12501}, "database": {"DB_PW": "", "DB_HOST": "localhost", "DB_NAME": "system", "DB_PORT": 8800, "DB_USER": "postgres", "service": "postgresql", "base_dir": "\/home\/ub2\/SERVER2\/file_server", "server_host": "65.96.175.247", "server_port": 12501, "base_sql_files": "pgsql\/pgsql_base\/sql_files", "project_sql_files": "pgsql\/sql_files"}}]]

local cj=require"cjson"
res = cj.decode(res)

local t = {}
-- for k,v in pairs(res) do
for _k in parse_iter(res) do
    print(cj.encode(_k))
    -- table.insert(t,1+#t,_k)
end
-- end