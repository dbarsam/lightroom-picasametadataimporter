--[[----------------------------------------------------------------------------

--------------------------------------------------------------------------------

PMIUtil.lua
Plug-in's Utility Module

--------------------------------------------------------------------------------

Copyright 2010-2012, D. Barsam
You may use this script for any purpose, as long as you include this notice in
any versions derived in whole or part from this file.  

See 'https://github.com/dbarsam/lightroom-picasametadataimporter' for more info.
 
----------------------------------------------------------------------------]]--

-- Access the Lightroom SDK namespaces.
local LrApplication     = import 'LrApplication'
local LrFunctionContext = import 'LrFunctionContext'
local LrLogger          = import 'LrLogger'
local LrPathUtils       = import 'LrPathUtils'

-- Load the External Modules via 'dofile'
local extern = LrPathUtils.child( _PLUGIN.path, "external")
local persistence = dofile(LrPathUtils.child( LrPathUtils.child( extern, "lua-table-persistence" ), 'persistence.lua'))

-- Initialize the logger
local logger = LrLogger( 'PMIUtil' )
logger:enable("print") -- "print" or "logfile"

--[[
    Define this module
]]-- 
local PMIUtil = {}

--[[
    Saves a Tableto a files
]]--
function PMIUtil.Save(filename, data)
    if (persistence) then
        persistence.store(filename, data);    
    end
end

--[[
    Creates a Table from a file
]]--
function PMIUtil.Load(filename)
    return persitence and persistence.load(filename) or nil
end

--[[
    Returns the i'th result from a function that returns multiple result
]]--
function PMIUtil.Select(index, default, ...) 
    return arg[index] and arg[index] or default
end

--[[
    Splits a string into a table
    credit: http://richard.warburton.it
]]--
function PMIUtil.Explode(div,str) 
    if (div=='') then return false end
    local pos,arr = 0,{}
    -- for each divider found
    for st,sp in function() return string.find(str,div,pos,true) end do
        table.insert(arr,string.sub(str,pos,st-1)) -- Attach chars left of current divider
        pos = sp + 1 -- Jump past current divider
    end
    table.insert(arr,string.sub(str,pos)) -- Attach chars right of last divider
    return arr
end

--[[
    'Map' function
    credit: http://lua-users.org/wiki/FunctionalLibrary
--]]
function PMIUtil.Map(values, predicate)
    predicate = predicate or function(val) return val end
    local newvalues = {}
    for i,v in pairs(values) do
        newvalues[i] = predicate(v)
    end
    return newvalues
end

--[[
    'Filter' function
    credit: http://lua-users.org/wiki/FunctionalLibrary
--]]
function PMIUtil.Filter(values, predicate, isarray)
    isarray   = isarray or true
    predicate = predicate or function(val) return true end
    filter    = isarray and function(t, k, v) table.insert(t, v) end or function(t, k, v) t[k] = v end

    local newvalues = {}
    for k,v in pairs(values) do
        if predicate(v) then
            filter(newvalues, k,v)
        end
    end
    return newvalues
end

--[[
    Evaluates a table and returns true if a single successful evaluation
]]--
function PMIUtil.Any(values, predicate) 
    predicate = predicate or function(val) return true end
    for _,v in ipairs(values) do
        if predicate(v) then
            return true
        end
    end
    return false
end

--[[
    Evaluates a table and returns true if all are successful evaluations
]]--
function PMIUtil.All(table, predicate) 
    predicate = predicate or function(val) return true end
    for _,v in table do
        if not predicate(v) then
            return false
        end
    end
    return true
end

--[[
    Resolves a Path into a Lightroom Collection Set
]]--
function PMIUtil.GetCollectionSet(path)
    return LrFunctionContext.callWithContext( "PMIUtil.GetCollectionSet", function(context)
        local set = nil
        if path ~= nil then 
            local root = LrPathUtils.parent(path)
            local name = LrPathUtils.leafName(path)
            if root ~= nil then
                local parent = PMIUtil.GetCollectionSet(root, withWriteAccess)
                local catalog = LrApplication.activeCatalog()
                catalog:withWriteAccessDo( "Creating Collection Set" ,  function( context ) 
                    set = catalog:createCollectionSet(name, parent, true);
                end)
            end
        end
        return set
    end)
end

--[[
    Resolves a Collection Set to a Path
]]--
function PMIUtil.GetCollectionSetPath(set)
    return LrFunctionContext.callWithContext( "PMIUtil.GetCollectionSetPath", function(context)
        if set == nil then
            return LrPathUtils.child(" ", "")
        else
            return LrPathUtils.child(PMIUtil.GetCollectionSetPath(set:getParent()),  set:getName())
        end
    end)
end

--[[
    Return the module
]]--
return PMIUtil
