module("pgsql_query", package.seeall)

local qry                       =   ngx.decode_args(ngx.var.qry, 0)
for k,v in pairs(qry) do
    ngx.var.qry                 =   k
    break
end
ngx.log(ngx.WARN,"-- \n{pgsql_system.lua} : \n ngx.var.qry :>>\n"      ..ngx.var.qry..    "\n<< ")