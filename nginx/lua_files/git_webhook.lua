
module("git_webhook", package.seeall)

function os_capture(cmd, raw)
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    if raw then return s end
    s = string.gsub(s, '^%s+', '')
    s = string.gsub(s, '%s+$', '')
    s = string.gsub(s, '[\n\r]+', ' ')
    return s
end


ngx.req.read_body()
local post_args = ngx.req.get_body_data()

-- os.execute("echo '"..post_args.."' > /tmp/lua")
-- m=require('mobdebug').start("10.0.0.53")

local json = [[{"commit":.after,"ref":.ref,"ssh_url":.repository.ssh_url,"https_url":.repository.clone_url}]]
local jq_cmd = [[echo ']]..post_args.."' | jq -M -c '"..json.."'"
local info = os_capture(jq_cmd)
local uuid = require"uuid"
local tmp_save = "/tmp/" .. uuid.new("time")
os.execute([[echo ']]..info..[[' > ]]..tmp_save)
os.execute([[/home/ub2/.scripts/git/webhooks "queue" "]]..tmp_save..[["]])
