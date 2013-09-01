--[[----------------------------------------------------------------------------

--------------------------------------------------------------------------------

PMIDatabase.lua
The Picasa Metadata container.

--------------------------------------------------------------------------------

Copyright 2010-2012, D. Barsam
You may use this script for any purpose, as long as you include this notice in
any versions derived in whole or part from this file.  

See 'https://github.com/dbarsam/lightroom-picasametadataimporter' for more info.
 
----------------------------------------------------------------------------]]--

-- Access the Lightroom SDK namespaces.
local LrApplication     = import 'LrApplication'
local LrDialogs         = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrLogger          = import 'LrLogger'
local LrProgressScope   = import 'LrProgressScope'
local LrTasks           = import 'LrTasks'

-- Initialize the logger
local logger = LrLogger( 'PMIDatabase' )
logger:enable("print")  -- "print" or "logfile"

-- Access the PMI SDK namespaces.
local pmiPrefs    = require "PMIPreferenceManager"
local pmiMetadata = require "PMIMetadata"
local pmiUtil     = require "PMIUtil"

--[[
    Define this module
]]-- 
local PMIDatabase = {}

--[[
    Saves the Database to a files
]]--
function PMIDatabase.Save(filename)
    if filename ~= nil then
        local data = {}
        data.version = 1
        data.ft = PMIDatabase.FileTable
        data.it = PMIDatabase.MetaData
        pmiUtil.Save(filename, data)
    else
        local path = LrDialogs.runSavePanel {
            title = LOC '$$$/PMI/Database/SaveDialog/Title=<Title>',
            label = LOC '$$$/PMI/Database/SaveDialog/Label=<Label>',
            requiredFileType = 'lua',
            canChooseFiles = true,
            canChooseDirectories = false,
            canCreateDirectories = true,
            allowsMultipleSelection = false,
        }
        if path ~= nil then
            PMIDatabase.Save(path)
        end        
    end
end

--[[
    Query the Database's state
]]--
function PMIDatabase.IsEmpty()
    return PMIDatabase.MetaData == nil or next(PMIDatabase.MetaData) == nil
end

--[[
    Populates the Database from a file
]]--
function PMIDatabase.Load(filename)
    local data = pmiUtil.Load(filename);
    if data ~= nil and data.version == 1 then
        PMIDatabase.FileTable = data.ft
        PMIDatabase.MetaData = data.it
    end
    return not PMIDatabase.IsEmpty()
end

--[[
    Returns a Table of Files that match the Picasa Album token
--]]
local function ResolveAlbumFiles(token)
    result = {}
    for k, v in pairs(PMIDatabase.MetaData) do 
        if v.pmi.category == 'file' and v.pc.albums ~= nil and v.pc.albums:match(token) then
            table.insert(result,k)
        end
    end
    return result
end

--[[
    Finds a collection by name.
--]]
local function ResolveCollection(name, collections)
    return LrFunctionContext.callWithContext( "PMIDatabase.ResolveCollection", function(context)
        for i, c in ipairs(collections) do
            if string.find(c:getName(), name) then
                return c
            end
        end       
        return nil
    end)
end

--[[
    Imports data from a list of picasa.ini files
--]]
function PMIDatabase.Import(files)

    -- Tables of the Database
    PMIDatabase.FileTable = files    
    PMIDatabase.MetaData = {}

    pscope = LrProgressScope( {title = LOC('$$$/PMI/Database/Import/ProgressScope=<ProgressScope>')} )
    pscope:setCancelable(true)

    LrFunctionContext.callWithContext( "PMIDatabase.Import", function(context)
        context:addCleanupHandler(function()
            pscope:cancel()
        end) 

        -- Cache to work around multiply-referenced albums
        local albums = {}

        -- Process the List of Picasa.ini
        for i,f in ipairs(PMIDatabase.FileTable) do

            pscope:setPortionComplete(i, #PMIDatabase.FileTable)
            pscope:setCaption(f);

            local entry = nil
            local lines = {}
            for line in io.lines(f) do 
                table.insert(lines, line) 
            end

            for i,l in ipairs(lines) do 
                if pscope:isCanceled() then
                    PMIDatabase.MetaData = {}
                    break
                end

                -- Header
                header = l:match("^%[(.*)%]$")
                if header then
                    -- Process Picasa keywords first
                    if header == "Picasa" then
                        entry = nil
                    elseif header == "Contacts" then
                        entry = nil
                    else
                        -- Album or File and start a new entry with quasi unique key
                        local hkey = string.gsub(f .. header, '%W', '')

                        -- Albums can be referenced in multiple files. Use the first file as the databse key
                        local album = header:match("^%.album:(.*)$")
                        if album ~= nil then
                            if albums[album] == nil then
                                albums[album] = hkey
                            else
                                hkey = albums[album]
                            end
                        end

                        -- Get a Database Entry
                        if PMIDatabase.MetaData[hkey] == nil then
                            PMIDatabase.MetaData[hkey] = {
                                pmi = {},
                                pc  = {},
                                lr  = {},
                            }
                        end
                        entry = PMIDatabase.MetaData[hkey]

                        -- Save the ini file for debugging
                        if entry.pmi.inifile == nil then
                            entry.pmi.inifile = {}
                        end
                        table.insert(entry.pmi.inifile, f)

                        -- Populate the remainder fields
                        if album then
                            entry.pc.path = ''
                            entry.pmi.category = 'album'
                        else
                            entry.pc.name = header
                            entry.pmi.category = 'file'
                        end                    
                    end
                elseif entry then
                    local key,value = l:match("^([^=]*)=(.*)$")
                    if key and value then
                        entry.pc[key] = value
                        --Split the 'filters' into separate metadata tokens
                        if key == 'filters' then
                            for _, filter in ipairs(pmiUtil.Explode(';', value)) do
                                local fkey,fvalue = filter:match("^([^=]*)=(.*)$")
                                if fkey and fvalue then
                                    entry.pc[fkey] = fvalue
                                end
                            end
                        end
                    end
                end
                LrTasks.yield()
            end
        end

    end)
    pscope:done()

    return not PMIDatabase.IsEmpty()
end

--[[ 
    Synchronises the database to Lightroom's internal database
        * Match the Picasa Album to the Lightroom Collection
        * Match the Picasa Files to the Picasa Album
        * Match the Picasa File to the Lightroom File
        * Apply the User's Import Templates
]]--
function PMIDatabase.Resolve()
    pscope = LrProgressScope( {title = string.format("%s %s %s...", LOC '$$$/PMI/Database/Resolve/ProgressScope=<ProgressScope>', LOC '$$$/PMI/Misc/PicasaOrLightroom=<PicasaOrLightroom>', LOC '$$$/PMI/Misc/Information=<Information>') } )
    pscope:setPortionComplete(0, #PMIDatabase.MetaData)

    LrFunctionContext.callWithContext( "PMIDatabase.Resolve", function(context)
        context:addCleanupHandler(function()
            pscope:cancel()
        end) 
        local catalog = LrApplication.activeCatalog ()
        local collections = catalog:getChildCollections()

        -- Get the User's Preferences
        local tokens = {
            album = pmiMetadata.GetTemplateTokens('album'),
            file  = pmiMetadata.GetTemplateTokens('file')
        }

        -- Temp table to match 'name' to entry instead of key to entry.
        local filelookup = {}

        -- Temp table for Lightroom's findPhotos call.  It's cheaper to do a
        -- single union findPhotos operation than multiple individual ones
        local sd = {}

        local i = 0
        for k, v in pairs(PMIDatabase.MetaData) do 
            i = i+1
            pscope:setPortionComplete(i, #PMIDatabase.MetaData)
            if (v.pmi.category == 'album') then
                pscope:setCaption(string.format("%s %s %s...", LOC '$$$/PMI/Database/Resolve/ProgressScope=<ProgressScope>', LOC '$$$/PMI/Misc/Album=<Album>', v.pc.name))
            elseif (v.pmi.category == 'file') then
                pscope:setCaption(string.format("%s %s %s...", LOC '$$$/PMI/Database/Resolve/ProgressScope=<ProgressScope>', LOC '$$$/PMI/Misc/File=<File>', v.pc.name))
            end

            v.lr.rules = {}
            for pck, pcv in pairs(v.pc) do 
                local rule = pmiPrefs.GetRule(v.pmi.category, pck)
                if rule ~= nil and rule.name ~= nil then
                    local keytype  = pmiMetadata.LrType[v.pmi.category][rule.name]

                    -- if it is an enum, the template will be a list of templates;
                    -- replace it with the corresponding one to our value
                    if pmiMetadata.PcEnumValues[pck] ~= nil then
                        rule.template = pmiPrefs.GetPref(rule.template[pcv])
                    end

                    if pmiMetadata.LrEnumValues[rule.name] ~= nil then
                        rule.value = rule.template
                    elseif keytype == 'collectionSet' then
                        if rule.template ~= nil then
                            rule.value = tostring(rule.template.path)
                        else
                            rule.value = pmiUtil.GetCollectionSetPath(nil)
                        end
                    elseif keytype == 'string' then
                        rule.value = pmiMetadata.ResolveTemplate(rule.template, tokens[v.pmi.category], v.pc)
                    elseif keytype == 'number' then
                        rule.value = pmiMetadata.ResolveConverter(rule.template, pcv)
                    end

                    v.lr.rules[pck] = rule
                end
            end

            if v.pmi.category == 'album' then
                -- Find the Lightroom Equivalents 
                v.lr.id = nil
                if v.lr.rules.name ~= nil then
                    local collection = ResolveCollection(v.lr.rules.name.value, collections)
                    v.lr.id = v.lr.collection and v.lr.collection.localIdentifier or nil
                end
                if v.lr.rules.name ~= nil then
                    local collection = ResolveCollection(v.lr.rules.name.value, collections)
                    v.lr.id = v.lr.collection and v.lr.collection.localIdentifier or nil
                end            
                -- Find the Files in Album
                v.pmi.files = ResolveAlbumFiles(v.pc.token)
            elseif v.pmi.category == 'file' then
                filelookup[v.pc.name] = v
                table.insert(sd, {criteria = 'filename', operation = 'beginsWith', value = v.pc.name, value2 = "",})
            end
        end

        if #sd > 0 then
            i = 0
            sd.combine = 'union'
            pscope:setPortionComplete(0, #PMIDatabase.MetaData)
            pscope:setCaption(LOC('$$$/PMI/Database/Resolve/Querying=<Querying>'));
            local files = catalog:findPhotos { searchDesc = sd }
            for i,p in ipairs(files) do 
                local name = p:getFormattedMetadata("fileName")
                local entry = filelookup[name]

                i = i+1
                pscope:setPortionComplete(i, #files)
                pscope:setCaption(string.format('%s %s...', LOC '$$$/PMI/Database/Resolve/ProgressScope=<ProgressScope>', name))

                if entry ~= nil then
                    entry.lr.id = p:getRawMetadata("uuid")
                    if p:getRawMetadata("isVideo") then
                        entry.lr.category = 'video'
                    else
                        entry.lr.category = 'image'
                    end
                end
            end
        end
    end)
    pscope:done()

    return not PMIDatabase.IsEmpty()
end

--[[
    Function to Query the table
]]--
function PMIDatabase.Query(category, product, key, default)
    value = default
    local entry = PMIDatabase.MetaData[category]
    if entry ~= nil then
        product = entry[product]
        if product ~= nil then
            value = product[key]
            if value ~= nil then
                value = default;
            end
        end
    end
end

--[[
    Function to return the back filtered keys
    Note:
        'album' category keys are picasa date
        'file'  category keys are sorted by file name
]]--
function PMIDatabase.GetFilteredKeys(categories)
    local keys = {}
    for _, c in pairs(categories) do
        keys[c] = {}
    end
    for k, v in pairs(PMIDatabase.MetaData) do
        if keys[v.pmi.category] ~= nil then
            table.insert(keys[v.pmi.category], k)
        end
    end

    -- This is a hardcoded sort
    if keys.album ~= nil then
        table.sort(keys.album, function(l,r) 
            return PMIDatabase.MetaData[l].pc.date ~= nil and PMIDatabase.MetaData[r].pc.date ~= nil and PMIDatabase.MetaData[l].pc.date > PMIDatabase.MetaData[r].pc.date 
        end)
    end
    if keys.file ~= nil then
        table.sort(keys.file, function(l,r) 
            return PMIDatabase.MetaData[l].pc.name ~= nil and PMIDatabase.MetaData[r].pc.name ~= nil and PMIDatabase.MetaData[l].pc.name:lower() > PMIDatabase.MetaData[r].pc.name:lower()
        end)
    end

    return keys
end

--[[
    Return the module
]]--
return PMIDatabase
