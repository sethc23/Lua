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
    local fs_config = ngx.shared.fs_config
    local LOG_TAG = "fs_websockets.send_data"
    local LOGGER_BASE = "logger -i --priority info --tag "..LOG_TAG.." -- "
    local ERROR_MSG = ""
    if fs_config:get("debug") then
        os.execute(LOGGER_BASE.." STARTING")
    end

    -- Load Data For Transmission
    local cj                                =   require "cjson"
    local url_args                          =   ngx.req.get_uri_args()
    
    local _data                             =   nil
    local service_endpt                     =   url_args.service_dest
    local dest_ip                           =   url_args[service_endpt.."_ip"]
    
    if dest_ip then
        _data                               =   url_args
    else 
        local f                             =   assert(io.open('/tmp/'..url_args.uuid,'r'))
        local raw_data                      =   f:read("*a")
        assert(f:close())
        _data                               =   cj.decode(raw_data)
        dest_ip                             =   _data[service_endpt.."_ip"]
        for k,v in pairs(url_args) do
            _data[k]                        =   v
        end
    end

    local text_to_send_pre_transmission     =   cj.encode(_data)
    local file_out_path                     =   _data.filepath
    local text_to_send_post_transmission    =   _data.uuid

    local uri                               =   "ws://"..dest_ip.."/receive"
    if fs_config:get("debug") then os.execute(LOGGER_BASE.." URI: "..uri) end

    -- local data_type                         = url_args["data_type"]:lower()

    -- local exit                              = true
        
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
    if not data then
        ERROR_MSG = "failed to receive 1st frame"
        ngx.say(ERROR_MSG..": ", err)
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return
    else
        if fs_config:get("debug") then os.execute(LOGGER_BASE.." WS: "..data) end
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
    if fs_config:get("debug") then os.execute(LOGGER_BASE.." WS: "..data) end
    if not data then
        ERROR_MSG = "failed to confirm initialization"
        ngx.say(ERROR_MSG..": ", err, " (",data, ")")
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return
    end

    if fs_config:get("debug") then os.execute(LOGGER_BASE.." file_out_path: "..file_out_path) end
    -- Send Data
    local f = assert(io.open(file_out_path, "rb"))
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
        if fs_config:get("debug") then os.execute(LOGGER_BASE.." WS: "..data) end
        if not data then
            ERROR_MSG = "failed to confirm byte block"
            ngx.say(ERROR_MSG..": ", err, " (",data, ")")
            os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
            return
        end

    end

    assert(f:close())
    
    local bytes, err = wb:send_text(text_to_send_post_transmission)
    if not bytes then
        ERROR_MSG = "failed to terminate transfer"
        ngx.say(ERROR_MSG..": ", err)
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return
    end
    data, typ, err = wb:recv_frame()
    if fs_config:get("debug") then os.execute(LOGGER_BASE.." WS: "..data) end
    if not data then
        ERROR_MSG = "failed to confirm termination"
        ngx.say(ERROR_MSG..": ", err, " (",data, ")")
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return
    end

    if fs_config:get("debug") then os.execute(LOGGER_BASE.." COMPLETE") end

    return ngx.exit(ngx.HTTP_OK)
end

function u.receive_data()
    local fs_config = ngx.shared.fs_config
    local LOG_TAG = "fs_websockets.receive_data"
    local LOGGER_BASE = "logger -i --priority info --tag "..LOG_TAG.." -- "
    local ERROR_MSG = ""
    if fs_config:get("debug") then
        os.execute(LOGGER_BASE.." STARTING")
    end

    -- MOST LIKELY GETTING INSTRUCTIONS FOR EVERYTHING... SO CONFIG DONE THEN

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
        os.execute(LOGGER_BASE.." WS: "..data)
        bytes, err              = wb:send_text("START OK")
        if not bytes then
            ERROR_MSG = "failed to instructions confirmation"
            ngx.say(ERROR_MSG..": ".. err)
            os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
            return ngx.exit(444)
        end
    end

    local cj            =   require "cjson"
    local url_args      =   ngx.req.get_uri_args()
    local h             =   ngx.req.raw_header()

    local _data         =   cj.decode(data)

    os.execute(LOGGER_BASE.." _data: "..cj.encode(_data))
    os.execute(LOGGER_BASE.." HEADERS: "..cj.encode(h))
    os.execute(LOGGER_BASE.." url_args: "..cj.encode(url_args))
    
    local service_dest  =   _data.service_dest
    local save_path     =   _data.save_path
    local filename      =   _data.filename
    local filepath      =   _data.filepath
    local EOF           =   _data.EOF

    if not service_dest then
        service_dest    =   url_args.service_dest
    end

    if not save_path then
        save_path       =   "/tmp"
    end

    if filepath and not filename then 
        filename        =   filepath:gsub("(.*)/([^/]+)$","%2")
    end

    if _data.uuid and not EOF then
        EOF             =   _data.uuid
    end


    if service_dest=="pdf_ocr" then
        save_path       =   _data.pdf_ocr_inbox_dir 
    elseif service_dest=="pgsql" then
        save_path       =   _data.pgsql_attachments_dir
    end


    local file_in,file_in_path = nil,nil
    if not filename then
        file_in         =   io.tmpfile()
    else
        file_in_path    =   save_path.."/"..filename
        file_in         =   assert(io.open(file_in_path, "wb"))
    end

    -- Receive & Confirm Data:
    while true do

        -- Receive Data or Error:
        local data, typ, err    = wb:recv_frame()
        
        if data==EOF then
            u.confirm_data_received(wb,LOGGER_BASE)
            break
        elseif not data then
            ERROR_MSG = "failed to receive next byte block"
            ngx.say(ERROR_MSG..": ".. err)
            os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
            return ngx.exit(444)
        else
            -- os.execute(LOGGER_BASE.." WS: "..data)
            file_in:write(data)
            u.confirm_data_received(wb,LOGGER_BASE)
        end

    end

    assert(file_in:flush())
    assert(file_in:close())

    if service_dest=="es" then
        os.execute(LOGGER_BASE.." CLOSING CONDITIONAL: "..service_dest)
        
        local f = io.open(file_in_path,'r')
        local json = f:read("*a")
        f:close()

        os.execute(LOGGER_BASE.." file_in_path: "..file_in_path)
        os.execute(LOGGER_BASE.." json: "..json)

        local res       =   {}
        res[0]          =   _data
        res[1]          =   file_in_path
        res[2]          =   cj
        res[3]          =   json

        local es_wb = require "fs_elasticsearch"
        es_wb.push_to_es(res)

    elseif service_dest=="pdf_ocr" then
        os.execute(LOGGER_BASE.." CLOSING CONDITIONAL: "..service_dest)
        os.execute("mv -f "..file_in_path.." "..file_in_path..".pdf")
        local f = assert(io.open("/tmp/"..filename,'w'))
        local json = f:write(cj.encode(_data))
        assert(f:close())

    elseif service_dest=="pgsql" then
        os.execute(LOGGER_BASE.." CLOSING CONDITIONAL: "..service_dest)
        local cmd = "/home/ub2/SERVER2/file_server/fs_ocr_to_pgsql"
        cmd = cmd .. " " .. _data.uid
        cmd = cmd .. " " .. _data.filename
        cmd = cmd .. " " .. save_path
        cmd = cmd .. " &"
        os.execute(LOGGER_BASE.." CMD: "..cmd)
        os.execute(cmd)
    end

    os.execute(LOGGER_BASE.." COMPLETE")
end

function u.check_query()
    local fs_config = ngx.shared.fs_config
    local LOG_TAG = "fs_websockets.check_query"
    local LOGGER_BASE = "logger -i --priority info --tag "..LOG_TAG.." -- "
    local ERROR_MSG = ""
    if fs_config:get("debug") then
        os.execute(LOGGER_BASE.." STARTING")
    end
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

    os.execute(LOGGER_BASE.." QRY: "..qry)
end


function u.update_pgsql(res)
    local fs_config = ngx.shared.fs_config
    local LOG_TAG = "fs_websockets.update_pgsql"
    local LOGGER_BASE = "logger -i --priority info --tag "..LOG_TAG.." -- "
    local ERROR_MSG = ""
    if fs_config:get("debug") then
        os.execute(LOGGER_BASE.." STARTING")
    end

    os.execute(LOGGER_BASE.." res.uuid:sub(1,#res.uuid-4): "..res.uuid:sub(1,#res.uuid-4))
    
    local qry = ""
    qry = "UPDATE file_idx SET _run_ocr = 'false' WHERE _key ='"..res.uuid:sub(1,#res.uuid-4).."'"
    qry = qry.." RETURNING uid;"
    qry = '/query?qry='..qry

    os.execute(LOGGER_BASE.." qry: "..qry)

    local resp                  =   ngx.location.capture(qry)
    if resp.status~=200 then
        os.execute(LOGGER_BASE.." qry: "..cj.encode(qry))
        os.execute(LOGGER_BASE.." qry: "..tostring(resp.status))
    end
    
    os.execute(LOGGER_BASE.." resp.status: "..resp.status)
    os.execute(LOGGER_BASE.." resp.body: "..resp.body)
    return resp.body:match("%d+")
end

function u.queue_ocr_to_pgsql(file_idx_uid,res,base_dir,attachments_dir)
    local fs_config = ngx.shared.fs_config
    local LOG_TAG = "fs_websockets.queue_ocr_to_pgsql"
    local LOGGER_BASE = "logger -i --priority info --tag "..LOG_TAG.." -- "
    local ERROR_MSG = ""
    if fs_config:get("debug") then
        os.execute(LOGGER_BASE.." STARTING")
    end

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

function u.os_capture(cmd, raw)
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    if raw then return s end
    s = string.gsub(s, '^%s+', '')
    s = string.gsub(s, '%s+$', '')
    s = string.gsub(s, '[\n\r]+', ' ')
    return s
end
function u.confirm_data_received(wb,LOGGER_BASE)
    -- Acknowledge Receipt or Error:
    local bytes, err              = wb:send_text("PART OK")
    if not bytes then
        ERROR_MSG = "failed to send confirmation"
        ngx.say(ERROR_MSG..": ".. err)
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return ngx.exit(444)
    end
end

function u.set_config()
    local fs_config = ngx.shared.fs_config
    local LOG_TAG = "fs_websockets.set_config"
    local LOGGER_BASE = "logger -i --priority info --tag "..LOG_TAG.." -- "
    local ERROR_MSG = ""
    if fs_config:get("debug") then
        os.execute(LOGGER_BASE.." STARTING")
    end

    local cj                        =   require"cjson"
    local qry                       =   "/query?qry=".."SELECT _json res FROM __config__"
    local resp                      =   ngx.location.capture(qry)
    local res                       =   {}
    ngx.shared.fs_config:flush_all()
    ngx.shared.fs_config:flush_expired()
    local fs_config                 =   ngx.shared.fs_config

    if resp.status~=200 then
        os.execute(LOGGER_BASE.." qry: "..cj.encode(qry))
        os.execute(LOGGER_BASE.." qry: "..tostring(resp.status))
    else
        
        res                         =   cj.decode(resp.body)[1]
        res                         =   cj.decode(res.res)

        function parse_tbl (_tbl, _key, _tag)
            if _key then
                local _val          =   _tbl[_key]
                if _tag then _key=_tag..":".._key end
                if type(_val)=="table" then
                    parse_tbl(_val,nil,_key)
                else
                    local t         =   {}
                    t[_key]         =   _val
                    coroutine.yield(t)
                end
            else
                for _k,_v in pairs(_tbl) do
                    if type(_v)=="table" then 
                        parse_tbl (_tbl, _k, _tag)
                    else
                        if _tag then _k=_tag..":".._k end
                        local t     =   {}
                        t[_k]       =   _v
                        coroutine.yield(t)
                    end
                end
            end
        end

        function parse_iter (_tbl)
            return coroutine.wrap(function () parse_tbl(_tbl) end)
        end

        for _var in parse_iter(res) do
            for k,v in pairs(_var) do
                local succ, err, forcible = fs_config:set(k,v)
                if not succ or err then 
                    os.execute(LOGGER_BASE.." ISSUE WITH SETTING SHARED DICT (fs_config)")
                    os.execute(LOGGER_BASE.." k: "..cj.encode(k))
                    os.execute(LOGGER_BASE.." v: "..cj.encode(v))
                    os.execute(LOGGER_BASE.." succ: "..cj.encode(succ))
                    os.execute(LOGGER_BASE.." err: "..cj.encode(err))
                    os.execute(LOGGER_BASE.." forcible: "..cj.encode(forcible))
                end
            end
        end

    end 
end
function u.get_config()
    local fs_config = ngx.shared.fs_config
    local LOG_TAG = "fs_websockets.get_config"
    local LOGGER_BASE = "logger -i --priority info --tag "..LOG_TAG.." -- "
    local ERROR_MSG = ""
    if fs_config:get("debug") then
        os.execute(LOGGER_BASE.." STARTING")
    end

    local cj            =   require"cjson"
    local fs_config     =   ngx.shared.fs_config
    local t             =   {}
    local _keys         =   fs_config:get_keys()

    for i,v in ipairs(_keys) do
        t[v]            =   fs_config:get(v)
    end
    ngx.say(cj.encode(t))
end
function u.send_config()
    local fs_config = ngx.shared.fs_config
    local LOG_TAG = "fs_websockets.send_config"
    local LOGGER_BASE = "logger -i --priority info --tag "..LOG_TAG.." -- "
    local ERROR_MSG = ""
    if fs_config:get("debug") then
        os.execute(LOGGER_BASE.." STARTING")
    end


    local cj = require"cjson"

    -- local this_ip = u.os_capture("curl -s 'http://ipv4.nsupdate.info/myip'")
    local this_ip = "65.96.175.247"
    
    local t = {}
    local _keys = fs_config:get_keys()
    if not _keys then 
        set_config()
        _keys = fs_config:get_keys()
    end
    local _servers = {}
    local server_addr = ""
    for i,k in ipairs(_keys) do
        t[k] = fs_config:get(k)
        if k:match("server_host") and t[k]~=this_ip then 
            server_addr = k:gsub("server_host","server_port")
            _servers[t[k]]=fs_config:get( server_addr )
        end
    end

    local config_vars = cj.encode(t)

    -- local other_servers = cj.encode(_servers)
    -- os.execute(LOGGER_BASE.." config_vars: "..config_vars)
    -- os.execute(LOGGER_BASE.." other_servers: "..other_servers)
    fs_config:set("debug",true)

    for k,v in pairs(_servers) do
        server_addr = "ws://"..k..":"..v.."/receive_config"

        os.execute(LOGGER_BASE.." server_addr: "..server_addr)

        -- Start Websocket
        local client = require "resty.websocket.client"
        local wb, err = client:new{
            timeout = 10000,                            -- in milliseconds
            max_payload_len = 1048576,
        }

        -- Make Connect and Error Check:
        local ok, err = wb:connect(server_addr)
        if not ok then
            ERROR_MSG = "failed to connect"
            ngx.say(ERROR_MSG..": ".. err)
            os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
            return
        end
        local data, typ, err = wb:recv_frame()
        if not data then
            ERROR_MSG = "failed to receive 1st frame"
            ngx.say(ERROR_MSG..": ", err)
            os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
            return
        else
            if fs_config:get("debug") then os.execute(LOGGER_BASE.." WS: "..data) end
        end

        local bytes, err = wb:send_binary(config_vars)
        if not bytes then
            ERROR_MSG = "failed to send byte block"
            -- ngx.say(ERROR_MSG..": ", err)
            os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
            return
        end

        data, typ, err = wb:recv_frame()
        if fs_config:get("debug") then os.execute(LOGGER_BASE.." WS: "..cj.encode(data)) end
        if not data then
            ERROR_MSG = "failed to confirm byte block"
            -- ngx.say(ERROR_MSG..": ", err, " (",data, ")")
            os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
            return
        end

    end
    
end
function u.receive_config()
    local fs_config = ngx.shared.fs_config
    local LOG_TAG = "fs_websockets.receive_config"
    local LOGGER_BASE = "logger -i --priority info --tag "..LOG_TAG.." -- "
    local ERROR_MSG = ""
    if fs_config:get("debug") then
        os.execute(LOGGER_BASE.." STARTING")
    end

    fs_config:set("debug",true)

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


    -- Receive Data or Error:
    local data, typ, err    = wb:recv_frame()
    
    if not data then
        ERROR_MSG = "failed to receive next byte block"
        ngx.say(ERROR_MSG..": ".. err)
        os.execute(LOGGER_BASE.." WS: "..ERROR_MSG)
        return ngx.exit(444)
    else
        os.execute(LOGGER_BASE.." WS: "..data)
        u.confirm_data_received(wb,LOGGER_BASE)
    end

    local cj            =   require"cjson"
    local config_vars   =   cj.decode(data)

    for k,v in pairs(config_vars) do
        local succ, err, forcible = fs_config:set(k,v)
        if not succ or err then 
            os.execute(LOGGER_BASE.." ISSUE WITH SETTING SHARED DICT (fs_config)")
            os.execute(LOGGER_BASE.." k: "..cj.encode(k))
            os.execute(LOGGER_BASE.." v: "..cj.encode(v))
            os.execute(LOGGER_BASE.." succ: "..cj.encode(succ))
            os.execute(LOGGER_BASE.." err: "..cj.encode(err))
            os.execute(LOGGER_BASE.." forcible: "..cj.encode(forcible))
        end
    end

    if fs_config:get("debug") then
        os.execute(LOGGER_BASE.." COMPLETE")
    end

end
return u
