
--package.path = package.path .. "/home/ub2/.luarocks/share/lua/5.1/?.lua;/home/ub2/.luarocks/share/lua/5.1/?/init.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?/init.lua;/root/.luarocks/share/lua/5.1/?.lua;/root/.luarocks/share/lua/5.1/?/init.lua;:/Lua:/Lua/luajit:/Lua:/Lua/lualib;"

--package.loaded.mobdebug = nil
--package.loaded.pl = nil
--package.loaded.penlight = nil
--pl=require"pl"

-- ssh -nN -R 8172:localhost:8172 ub2 &

m=require('mobdebug').start("10.0.0.53")
u = {}
n = ngx
a="test"
--
--z = ngx.var.request_uri


--package.loaded.mobdebug = nil

