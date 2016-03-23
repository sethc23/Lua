--
-- User: admin
-- Date: 10/30/15
-- Time: 7:26 PM
--

module("pg_file_server", package.seeall)

local u = {}

function u.update_es_trigger()
    local cj = require"cjson"
    require"pl"
    local df = Date.Format()

    --package.loaded.mobdebug = nil
    --require('mobdebug').start("10.0.1.1")

    local d = {}
    local _uid = ""
    for k,v in pairs(_t.relation["attributes"]) do
        d[v] = k
    end
    local _keys = {}
    local fname = os.tmpname()
    local f = io.open(fname,'w')
    for i,v in ipairs(d) do
        _keys[i] = v
        local _val = _t.row[ d[i] ]
        if k=="uid" then _uid = tostring(_t.row[k]) end
        if k=="last_updated" then
            local d_str = tostring(_t.row[k])
            local dt = df:parse(d_str)
            _val = tostring(dt.time)
        end
        f:write(_val,'\n')
    end
    local tbl_name = _t.relation["name"]
    local cmd = "echo 'GET /json?" .. tbl_name .. "=" .. cj.encode(d) ..
                  "&uid=" .. _uid .. "' | socat - tcp:0.0.0.0:12501,reuseaddr,nonblock"
    os.execute(cmd)
end

return u