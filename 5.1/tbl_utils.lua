--
-- User: admin
-- Date: 9/17/15
-- Time: 10:19 AM
--
--module("tbl_utils", package.seeall)

local _tbl = {}

function _tbl.val_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return "table" == type( v ) and _tbl.tostring( v ) or
      tostring( v )
  end
end

function _tbl.key_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. _tbl.val_to_str( k ) .. "]"
  end
end

function _tbl.tostring( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, _tbl.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
        _tbl.key_to_str( k ) .. "=" .. _tbl.val_to_str( v ) )
    end
  end
  return "{" .. table.concat( result, "," ) .. "}"
end

function _tbl.table_invert(t)
  local u = { }
  for k, v in pairs(t) do u[v] = k end
  return u
end

function _tbl.index(tbl_in,_var)
    local t = {}
    t = _tbl.table_invert(tbl_in)
    local cnt = 1
    for k,v in pairs(t) do
        if v==_var then return cnt
        else cnt = cnt + 1 end
    end
    return nil
end

function _tbl.count(t,_var)
    local t,cnt = {},0
    t = _tbl.table_invert(tbl_in)
    for i,v in ipairs(t) do
        if v==_var then cnt = cnt + 1 end
    end
    return cnt
end

return _tbl