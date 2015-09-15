package = "pgmoon"
version = "1.1.1-1"

source = {
  url = "git://github.com/leafo/pgmoon.git",
  branch = "v1.1.1"
}

description = {
  summary = "Postgres driver for OpenResty and Lua",
  detailed = [[PostgreSQL driver written in pure Lua for use with OpenResty's cosocket API. Can also be used in regular Lua with LuaSocket and LuaCrypto.]],
  homepage = "https://github.com/leafo/pgmoon",
  maintainer = "Leaf Corcoran <leafot@gmail.com>",
  license = "MIT"
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type = "builtin",
  modules = {
    ["pgmoon"] = "pgmoon/init.lua",
    ["pgmoon.crypto"] = "pgmoon/crypto.lua",
    ["pgmoon.socket"] = "pgmoon/socket.lua",
  },
}

