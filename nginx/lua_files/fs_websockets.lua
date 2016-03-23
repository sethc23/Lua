--
-- User: admin
-- Date: 10/19/15
-- Time: 3:42 AM
--
module("fs_websockets", package.seeall)

--package.loaded.mobdebug = nil
--require('mobdebug').start("10.0.1.1")

local u = {}

function u.send_file(ip_addr)

    local url_dest,exit = "",true
    if type(ip_addr)=='string' then url_dest="/receive"
    else
        url_dest = ip_addr["url_dest"]
        ip_addr = ip_addr["ip"]
        exit = ip_addr["exit"]
    end
    local uri = "ws://"..ip_addr..url_dest

    local client = require "resty.websocket.client"
    local wb, err = client:new{
        timeout = 10000,                            -- in milliseconds
        max_payload_len = 1048576,
    }

    -- Make Connect and Error Check:
    local ok, err = wb:connect(uri)
    if not ok then
        ngx.say("failed to connect: " .. err)
        return
    end
    local data, typ, err = wb:recv_frame()
    if not data then
        ngx.say("failed to receive 1st frame: ", err)
        return
    end


    local url_args = ngx.req.get_uri_args() -- uuid,filename,filepath
    local cj = require "cjson"

    local bytes, err = wb:send_text(cj.encode(url_args))
    if not bytes then
        ngx.say("failed to initialize transfer: ", err)
        return
    end
    data, typ, err = wb:recv_frame()
    if not data then
        ngx.say("failed to confirm initialization: ", err, " (",data, ")")
        return
    end

    local f = assert(io.open(url_args.filepath, "rb"))
    local block = 4096
    while true do

        local f_bytes = f:read(block)
        if not f_bytes then break end

        local bytes, err = wb:send_binary(f_bytes)
        if not bytes then
            ngx.say("failed to send byte block: ", err)
            return
        end

        data, typ, err = wb:recv_frame()
        if not data then
            ngx.say("failed to confirm byte block: ", err, " (",data, ")")
            return
        end

    end
    assert(f:close())

    local bytes, err = wb:send_text(url_args.uuid)
    if not bytes then
        ngx.say("failed to terminate transfer: ", err)
        return
    end
    data, typ, err = wb:recv_frame()
    if not data then
        ngx.say("failed to confirm termination: ", err, " (",data, ")")
        return
    end

    if exit then return ngx.exit(ngx.HTTP_OK)
    else return url_args end

end

function u.receive_file(save_path)

    local server            = require "resty.websocket.server"
    local cjson             = require "cjson"

    -- Make Connection or Error:
    local wb, err           = server:new{
        timeout             = 10000,                        -- in milliseconds
        max_payload_len     = 1048576,
    }
    if not wb then
        ngx.log(ngx.ERR, "failed to new websocket: ", err)
        return ngx.exit(444)
    end

    -- Confirm Connection or Error:
    local bytes, err        = wb:send_text("MESSAGE FROM UB1 ON WebSocket!")
    if not bytes then
        ngx.log(ngx.ERR, "failed to send the 1st text: ", err)
        return ngx.exit(444)
    end

    -- Initialize Transfer // GET FILE INFO
    local data, typ, err    = wb:recv_frame()
    if not data then
        ngx.log(ngx.ERR, "failed to receive a frame: ", err)
        return ngx.exit(444)
    end
    -- Acknowledge Receipt or Error:
    bytes, err              = wb:send_text("START OK")
    if not bytes then
        ngx.log(ngx.ERR, "failed to send confirmation: ", err)
        return ngx.exit(444)
    end

    local f = cjson.decode(data) -- "uuid",filename,filepath

    -- Received all binary chunks and append to file
    local file_in_name = ""
    if save_path~='/tmp' then
        file_in_name = save_path.."/"..f.uuid..".pdf"
    else
        file_in_name = save_path.."/"..f.uuid
    end

    local file_in = io.open(file_in_name, "ab+")

    while true do

        -- Receive Data or Error:
        local data, typ, err    = wb:recv_frame()

        if data==f.uuid then break
        elseif not data then
            ngx.log(ngx.ERR, "failed to receive next byte block: ", err)
            return ngx.exit(444)
        end

        file_in:write(data)

        -- Acknowledge Receipt or Error:
        bytes, err              = wb:send_text("PART OK")
        if not bytes then
            ngx.log(ngx.ERR, "failed to send confirmation: ", err)
            return ngx.exit(444)
        end

    end

    file_in:flush()
    file_in:close()
    -- Acknowledge Completion or Error:
    bytes, err              = wb:send_text("END OK")
    if not bytes then
        ngx.log(ngx.ERR, "failed to send the last confirmation: ", err)
        return ngx.exit(444)
    end

    return f

end

function u.send_json()

    local client = require "resty.websocket.client"
    local cj = require"cjson"
--    local pl = require'pl.import_into'()
--    local tbl_u = require "tbl_utils"
    local wb, err = client:new{
        timeout = 10000,                            -- in milliseconds
        max_payload_len = 1048576,
    }

    local uri = "ws://10.0.1.51:12501/json"

    -- Make Connect and Error Check:
    local ok, err = wb:connect(uri)
    if not ok then
        ngx.say("failed to connect: " .. err)
        return
    end
    local data, typ, err = wb:recv_frame()
    if not data then
        ngx.say("failed to receive 1st frame: ", err)
        return
    end

    -- Load Data For Transmission
    local url_args = ngx.req.get_uri_args() -- uuid,filename,filepath
    local t = {}
    t["uid"] = url_args.uid
    local tmp_file = "",""
    for k,v in pairs(url_args) do
        t["url_path"] = k
        tmp_file = os.tmpname()
        local z = io.open(tmp_file,'w')
        z:write(v)
        z:close()
        break
    end

    -- Send Instructions for Data
    local bytes, err = wb:send_text(cj.encode(t))
    if not bytes then
        ngx.say("failed to send instructions: " .. err)
        return
    end
    local data, typ, err = wb:recv_frame()
    if not data then
        ngx.say("failed to confirm instructions 1st frame: ", err)
        return
    end

    -- Send Data
    local f = io.open(tmp_file,'r')
    local block = 4096

    while true do

        local f_bytes = f:read(block)
        if not f_bytes then break end

        local bytes, err = wb:send_binary(f_bytes)
        if not bytes then
            ngx.say("failed to send byte block: ", err)
            return
        end

        data, typ, err = wb:recv_frame()
        if not data then
            ngx.say("failed to confirm byte block: ", err, " (",data, ")")
            return
        end

    end

    -- Close Connection

    local bytes, err = wb:send_close()
    if not bytes then
        ngx.say("failed to terminate transfer: ", err)
        return
    end
    data, typ, err = wb:recv_frame()
    if not data then
        ngx.say("failed to confirm termination: ", err, " (",data, ")")
        return
    end

    return ngx.exit(ngx.HTTP_OK)
end

function u.receive_json()

    local server            = require "resty.websocket.server"
    local cj                = require "cjson"
--    local pl                = require'pl.import_into'()

    -- Make & Confirm Connection or Error:
    local wb, err           = server:new{
        timeout             = 10000,                        -- in milliseconds
        max_payload_len     = 1048576,
    }
    if not wb then
        ngx.log(ngx.ERR, "failed to new websocket: ", err)
        return ngx.exit(444)
    end
    local bytes, err        = wb:send_text("MESSAGE FROM UB1 ON WebSocket!")
    if not bytes then
        ngx.log(ngx.ERR, "failed to send the 1st text: ", err)
        return ngx.exit(444)
    end

    -- Receive & Confirm Data Instructions:
    local json_info, typ, err    = wb:recv_frame()
    if not json_info then
        ngx.log(ngx.ERR, "failed to receive data instructions: ", err)
        return ngx.exit(444)
    else
        bytes, err              = wb:send_text("PART OK")
        if not bytes then
            ngx.log(ngx.ERR, "failed to confirm instructions confirmation: ", err)
            return ngx.exit(444)
        end
    end
    local _j = cj.decode(json_info)

    -- Receive & Confirm Data:
    local tmp_file = os.tmpname()
    local f = io.open(tmp_file,'w')

    while true do

        -- Receive Data or Error:
        local data, typ, err    = wb:recv_frame()
        if not data then break end

        f:write(data)

        -- Acknowledge Receipt or Error:
        bytes, err              = wb:send_text("PART OK")
        if not bytes then
            ngx.log(ngx.ERR, "failed to send confirmation: ", err)
            return ngx.exit(444)
        end

    end

    f:close()
--    ngx.log(ngx.ERR, "data received.  file created: "..tmp_file)


    local f = io.open(tmp_file,'r')
    local _json = f:read("*a")
    f:close()

    return tmp_file,_j,_json

end

return u