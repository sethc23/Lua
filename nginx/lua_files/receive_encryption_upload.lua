-- sites-available/lua_files/receive_upload

module("receive_encryption_upload", package.seeall)

--ngx.log(ngx.WARN,"---->> receive_upload START <<----")

local SERV_HOME     =   "/home/ub2/SERVER2"
local resty_sha1    =   require "resty.sha1"
local resty_md5     =   require "resty.md5"
local upload        =   require "resty.upload"
local cjson         =   require "cjson"
local uuid          =   require "uuid"
local str           =   require "resty.string"
local chunk_size    =   4096
local form          =   upload:new(chunk_size)
local md5           =   resty_md5:new()
local sha1          =   resty_sha1:new()
local sha1_sum      =   ""
local md5_sum       =   ""
local                   file
local t             =   ""
local s             =   nil
local file_name     =   ""
local file_path     =   SERV_HOME.."/encryption/upload/"
local save_path     =   ""
local started       =   false
local start_upload  =   false
local stop_upload   =   false
local uploaded      =   false


function os.capture(cmd, raw)
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    if raw then return s end
    s = string.gsub(s, '^%s+', '')
    s = string.gsub(s, '%s+$', '')
    s = string.gsub(s, '[\n\r]+', ' ')
    return s
end


while true do
    local typ, res, err = form:read()
    t               =   ""

    if not typ then
         ngx.say("failed to read: ", err)
         return
    end

    --[[
    if typ=="header" then
        ngx.log(ngx.WARN,"{receive_upload.lua}/ ALL HEADERS: "..cjson.encode(res))
    end
    --]]

    --ngx.log(ngx.WARN,cjson.encode({typ,res}))

    if ( typ=="header" and not stop_upload ) then

        s           =   string.find(cjson.encode(res),"filename=",1)
        if ( s and not started ) then
            started =   true

            --ngx.log(ngx.WARN,"{receive_upload.lua}/ HEADER: "..cjson.encode(res))

            for key, val in pairs(res) do

                --ngx.log(ngx.WARN,"key: "..key)
                --ngx.log(ngx.WARN,"val: "..val)

                if val:find("filename") then
                    file_name                       =   val:gsub("(.*)filename=\"([^\"]*)\"","%2")
                    file_uuid                       =   uuid.new("time")
                    save_path                       =   file_path..file_uuid
                    --save_path                       =   file_path..file_name
                    file                            =   io.open(save_path, "w+")
                    --ngx.log(ngx.WARN,"FILE_NAME: "..file_name)
                    -- ngx.log(ngx.WARN,"SAVE_PATH: "..save_path)
                    break
                end
            end
        end

    elseif ( typ=="body" and not stop_upload )  then

        --ngx.log(ngx.WARN,"COPYING BODY")
        start_upload        =   true

        t                   =   string.find(cjson.encode(res),"%%%%EOF",1)
        if ( t~=nil and t>0 ) then

            --ngx.log(ngx.WARN,"WRITING AND STOPPING")

            file:write(res)
            sha1:update(res)
            md5:update(res)

            stop_upload     =   true
            --ngx.log(ngx.WARN,cjson.encode({"STOP: ",start_upload,stop_upload}))

        end

        if ( start_upload and not stop_upload ) then

            --ngx.log(ngx.WARN,"WRITING")

            if file then
                file:write(res)
                sha1:update(res)
                md5:update(res)
            end

        end

    elseif ( ( typ=="part_end" or stop_upload) and not uploaded ) then
        --ngx.log(ngx.WARN,"CLOSING WRITE")
        file:close()
        file                =   nil
        uploaded            =   true
        sha1_sum            =   str.to_hex(sha1:final())
        md5_sum             =   str.to_hex(md5:final())
        sha1:reset()
        md5:reset()

        
        --ngx.say("sha1_sum  "          ..str.to_hex(sha1_sum))
        --ngx.say("md5_sum  "           ..str.to_hex(md5_sum))
        --ngx.log(ngx.WARN,"sha1_sum  " ..str.to_hex(sha1_sum))
        --ngx.log(ngx.WARN,"md5_sum  "  ..str.to_hex(md5_sum))

    elseif typ == "eof" then
        uploaded            =   true
        break

    else
        -- do nothing
    end
end

-- ngx.log(ngx.WARN,"---->> receive_upload PART I END <<----")



if not uploaded then
    ngx.log(ngx.WARN,"UPLOADED?---->>"..cjson.encode(uploaded).."<<----")
    return ngx.exit(ngx.HTTP_BAD_REQUEST)
else
    local cmd = "/usr/bin/python3 "..SERV_HOME.."/encryption/run_encryption.py convert "..file_name.." "..save_path.." "..sha1_sum.." "..md5_sum
    --ngx.log(ngx.WARN,"CMD:---->>"..cmd.."<<----")

    local res = os.capture(cmd, True)
    --ngx.log(ngx.WARN,"RES:---->>"..res.."<<----")

    ngx.var.new_file = save_path:gsub("(.*)/([^/]+)$","%2")

    return ngx.redirect(res)

end
