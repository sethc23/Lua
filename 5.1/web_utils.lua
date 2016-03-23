
module("web_utils", package.seeall)

local u = {}
local cj = require "cjson"

function u.get_url_args(ngx)
    local r                     =   {}
    local args                  =   ngx.req.get_uri_args()
    for k, v in pairs(args) do
        r[key]                  =   val
    end
    return r
end

function u.post_args_to_string(ngx)

    ngx.req.read_body()
    --local post_args             = ngx.req.get_post_args() --returns table
    local post_args             = ngx.req.get_body_data() --returns string
    
    return post_args
    
end



return u