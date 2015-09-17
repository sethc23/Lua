--
-- User: admin
-- Date: 9/17/15
-- Time: 10:19 AM
--

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

return _tbl