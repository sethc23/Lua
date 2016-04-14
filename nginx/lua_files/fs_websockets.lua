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

function u.send_data()
    local LOG_TAG = "fs_websockets.send_file"
    local LOGGER_BASE = "logger -i --priority info --tag "..LOG_TAG.." -- "
    local ERROR_MSG = ""
    os.execute(LOGGER_BASE.." STARTING")

    --local pl = require'pl.import_into'()
    --local tbl_u = require "tbl_utils"

    --json currently sends close rather than code asking to close...

    -- Load Data For Transmission
    local cj = require "cjson"
    local url_args = ngx.req.get_uri_args()        -- uuid,filename,filepath

    -- local share_params = {"tbl","uid","uuid","filepath"}
    -- for _,v in ipairs(share_params) do 
    --     share_params[v] = url_args[v] 
    -- end


    local service_endpt = url_args["service_dest"]
    local dest_ip = url_args[service_endpt.."_ip"]

    local uri = "ws://"..dest_ip.."/receive"
    os.execute(LOGGER_BASE.." URI: "..uri)

    local data_type                         = url_args["data_type"]:lower()
    local text_to_send_pre_transmission     = cj.encode(url_args)
    local data_to_send                      = {}
    local tmp_fpath                         = url_args.filepath
    local text_to_send_post_transmission    = url_args.uuid
    local exit                              = true
        
    -- Start Websocket
    local client = require "resty.websocket.client"
    local wb, err = client:new{
        timeout = 10000,                            -- in milliseconds
        max_payload_len = 1048576,
    }

    -- Make Connect and Error Check:
    local ok, err = wb:connect(uri)
    if not ok then
        ERROR_MSG = "failed to connect"
        ngx.say(ERROR_MSG..": ".. err)
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return
    end
    local data, typ, err = wb:recv_frame()
    os.execute(LOGGER_BASE.." data: "..data)
    if not data then
        ERROR_MSG = "failed to receive 1st frame"
        ngx.say(ERROR_MSG..": ", err)
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return
    end

    -- Send Instructions for Data
    local bytes, err = wb:send_text(text_to_send_pre_transmission)
    if not bytes then
        ERROR_MSG = "failed to initialize transfer"
        ngx.say(ERROR_MSG..": ", err)
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return
    end
    data, typ, err = wb:recv_frame()
    os.execute(LOGGER_BASE.." data: "..data)
    if not data then
        ERROR_MSG = "failed to confirm initialization"
        ngx.say(ERROR_MSG..": ", err, " (",data, ")")
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return
    end

    os.execute(LOGGER_BASE.." tmp_fpath: "..tmp_fpath)
    -- Send Data
    local f = assert(io.open(tmp_fpath, "rb"))
    local block = 4096
    while true do
        local f_bytes = f:read(block)
        if not f_bytes then break end

        local bytes, err = wb:send_binary(f_bytes)
        if not bytes then
            ERROR_MSG = "failed to send byte block"
            ngx.say(ERROR_MSG..": ", err)
            os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
            return
        end

        data, typ, err = wb:recv_frame()
        os.execute(LOGGER_BASE.." data: "..data)
        if not data then
            ERROR_MSG = "failed to confirm byte block"
            ngx.say(ERROR_MSG..": ", err, " (",data, ")")
            os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
            return
        end

    end

    -- Close Connection
    assert(f:close())
    
    if data_type=="json" then
        local bytes, err = wb:send_text(text_to_send_post_transmission)
        -- local bytes, err = wb:send_close()
    else
        local bytes, err = wb:send_text(text_to_send_post_transmission)
    end
    if not bytes then
        ERROR_MSG = "failed to terminate transfer"
        ngx.say(ERROR_MSG..": ", err)
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return
    end
    data, typ, err = wb:recv_frame()
    if not data then
        ERROR_MSG = "failed to confirm termination"
        ngx.say(ERROR_MSG..": ", err, " (",data, ")")
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return
    end

    if exit then 
        return ngx.exit(ngx.HTTP_OK)
    elseif data_type=="json" then
        return ngx.exit(ngx.HTTP_OK)
    else
        return url_args end
end

function u.receive_data()
    local LOG_TAG = "fs_websockets.receive_data"
    local LOGGER_BASE = "logger -i --priority info --tag "..LOG_TAG.." -- "
    local ERROR_MSG = ""
    os.execute(LOGGER_BASE.." STARTING")

    local cj            =   require "cjson"
    local url_args      =   ngx.req.get_uri_args()
    local h             =   ngx.req.raw_header()

    os.execute(LOGGER_BASE.." HEADERS: "..cj.encode(h))
    os.execute(LOGGER_BASE.." url_args: "..cj.encode(url_args))

    local service_endpt =   url_args["service_dest"]
    local save_path     =   ""

    if service_endpt=="pgsql" then
        exit            =   false
        save_path       =   ""
    elseif service_endpt=="es" then
        exit            =   true
        save_path       =   "/tmp"
    elseif service_endpt=="pdf_ocr" then
        exit            =   false
        save_path       =   ""
    end

    -- Make Socket or Error:
    local server            = require "resty.websocket.server"
    local wb, err           = server:new{
        timeout             = 10000,                        -- in milliseconds
        max_payload_len     = 1048576,
    }
    if not wb then
        ERROR_MSG = "failed to make new websocket"
        ngx.say(ERROR_MSG..": ".. err)
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return ngx.exit(444)
    end

    -- Make Connection or Error:
    local bytes, err        = wb:send_text("MESSAGE FROM USER ON WebSocket!")
    if not bytes then
        ERROR_MSG = "failed to send the 1st text"
        ngx.say(ERROR_MSG..": ".. err)
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return ngx.exit(444)
    end

    -- Initialize Transfer // GET FILE INFO
    local data, typ, err    = wb:recv_frame()
    if not data then
        ERROR_MSG = "failed to receive data instructions"
        ngx.say(ERROR_MSG..": ".. err)
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return ngx.exit(444)
    else
    -- Acknowledge Receipt or Error:
        bytes, err              = wb:send_text("START OK")
        if not bytes then
            ERROR_MSG = "failed to instructions confirmation"
            ngx.say(ERROR_MSG..": ".. err)
            os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
            return ngx.exit(444)
        end
    end

    os.execute(LOGGER_BASE.." data: "..data)
    local _data = cj.decode(data)

    os.execute(LOGGER_BASE.." data_type: "..data_type)
    if _data.data_type=="file" then

        -- local file_in = io.open(_data.filepath, "ab+")
        local file_in = assert(io.open(_data.filepath, "ab+"))

        while true do

            -- Receive Data or Error:
            local data, typ, err    = wb:recv_frame()

            os.execute(LOGGER_BASE.." data: "..data)

            if data==_data.uuid then break
            elseif not data then
                ERROR_MSG = "failed to receive next byte block"
                ngx.say(ERROR_MSG..": ".. err)
                os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
                return ngx.exit(444)
            else
                file_in:write(data)    
            end

            -- Acknowledge Receipt or Error:
            bytes, err              = wb:send_text("PART OK")
            if not bytes then
                ERROR_MSG = "failed to send confirmation"
                ngx.say(ERROR_MSG..": ".. err)
                os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
                return ngx.exit(444)
            end
        end
        assert(file_in:flush())
        assert(file_in:close())
        -- Acknowledge Completion or Error:
        bytes, err              = wb:send_text("END OK")
        if not bytes then
            ERROR_MSG = "failed to send the last confirmation"
            ngx.say(ERROR_MSG..": ".. err)
            os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
            return ngx.exit(444)
        end
        return f

    elseif _data.data_type=="json" then

        -- Receive & Confirm Data:
        local tmp_file = _data.filepath
        local file_in = assert(io.open(tmp_file, "wb"))

        while true do

            function confirm_data_received()
                -- Acknowledge Receipt or Error:
                bytes, err              = wb:send_text("PART OK")
                if not bytes then
                    ERROR_MSG = "failed to send confirmation"
                    ngx.say(ERROR_MSG..": ".. err)
                    os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
                    return ngx.exit(444)
                end
            end

            -- Receive Data or Error:
            local data, typ, err    = wb:recv_frame()
            os.execute(LOGGER_BASE.." data: "..data)

            if data==_data.uuid then
                confirm_data_received()
                break
            elseif not data then
                ERROR_MSG = "failed to receive next byte block"
                ngx.say(ERROR_MSG..": ".. err)
                os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
                return ngx.exit(444)
            else
                file_in:write(data)
                confirm_data_received()  
            end

        end
        assert(file_in:flush())
        assert(file_in:close())

        if _data.service_dest:lower()=="es" then
            
            local f = io.open(tmp_file,'r')
            local json = f:read("*a")
            f:close()

            os.execute(LOGGER_BASE.." tmp_file: "..tmp_file)
            os.execute(LOGGER_BASE.." _json: "..json)

            local res       =   {}
            res[0]          =   _data
            res[1]          =   tmp_file
            res[2]          =   cj
            res[3]          =   json

            local es_wb = require "fs_elasticsearch"
            es_wb.push_to_es(res)

        end

    else
        ERROR_MSG = "UNKNOWN 'data_type'"
        ngx.say(ERROR_MSG..": ".. err)
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return ngx.exit(444)
    end
end

function u.check_query()
    local LOG_TAG = "fs_websockets.check_query"
    local LOGGER_BASE = "logger -i --priority info --tag "..LOG_TAG.." -- "
    local ERROR_MSG = ""
    os.execute(LOGGER_BASE.." STARTING")
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
    local LOG_TAG = "fs_websockets.update_pgsql"
    local LOGGER_BASE = "logger -i --priority info --tag "..LOG_TAG.." -- "
    local ERROR_MSG = ""
    os.execute(LOGGER_BASE.." STARTING")

    os.execute(LOGGER_BASE.." res.uuid:sub(1,#res.uuid-4): "..res.uuid:sub(1,#res.uuid-4))
    
    local qry = ""
    qry = "UPDATE file_idx SET _run_ocr = 'false' WHERE _key ='"..res.uuid:sub(1,#res.uuid-4).."'"
    qry = qry.." RETURNING uid;"
    qry = '/query?qry='..qry

    os.execute(LOGGER_BASE.." qry: "..qry)

    local resp                  =   ngx.location.capture(qry)
    if resp.status~=200 then
        ngx.log(ngx.WARN,"-- {fs_websockets.lua}/ : pgsql_args :>>"      ..qry..                        "<<  ")
        ngx.log(ngx.WARN,"-- {fs_websockets.lua}/ : resp :>>"            ..tostring(resp.status)..   "<<  ")
    end
    
    os.execute(LOGGER_BASE.." resp.status: "..resp.status)
    os.execute(LOGGER_BASE.." resp.body: "..resp.body)
    return resp.body:match("%d+")
end

function u.queue_ocr_to_pgsql(file_idx_uid,res,base_dir,attachments_dir)
    local LOG_TAG = "fs_websockets.send_file"
    local LOGGER_BASE = "logger -i --priority info --tag "..LOG_TAG.." -- "
    local ERROR_MSG = ""
    os.execute(LOGGER_BASE.." STARTING")

    os.execute(LOGGER_BASE.." file_idx_uid: "..file_idx_uid)
    os.execute(LOGGER_BASE.." res.uuid: "..res.uuid)
    os.execute(LOGGER_BASE.." res.filename: "..res.filename)

    -- res = "uuid",filename,filepath
    -- base_dir = "/home/ub2/SERVER2/file_server"
    -- attachments_dir = "/home/ub2/ARCHIVE/gmail_attachments"
    
    local cmd = "echo 'su ub2 -c \" "
    local cmd = cmd..base_dir.."/fs_ocr_to_pgsql "
    local cmd = cmd.."\'"..file_idx_uid.."\' "
    local cmd = cmd.."\'"..res.filename.."\' "
    local cmd = cmd.."\'"..attachments_dir.."\' "
    local cmd = cmd.." >> /tmp/pgsql3 2>&1 "
    local cmd = cmd.."\"' | at NOW + 1 minute "
    local cmd = cmd.."2>&1 | logger -i --priority info --tag "..LOG_TAG.." &"
    
    os.execute(cmd)

end

return u
