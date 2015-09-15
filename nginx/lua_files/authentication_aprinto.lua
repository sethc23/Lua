-- sites-available/lua_files/authentication_aprinto.lua
--package.path = package.path .. ";/usr/local/openresty/luajit/share/lua/5.1/mobdebug.lua"
--require('mobdebug').start('10.0.1.52')

module("authentication_aprinto", package.seeall)

--ngx.log(ngx.WARN,"-- {auth_aprinto}/ : START :>> -- <<  ")

-- -------------------------------------------------
-- Functions ---------------------------------------

function ReverseTable (t)
    local reversedTable = {}
    local itemCount = #t
    for k, v in ipairs(t) do
        reversedTable[itemCount + 1 - k] = v
    end
    return reversedTable
end

function update_array_remove (list,item)
  local remove_list = {}
  for i,v in ipairs(list) do
      if v==item then table.insert(remove_list,i) end
  end
  local rev_remove_list = ReverseTable(remove_list)
  for i,v in ipairs(rev_remove_list) do table.remove(list,v) end
  return list
end

-- -------------------------------------------------
-- -------------------------------------------------


local cjson                 =   require "cjson"

local h                     =   ngx.req.raw_header()
--ngx.log(ngx.WARN,"-- {auth_aprinto} : header :>>"           ..cjson.encode(h)..    "<< ")
for row in h:gmatch('(.*)([^%\n]+)%\n') do
    for c in row:gmatch('form%-data') do
        --ngx.log(ngx.WARN,"-- {auth_aprinto} : RETURN header :>>"      ..cjson.encode(h)..    "<< ")
        return
    end
end

local req_method            =   ngx.req.get_method()
--ngx.log(ngx.WARN,"-- {auth_aprinto}/ : req_method :>>"           ..req_method..           "<<  ")
if req_method=="GET" then return end

ngx.req.read_body()
local post_args             =   cjson.encode(ngx.req.get_post_args())
--ngx.log(ngx.WARN,"-- {auth_aprinto}/ : post_args :>>"           ..post_args..           "<<  ")

local s                     =   post_args:gsub("%[","")
s                           =   s:gsub("%]","")
s                           =   s:gsub("\\\"","")
s                           =   s:gsub(" ","")
s                           =   s:gsub(":true}","")
--ngx.log(ngx.WARN,"-- {auth_aprinto}/ : clean_post_args :>>"     ..s..                   "<<  ")

local machine_id            =   ""
local valid_fields          =   {"pdf_id","printer_id","machine_id","application_name","doc_name"}
for k,v in s:gmatch('([^:{,]+):([^,}]+)') do
    if k=="machine_id" then machine_id=v end
    valid_fields            =   update_array_remove(valid_fields,k)
end
--ngx.log(ngx.WARN,"-- {auth_aprinto}/ : #valid_fields :>>"       ..#valid_fields..                   "<<  ")


--[[
ngx.log(ngx.WARN,"-- {auth_aprinto}/ : req_meth :>>"       ..req_method..  "<<  ")
ngx.log(ngx.WARN,"-- {auth_aprinto}/ : post_args :>>"      ..p..                   "<<  ")
ngx.log(ngx.WARN,"-- {auth_aprinto}/ : t :>>"              ..t..                   "<<  ")
ngx.log(ngx.WARN,"-- {auth_aprinto}/ : mach_id :>>"        ..machine_id..  "<<  ")
--]]


local capt_url              =   "/auth_check?ip_addr="..ngx.var.remote_addr.."&machine_id="..machine_id
local auth_res_orig         =   ngx.location.capture(capt_url)

local auth_res              =   string.gsub(auth_res_orig.body,"%[","")
auth_res                    =   string.gsub(auth_res,"%]","")
auth_res                    =   cjson.decode(auth_res).res

--ngx.log(ngx.WARN,"-- {auth_aprinto} : END :>> -- << ")

if auth_res == "ok" then
    --ngx.log(ngx.WARN,"-- {auth_aprinto}/ : auth_res_orig :>>"   ..cjson.encode(auth_res_orig).. "<<  ")
    --ngx.log(ngx.WARN,"-- {auth_aprinto}/ : machine_id :>>"      ..cjson.encode(machine_id)..    "<<  ")
    --return ngx.exit(ngx.HTTP_OK)
    if  #valid_fields==0 then return
    else return ngx.exit(ngx.HTTP_FORBIDDEN) end

else
    --ngx.log(ngx.WARN,"-- {auth_aprinto}/ : auth_res :>>"    ..auth_res..                "<<  ")

    -- IF VALID POST ARGS, RETURN
    --      (in the f(x) z_aprinto_authentication, a source will not be blacklisted
    --          until 5th attempt when providing a machine_id)

    if #valid_fields==0 then return


    -- WHAT ABOUT SUBSEQUENT POST TO '/' THAT IS INVALID?
    --      WON'T THAT ALSO COUNT TOWARD THE '5 CHANCES' SUCH THAT EVERY PRINT COUNTS AS TWO CHANCES?
    --          AND, MACHINE_ID IS NOT PROVIDED AT THAT POINT!!
    --      BUT, IF THE "PDF_ID" IS THE SAME, THEN SKIP z_aprinto_authentication ?
    --          MAKES SENSE BECAUSE IP ALREADY CHECKED -- NO NEED TO RUN AGAIN
    --              (SINCE NO CHANGE UNTIL AT LEAST AFTER POSTING PDF)
    --      AS IS TURNS OUT, WHEN A PDF IS POSTED, AUTH IS DIFFERED TO receive_upload.lua ANYWAY...
    --      TODO: ngx.auth_aprinto -- limit pdf posts to those with valid pdf_id's (append receive_upload.lua)

    -- ELSE: FORBIDDEN

    else return ngx.exit(ngx.HTTP_FORBIDDEN) end

end