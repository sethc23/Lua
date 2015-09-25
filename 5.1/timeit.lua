--
-- User: admin
-- Date: 9/24/15
-- Time: 10:59 PM
-- modified https://gist.github.com/mkfmnn/3726661#file-timeit-lua
--

--- call a function with a repeat count argument.
-- Takes a single argument, which is a function which in turn takes one argument,
-- a repeat count.  The function is called with increasingly large repeat counts
-- until it takes at least a certain amount of time to run, and is then called four
-- more times with the same repeat count, with the minimum elapsed time recorded.
-- Modeled loosely on Python's timeit, except the function passed in is responsible
-- for doing the actual repetition.
return function(func)

    function iter_func(n)
        for i=1,n do func() end
    end

    local reps = 1
    local elapsed
    repeat
        reps = reps * 10
        local start = os.clock()
        iter_func(reps)
        elapsed = os.clock() - start
    until elapsed>0.05 or reps >= 1e9
    for i = 1, 4 do
        local start = os.clock()
        iter_func(reps)
        elapsed = math.min(elapsed, os.clock() - start)
    end
    return ("%7.3f nsec/call"):format( (elapsed / reps) * 1e9 )
end

