
-- sites-available/lua_files/aporo_ngx.lua
module("access_mirror", package.seeall)

ngx.log(ngx.WARN,"#>>> {access_mirror.lua}: START <<<#")

ngx.say("{")

local cjson                 =   require "cjson"

local r                     =   {}
local h                     =   ngx.req.get_headers()
-- for k, v in pairs(h) do
for k, v in pairs(h) do
    ngx.say("\""..k.."\":\""..v.."\",")
    -- r[k]                  =   v
end
ngx.say("\"request_method\":\""..ngx.req.get_method().."\",")
-- ngx.log(ngx.WARN,"-- \n{aporo_ngx.lua} : \nheader :>>\n"      ..cjson.encode(ngx.req.raw_header())..    "\n<< ")

local r_vars                =                  {ngx.var.args,
                                                ngx.var.binary_remote_addr,
                                                ngx.var.body_bytes_sent,
                                                ngx.var.bytes_sent,
                                                ngx.var.connection,
                                                ngx.var.connection_requests,
                                                ngx.var.content_length,
                                                ngx.var.content_type,
                                                ngx.var.cookie_name,
                                                ngx.var.document_root,
                                                ngx.var.document_uri,
                                                ngx.var.host,
                                                ngx.var.hostname,
                                                ngx.var.http_name,
                                                ngx.var.https,
                                                ngx.var.is_args,
                                                ngx.var.limit_rate,
                                                ngx.var.msec,
                                                ngx.var.nginx_version,
                                                ngx.var.pid,
                                                ngx.var.pipe,
                                                ngx.var.proxy_protocol_addr,
                                                ngx.var.query_string,
                                                ngx.var.realpath_root,
                                                ngx.var.remote_addr,
                                                ngx.var.remote_port,
                                                ngx.var.remote_user,
                                                ngx.var.request,
                                                ngx.var.request_body,
                                                ngx.var.request_body_file,
                                                ngx.var.request_completion,
                                                ngx.var.request_filename,
                                                ngx.var.request_length,
                                                ngx.var.request_method,
                                                ngx.var.request_time,
                                                ngx.var.request_uri,
                                                ngx.var.scheme,
                                                ngx.var.sent_http_name,
                                                ngx.var.server_addr,
                                                ngx.var.server_name,
                                                ngx.var.server_port,
                                                ngx.var.server_protocol,
                                                ngx.var.status,
                                                ngx.var.tcpinfo_rtt,
                                                ngx.var.tcpinfo_rttvar,
                                                ngx.var.tcpinfo_snd_cwnd,
                                                ngx.var.tcpinfo_rcv_space,
                                                ngx.var.time_iso8601,
                                                ngx.var.time_local,
                                                ngx.var.uri,
                                                ngx.var.proxy_host,
                                                ngx.var.proxy_port,
                                                ngx.var.proxy_add_x_forwarded_for,
                                                ngx.var.secure_link,
                                                ngx.var.secure_link_expires,
                                                ngx.var.session_log_id,
                                                ngx.var.session_log_binary_id,
                                                ngx.var.spdy,
                                                ngx.var.spdy_request_priority,
                                                ngx.var.ssl_cipher,
                                                ngx.var.ssl_client_cert,
                                                ngx.var.ssl_client_fingerprint,
                                                ngx.var.ssl_client_raw_cert,
                                                ngx.var.ssl_client_serial,
                                                ngx.var.ssl_client_s_dn,
                                                ngx.var.ssl_client_i_dn,
                                                ngx.var.ssl_client_verify,
                                                ngx.var.ssl_protocol,
                                                ngx.var.ssl_server_name,
                                                ngx.var.ssl_session_id,
                                                ngx.var.ssl_session_reused}

local r_names               =                  {"args",
                                                "binary_remote_addr",
                                                "body_bytes_sent",
                                                "bytes_sent",
                                                "connection",
                                                "connection_requests",
                                                "content_length",
                                                "content_type",
                                                "cookie_name",
                                                "document_root",
                                                "document_uri",
                                                "host",
                                                "hostname",
                                                "http_name",
                                                "https",
                                                "is_args",
                                                "limit_rate",
                                                "msec",
                                                "nginx_version",
                                                "pid",
                                                "pipe",
                                                "proxy_protocol_addr",
                                                "query_string",
                                                "realpath_root",
                                                "remote_addr",
                                                "remote_port",
                                                "remote_user",
                                                "request",
                                                "request_body",
                                                "request_body_file",
                                                "request_completion",
                                                "request_filename",
                                                "request_length",
                                                "request_method",
                                                "request_time",
                                                "request_uri",
                                                "scheme",
                                                "sent_http_name",
                                                "server_addr",
                                                "server_name",
                                                "server_port",
                                                "server_protocol",
                                                "status",
                                                "tcpinfo_rtt",
                                                "tcpinfo_rttvar", 
                                                "tcpinfo_snd_cwnd", 
                                                "tcpinfo_rcv_space",
                                                "time_iso8601",
                                                "time_local",
                                                "uri",
                                                "proxy_host",
                                                "proxy_port",
                                                "proxy_add_x_forwarded_for",
                                                "secure_link",
                                                "secure_link_expires",
                                                "session_log_id",
                                                "session_log_binary_id",
                                                "spdy",
                                                "spdy_request_priority",
                                                "ssl_cipher",
                                                "ssl_client_cert",
                                                "ssl_client_fingerprint",
                                                "ssl_client_raw_cert",
                                                "ssl_client_serial",
                                                "ssl_client_s_dn",
                                                "ssl_client_i_dn",
                                                "ssl_client_verify",
                                                "ssl_protocol",
                                                "ssl_server_name",
                                                "ssl_session_id",
                                                "ssl_session_reused"}
ngx.log(ngx.WARN,"#>>> ".."TEST PAIRS:  "..#r_vars.."==?=="..#r_names.." <<<#")
-- ngx.log(ngx.WARN,"#>>> ".."TEST".." <<<#")

for i=1,#r_vars do
    if r_vars[i] then ngx.say("\""..r_names[i].."\":\""..r_vars[i]:gsub("\n","").."\",") end
    -- if r_vars[i] then ngx.log(ngx.WARN,"#>>> "..r_names[i].." : "..r_vars[i]:gsub("\n","").." <<<#") end
end



-- local uri_args                  =   ngx.req.get_uri_args()
--ngx.log(ngx.WARN,"#>>> {aporo_ngx.lua}:uri_args "    ..cjson.encode({type(uri_args),uri_args})..    "<<<#")

-- local post_args                 =   {}
-- if ngx.var.request_method=='POST' then
--     ngx.req.read_body()
--     post_args                   =   ngx.req.get_post_args()
--    ngx.log(ngx.WARN,"#>>> {aporo_ngx.lua}:post_args "    ..cjson.encode({type(post_args),post_args})..    "<<<#")
-- end


-- ngx.say("\"content_length\":\""..ngx.header.content_type.."\"")
-- ngx.say(",\"content_type\":\""..ngx.header.content_type.."\"")
--ngx.say(",\"http_cookie\":\""..ngx.var.http_cookie.."\"")
--ngx.say(",\"date_gmt\":\""..ngx.var.date_gmt.."\"")
--ngx.say(",\"date_local\":\""..ngx.var.date_local.."\"")
--ngx.say(",\"document_root\":\""..ngx.var.document_root.."\"")
--ngx.say(",\"document_uri\":\""..ngx.var.document_uri.."\"")

--ngx.say(",\"args\":\""..ngx.var.args.."\"")
-- ngx.say(",\"binary_remote_addr\":\""..ngx.var.binary_remote_addr.."\"")
ngx.say("}")

ngx.exit(ngx.OK)



