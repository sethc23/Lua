--
-- User: admin
-- Date: 9/21/15
-- Time: 9:59 PM
--

local unpack = unpack or table.unpack

local function fancyparams(arg_def, f)
    return function(args)
        local params = {}
        for i = 1, #arg_def do
            local paramname = arg_def[i][1] --the name of the first parameter to the function
            local default_value = arg_def[i][2]
            params[i] = args[i] or args[paramname] or default_value
        end
        return f(unpack(params, 1, #arg_def))
    end
end

return fancyparams

