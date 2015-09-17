
u = {}

function u.getfield (f)
      local v = _G    -- start with the table of globals
      for w in string.gfind(f, "[%w_]+") do v = v[w] end
      return v
end

function u.log_env ()
    for n in pairs(_G) do
        log(n)
    end
end

return u