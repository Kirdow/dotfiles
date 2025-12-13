_G["dump"] = function(o, depth)
    if type(depth) ~= 'number' then
        depth = 3
    end
    local prefix = ""
    local pprefix = ""
    for i=1,depth do
	pprefix = prefix
        prefix = prefix .. "  "
    end
    if type(o) == 'table' then
	if depth <= 0 then
	    return '{...}'
	end
        local s = '{\n'
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. prefix .. '[' .. k .. '] = ' .. dump(v,depth-1) .. ',\n'
        end
        return s .. pprefix .. '}'
    else
        return tostring(o)
    end
end

_G["var_dump"] = function(n, o)
    print(n .. ": " .. dump(o))
end

_G["search_path"] = function(o, s, p, depth)
    local found = ""
    if type(o) ~= 'table' then
        return found
    end

    if type(depth) ~= 'number' then
        depth = 1
    end
    if type(p) ~= 'string' then
        p = ""
    end

    if depth >= 6 then
        return found
    end

    for k,v in pairs(o) do
        local key = tostring(k)
        local path = p .. "." .. key
        if p == "" then
            path = key
        end

        if path:sub(-#s) == s then
            if #found == 0 then
                found = path
            else
                found = found .. ", " .. path
            end
        else 
            local next = search_path(v, s, path, depth + 1)
            if #next ~= 0 then
                if #found == 0 then
                    found = next
                else
                    found = found .. ", " .. next
                end
            end
        end
    end

    return found
end

_G["show_path"] = function(o, s)
    path = search_path(o, s)
    if #path ~= 0 then
        print(s .. " is: " .. path)
    else
        print(s .. " is: " .. "not found")
    end
end

