#!/bin/sh

exec '/usr/local/openresty/luajit/bin/luajit-2.1.0-alpha' -e 'package.path="/home/ub2/.luarocks/share/lua/5.1/?.lua;/home/ub2/.luarocks/share/lua/5.1/?/init.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?/init.lua;"..package.path; package.cpath="/home/ub2/.luarocks/lib/lua/5.1/?.so;/usr/local/openresty/luajit/lib/lua/5.1/?.so;"..package.cpath' -e 'local k,l,_=pcall(require,"luarocks.loader") _=k and l.add_context("luaprofiler","2.0.2-2")' '/usr/local/openresty/luajit/lib/luarocks/rocks/luaprofiler/2.0.2-2/bin/summary.lua' "$@"
