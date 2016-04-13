
module("pgsql_curl_query", package.seeall)

-- ngx.log(ngx.WARN,"\n\n\t\t>> {pgsql_curl_query} : running \n\n")

-- EXAMPLE: curl -s --url "http://0.0.0.0:9999/curl_query" -X POST -d "qry=select distinct server res from servers where server_idx is not null order by server"

-- ngx.req.read_body()
-- local post_args = ngx.req.get_post_args() -- reads as table
--local post_args             = ngx.req.get_body_data() --returns string

-- local cj = require"cjson"
-- ngx.log(ngx.WARN,"\n\n\t\t>> {pgsql_curl_query} : post_args >>\n\n"      ..cj.encode(post_args)..    "\n\n<<")


local qry                       =   ngx.decode_args(ngx.var.qry, 0)
-- ngx.log(ngx.WARN,"\n\n\t\t>> {pgsql_curl_query} : qry >>\n\n"      ..cj.encode(qry)..    "\n\n<<")
for k,v in pairs(qry) do
    ngx.var.qry                 =   k
    -- ngx.log(ngx.WARN,"\n\n\t\t>> {pgsql_curl_query} : k >>\n\n"      ..k..    "\n\n<<")
    break
end

-- ngx.log(ngx.WARN,"\n\n\t\t>> {pgsql_curl_query} : ngx.var.qry >>\n\n"      ..ngx.var.qry..    "\n\n<<")
-- ngx.log(ngx.WARN,"\n\n\t\t>> {pgsql_curl_query} : ngx.var.arg_qry >>\n\n"      ..ngx.var.arg_qry..    "\n\n<<")

-- ngx.log(ngx.WARN,"\n\n\t\t>> {pgsql_curl_query} : post_args >>\n\n"      ..cj.encode(post_args)..    "\n\n<<")