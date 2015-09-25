--
-- User: admin
-- Date: 9/21/15
-- Time: 2:27 PM
--

local u={}

function u.permgen (a, n)

    if n == 0 then
        coroutine.yield(a)
    else

        for i=1,n do

            -- put i-th element as the last one
            a[n], a[i] = a[i], a[n]

            -- generate all permutations of the other elements
            u.permgen(a, n - 1)

            -- restore i-th element
            a[n], a[i] = a[i], a[n]

        end

    end

end

function u.perm (a)
      local n = table.getn(a)
      return coroutine.wrap(function () u.permgen(a, n) end)
end

return u

-- TEST:  for p in perm{"a", "b", "c"} do printResult(p) end

