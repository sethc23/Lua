--
-- User: admin
-- Date: 10/19/15
-- Time: 3:42 AM
--
module("fs_websockets", package.seeall)

--package.loaded.mobdebug = nil
--require('mobdebug').start("10.0.1.1")
--[[

psql_server (PSQ)
file_server (FS)

- PSQ receives gmail update
1. [fs_update_es (gmail) ]                    - PSQ sends json from gmail contents  [ for elasticsearch ? ] 
2. [fs_update_file_idx_on_gmail_update]
(1.) [fs_update_es (file_idx) ]                 - PSQ sends json from file_idx._info  [ for pypdfOCR ? ]
3. [fs_process_files_in_file_idx ( 1st )]  - PSQ sends file from file_idx
... some info updated
-..- PSQ sends json from file_idx._info  [ for pypdfOCR ? ] -- AFTER LAST-UPDATED COLUMN UPDATE
- FS sends OCRed file
- PSQ updates pgsql


TWO PRIMARY PROCESSES:

    1. receiving email, attachments are inspected, and 
        as much data extracted as possible, 
        which includes OCR
            --> ORIGINAL/OCR files communicated b/t PSQ/FS

    2. database storing gmail emails and extracted content
        needs to be accessible and easily searchable
            --> JSON packets sent from PSQ to SE,
                    which is content indexing tool (elasticsearch)
                    coupled with a web search interface (Kibana)



]]--

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

    os.execute("echo '"..uri.."' >> /tmp/pgsql;")

    -- Make Connect and Error Check:
    local ok, err = wb:connect(uri)
    if not ok then
        ngx.say("failed to connect: " .. err)
        os.execute("echo 'failed to connect' >> /tmp/pgsql;")
        return
    end
    local data, typ, err = wb:recv_frame()
    if not data then
        ngx.say("failed to receive 1st frame: ", err)
        os.execute("echo 'failed to receive 1st frame' >> /tmp/pgsql;")
        return
    end

    local url_args = ngx.req.get_uri_args() -- uuid,filename,filepath
    local cj = require "cjson"

    os.execute("echo '45' >> /tmp/pgsql;")

    local bytes, err = wb:send_text(cj.encode(url_args))
    if not bytes then
        ngx.say("failed to initialize transfer: ", err)
        return
    end
    data, typ, err = wb:recv_frame()
    if not data then
        ngx.say("failed to confirm initialization: ", err, " (",data, ")")
        os.execute("echo 'failed to confirm initialization' >> /tmp/pgsql;")
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
            os.execute("echo 'failed to send byte block' >> /tmp/pgsql;")
            return
        end

        data, typ, err = wb:recv_frame()
        if not data then
            ngx.say("failed to confirm byte block: ", err, " (",data, ")")
            os.execute("echo 'failed to confirm byte block' >> /tmp/pgsql;")
            return
        end

    end
    assert(f:close())

    local bytes, err = wb:send_text(url_args.uuid)
    if not bytes then
        ngx.say("failed to terminate transfer: ", err)
        os.execute("echo 'failed to terminate transfer' >> /tmp/pgsql;")
        return
    end
    data, typ, err = wb:recv_frame()
    if not data then
        ngx.say("failed to confirm termination: ", err, " (",data, ")")
        os.execute("echo 'failed to confirm termination' >> /tmp/pgsql;")
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
    --local pl = require'pl.import_into'()
    --local tbl_u = require "tbl_utils"
    local wb, err = client:new{
        timeout = 10000,                            -- in milliseconds
        max_payload_len = 1048576,
    }

    local uri = "ws://50.176.131.26:12501/json"

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
    --local pl                = require'pl.import_into'()

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
    --ngx.log(ngx.ERR, "data received.  file created: "..tmp_file)


    local f = io.open(tmp_file,'r')
    local _json = f:read("*a")
    f:close()

    return tmp_file,_j,_json
end

function u.check_query()
    -- ngx.log(ngx.WARN,"\n\n\t\t>> {websockets_rewrite_by_lua} : STARTING >>\n\n"      .."STARTING"..    "\n\n<<")
    
    -- local raw_header = ngx.req.raw_header()
    -- ngx.log(ngx.WARN,"\n\n\t\t>> {websockets_rewrite_by_lua} : raw_header >>\n\n"      ..raw_header..    "\n\n<<")
    -- ngx.log(ngx.WARN,"\n\n\t\t>> {websockets_rewrite_by_lua} : ngx.var.uri >>\n\n"      ..ngx.var.uri..    "\n\n<<")
    -- ngx.log(ngx.WARN,"\n\n\t\t>> {websockets_rewrite_by_lua} : ngx.var.request_uri >>\n\n"      ..ngx.var.request_uri..    "\n\n<<")
    -- ngx.log(ngx.WARN,"\n\n\t\t>> {websockets_rewrite_by_lua} : ngx.var.args >>\n\n"      ..ngx.var.args..    "\n\n<<")

    local qry                               =   ""
    local req_method                        =   ngx.var.request_method
    -- ngx.log(ngx.WARN,"\n\n\t\t>> {websockets_rewrite_by_lua} : req_method >>\n\n"      ..req_method..    "\n\n<<")
    
    if req_method=="GET" then
        qry                                 =   ngx.var.arg_qry
        if not qry or qry=="" then
            qry                             =   ngx.var.args
            local cj                        =   require"cjson"
            local t                         =   cj.decode(qry)
            qry                             =   t.qry
        end
    elseif req_method=="POST" then
        local cj                            =   require"cjson"
        ngx.req.read_body()
        local post_args                     =   ngx.req.get_body_data() --returns string
        local t                             =   cj.decode(post_args)
        qry                                 =   t.qry
    else
        ngx.exit(ngx.HTTP_METHOD_NOT_IMPLEMENTED)
    end
    -- ngx.log(ngx.WARN,"\n\n\t\t>> {websockets_rewrite_by_lua} : qry >>\n\n"      ..tostring(qry)..    "\n\n<<")
    ngx.var.qry                             =   qry
end


function u.update_pgsql(res)
    os.execute("echo \'fs_websockets.update_pgsql\' >> /tmp/pgsql;")
    -- local qry = ""
    -- qry = "INSERT INTO file_content(src_db,src_uid,plain_text,html_text,pg_num)"
    -- qry = qry..[[  UPDATE file_idx SET _run_ocr = 'false' WHERE _key =]].."'"..res.uuid:sub(1,#res.uuid-4).."'"
    -- make_query(qry)
    
    -- os.execute("echo \'"..resp.status.."\' >> /tmp/pgsql;")
    -- os.execute("echo \'"..resp.body.."\' >> /tmp/pgsql;")

    -- res.uuid:sub(1,#res.uuid-4)

    qry = "UPDATE file_idx SET _run_ocr = 'false' WHERE _key ='"..res.uuid.."'"
    qry = qry.." RETURNING uid;"
    qry = '/query?qry='..qry
    local resp                  =   ngx.location.capture(qry)
    if resp.status~=200 then
        ngx.log(ngx.WARN,"-- {fs_websockets.lua}/ : pgsql_args :>>"      ..qry..                        "<<  ")
        ngx.log(ngx.WARN,"-- {fs_websockets.lua}/ : resp :>>"            ..tostring(resp.status)..   "<<  ")
    end
    
    -- os.execute("echo \'"..resp.status.."\' >> /tmp/pgsql;")
    -- os.execute("echo \'"..resp.body.."\' >> /tmp/pgsql;")

    return resp.body:match("%d+")
end

function u.queue_ocr_to_pgsql(file_idx_uid,res,base_dir,attachments_dir)
    os.execute("echo \'fs_websockets.queue_ocr_to_pgsql -- START\' >> /tmp/pgsql;")
    os.execute("echo \'file_idx_uid -- "..file_idx_uid.."\' >> /tmp/pgsql;")
    os.execute("echo \'file_idx_uid -- "..res.uuid.."\' >> /tmp/pgsql;")
    os.execute("echo \'file_idx_uid -- "..res.filename.."\' >> /tmp/pgsql;")
    
    -- res = "uuid",filename,filepath
    -- base_dir = "/home/ub2/SERVER2/file_server"
    -- attachments_dir = "/home/ub2/ARCHIVE/gmail_attachments"
    
    local cmd = "echo 'su ub2 -c \" "
    local cmd = cmd..base_dir.."/fs_ocr_to_pgsql "
    local cmd = cmd.."\'"..file_idx_uid.."\' "
    local cmd = cmd.."\'"..res.filename.."\' "
    local cmd = cmd.."\'"..attachments_dir.."\' "
    local cmd = cmd.." >> /tmp/pgsql3 2>&1 "
    local cmd = cmd.."\"' | at NOW + 1 minute > /tmp/pgsql2 2>&1"   
    
    os.execute(cmd)

end

return u