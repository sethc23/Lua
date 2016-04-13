

local fs_wb = require "fs_websockets"

--m=require('mobdebug').start("0.0.0.0")

local dest = {ip="127.0.0.1:12501", url_dest="/receive_json_file", exit=false}
local r = fs_wb.send_file(dest)             -- "tbl","uid","uuid","filepath"

--os.execute("rm -fr "..r.filepath)
