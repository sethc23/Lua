-- sites-available/lua_files/receive_upload

module("receive_upload", package.seeall)

--ngx.log(ngx.WARN,"---->> receive_upload START <<----")

--local resty_sha1    =   require "resty.sha1"
--local resty_md5     =   require "resty.md5"
local upload        =   require "resty.upload"
local cjson         =   require "cjson"

local chunk_size    =   4096
local form          =   upload:new(chunk_size)
--local sha1        =   resty_sha1:new()
--local md5         =   resty_md5:new()
local                   file
local pdf_id        =   ""
local post_continue =   false
local t             =   ""
local s             =   nil
local test_conv     =   false
local windows_conv  =   false
local file_name     =   ""
local file_path     =   "/home/ub2/SERVER2/aprinto/media/uploads/"
local save_path     =   ""
local started       =   false
local start_upload  =   false
local stop_upload   =   false
local uploaded      =   false


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

    if ( typ=="header" and stop_upload==false ) then

        s           =   string.find(cjson.encode(res),"filename=",1)
        if ( started==false and s~=nil ) then
            started =   true

            --ngx.log(ngx.WARN,"{receive_upload.lua}/ HEADER: "..cjson.encode(res))

            for key, val in pairs(res) do

                --ngx.log(ngx.WARN,"key: "..key)
                --ngx.log(ngx.WARN,"val: "..val)

                s                                   =   string.find(val,"%.pdf",1) -- windows path convention
                if s~=nil then
                    s                               =   string.find(val,"/%w+.pdf",1) -- linux/mac path convention
                    if s==nil then
                        s                           =   ""
                        windows_conv                =   True
                    end
                end

                if s~=nil then

                    if windows_conv==false then         -- linux/mac path convention
                        file_name                   =   string.gsub(val,"(.*)/(%w+.pdf)(.*)","%2")
                        --ngx.log(ngx.WARN,"linux conv2: "..s)
                    else                                -- windows path convention
                        file_name                   =   string.gsub(val,"(.*)\\([^\\\\]+%.pdf)(.*)","%2")
                        --ngx.log(ngx.WARN,"windows conv2: "..s)
                    end

                    s                               =   string.find(file_name,"=",1)
                    if s~=nil then
                        file_name                   =   file_name:gsub("(.*)\"([^\"]+%.pdf)(.*)","%2")
                    end

                    pdf_id                          =   file_name:gsub("(.*)([^_]+)_([^%.]+)%.pdf","%3")


                    -- --------------------------------------------<<
                    -- DO PDF_ID CHECK RETURN IF NO EXISTING PDF_ID
                    s                               =   ngx.location.capture(
                        '/pdf_id_check/',
                        { method                    =   ngx.HTTP_POST,
                            args                    =
                                { pdf_id            =   pdf_id } }
                    )
                    s                               =   s.body:gsub("%[","")
                    s                               =   s:gsub("%]","")
                    s                               =   s:gsub("%\"","")
                    s                               =   s:gsub(" ","")
                    s                               =   "{"..s:gsub("(.*)(\"{)(.*)(}\")(.*)","%3").."}"

                    for k,v in string.gmatch(s,'([^:{,]+):([^,}]+)') do
                        if k=="cnt" then
                            --ngx.log(ngx.WARN,"{receive_upload.lua}/odf_id_check CNT: "..cjson.encode({type(v),v}))
                            if v=="1" then post_continue = true end
                            break
                        end
                    end
                    -- CONFIRM FILE TYPE IS PDF ELSE RETURN


                    if post_continue==false then return ngx.exit(ngx.HTTP_FORBIDDEN) end
                    -- -------------------------------------------->>
                    -- -------------------------------------------->>


                    save_path                       =   file_path..file_name
                    file                            =   io.open(save_path, "w+")
                    --ngx.log(ngx.WARN,"FILE_NAME: "..file_name)
                    break
                end
            end
        end

    elseif ( typ=="body" and stop_upload==false )  then

        t                   =   string.find(cjson.encode(res),"%%PDF",1)
        if ( t~= nil and t>0 ) then
            start_upload    =   true
            --ngx.log(ngx.WARN,cjson.encode({"START: ",start_upload,stop_upload}))
        end


        t                   =   string.find(cjson.encode(res),"%%%%EOF",1)
        if ( t~=nil and t>0 ) then

            file:write(res)
            --sha1:update(res)
            --md5:update(res)

            stop_upload     =   true
            --ngx.log(ngx.WARN,cjson.encode({"STOP: ",start_upload,stop_upload}))

        end

        if ( start_upload==true and stop_upload==false ) then

            if file then
                file:write(res)
                --sha1:update(res)
                --md5:update(res)
            end

        end

    elseif ( typ=="part_end" and stop_upload==true and uploaded==false ) then
        file:close()
        file                =   nil
        uploaded            =   true
        --local sha1_sum    =   sha1:final()
        --local md5_sum     =   md5:final()
        --sha1:reset()
        --md5:reset()

        --local str         =   require "resty.string"
        --ngx.say("sha1_sum  "          ..str.to_hex(sha1_sum))
        --ngx.say("md5_sum  "           ..str.to_hex(md5_sum))
        --ngx.log(ngx.WARN,"sha1_sum  " ..str.to_hex(sha1_sum))
        --ngx.log(ngx.WARN,"md5_sum  "  ..str.to_hex(md5_sum))

    elseif typ == "eof" then
        break

    else
        -- do nothing
    end
end

if uploaded==false then return ngx.exit(ngx.HTTP_FORBIDDEN) end

local post_resp = ngx.location.capture(
    '/update_new_order/',
    { method    = ngx.HTTP_POST,
        args    = {
            local_document  =   save_path,
            qr_url          =   "",
            pdf_id          =   pdf_id } }
)

if post_resp.status~=200 then
    ngx.log(ngx.WARN,"-- {receive_upload.lua}/ : post_resp :>>"     ..cjson.encode(post_resp.status)..       "<<  ")
    ngx.log(ngx.WARN,"-- {receive_upload.lua}/ : file_name :>>"     ..cjson.encode(file_name)..              "<<  ")
    ngx.log(ngx.WARN,"-- {receive_upload.lua}/ : save_path :>>"     ..cjson.encode(save_path)..              "<<  ")
    ngx.log(ngx.WARN,"-- {receive_upload.lua}/ : pdf_id    :>>"     ..cjson.encode(pdf_id)..                 "<<  ")
end

-- Avail from DB: "body":"[{\"order_tag\":\"FCZA\",\"printer_id\":\"1.0.8.0\",\"machine_id\":\"0db83722-3e83-4343-94bf-614dce442326\",\"application_name\":\"Microsoft\",\"doc_name\":\"Word\",\"status\":\"U\"}]"

s                           =   post_resp.body:gsub("%[","")
s                           =   s:gsub("%]","")
s                           =   s:gsub("%\"","")
s                           =   s:gsub(" ","")
s                           =   "{"..s:gsub("(.*)(\"{)(.*)(}\")(.*)","%3").."}"

local t                     =   {}
for k,v in string.gmatch(s,'([^:{,]+):([^,}]+)') do
    t[k]                    =   v
end
local machine_id            =   t.machine_id
local order_tag             =   t.order_tag
local ip_addr               =   t.ip_addr

local queue_file = ngx.location.capture(
    '/queue_file',
    { method    =   ngx.HTTP_GET,
       args     =   {
           pdf_id           =   pdf_id,
           machine_id       =   machine_id,
           local_document   =   save_path,
           order_tag        =   order_tag,
           ip_addr          =   ip_addr
       } }
)

if queue_file.status~=200 then
    ngx.log(ngx.WARN,"-- {receive_upload.lua}/ : queue_file :>>"    ..cjson.encode(queue_file.status)..       "<<  ")
    ngx.log(ngx.WARN,"-- {receive_upload.lua}/ : file_name :>>"     ..cjson.encode(file_name)..                "<<  ")
    ngx.log(ngx.WARN,"-- {receive_upload.lua}/ : save_path :>>"     ..cjson.encode(save_path)..                "<<  ")
    ngx.log(ngx.WARN,"-- {receive_upload.lua}/ : pdf_id :>>"        ..cjson.encode(pdf_id)..                   "<<  ")
end

--[[
TODO:  input to DB: sha1_sum,md5_sum
--]]

--ngx.log(ngx.WARN,"---->> receive_upload END <<----")