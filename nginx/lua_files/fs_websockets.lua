--
-- User: admin
-- Date: 10/19/15
-- Time: 3:42 AM
--
module("fs_websockets", package.seeall)

local u = {}

function u.send_file(ip_addr)

    local client = require "resty.websocket.client"
    local wb, err = client:new{
        timeout = 10000,                            -- in milliseconds
        max_payload_len = 1048576,
    }
    local uri = "ws://"..ip_addr.."/receive"

    --ngx.say("uri: ", uri)

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

    --ngx.say("1: received: ", data, " (", typ, ")")

    -- Define/Communicate uuid for signaling transfer conclusion
    --local uuid          =   require "uuid"
    --uuid.new("time")

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

    return ngx.exit(ngx.HTTP_OK)

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

    local f = cjson.decode(data) -- uuid,filename,filepath

    -- Received all binary chunks and append to file
    local file_in_name = save_path.."/"..f.uuid..".pdf"
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

return u