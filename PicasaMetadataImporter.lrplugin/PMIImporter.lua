--[[----------------------------------------------------------------------------

--------------------------------------------------------------------------------

PMIImporter.lua
Imports data from the PMIDatabase into Lightroom

--------------------------------------------------------------------------------

Copyright 2010-2012, D. Barsam
You may use this script for any purpose, as long as you include this notice in
any versions derived in whole or part from this file.  

See 'https://github.com/dbarsam/lightroom-picasametadataimporter' for more info.
 
----------------------------------------------------------------------------]]--

-- Access the Lightroom SDK namespaces.
local LrPathUtils       = import 'LrPathUtils'
local LrApplication     = import 'LrApplication'
local LrProgressScope   = import 'LrProgressScope'
local LrFunctionContext = import 'LrFunctionContext'
local LrDialogs         = import 'LrDialogs'
local LrView            = import 'LrView'
local LrBinding         = import 'LrBinding'
local LrLogger          = import 'LrLogger'

-- Initialize the logger
local logger = LrLogger( 'PMIImporter' )
logger:enable("print") -- "print" or "logfile"

-- Access the PMI SDK namespaces.
local pmiUtil         = require "PMIUtil"

--[[
    Define this module
]]-- 
local PMIImporter = {}

--[[
    Save the Import Report to file
]]-- 
local function saveReport(lines)
    local path = LrDialogs.runSavePanel {
        title = LOC '$$$/PMI/Importer/SaveDialog/Title=<Title>',
        label = LOC '$$$/PMI/Importer/SaveDialog/Label=<Label>',
        requiredFileType = 'txt',
        canChooseFiles = true,
        canChooseDirectories = false,
        canCreateDirectories = true,
        allowsMultipleSelection = false,
    }
    if path ~= nil then
        local createFile = assert(io.open(path,"w+"))
        createFile:write(table.concat(lines, '\n'))
        createFile:close()
    end        
end

--[[
    Display the Import Report on screen
]]-- 
local function showReportDialog(lines)

    return LrFunctionContext.callWithContext( 'showReportDialog', function( context )

        local f = LrView.osFactory()

        local rows = {
            spacing = f:label_spacing(),
            font = '<system/small>',
        }
        for _, l in ipairs(lines) do
            if  l:match('^\t+') ~= nil then
                local margin = (30 * pmiUtil.Select(2, 0, l:find('^\t+'))) 
                table.insert(rows, f:row { margin_horizontal = margin, f:static_text { title = l:gsub('^\t+', '') }})
            else
                table.insert(rows, f:row { f:static_text { title = l } })
            end
        end

        -- Create the contents for the dialog.
        local c = f:column {
            spacing = f:dialog_spacing(),
            f:static_text{
                title = LOC '$$$/PMI/Importer/Message/Title=<Message>',
                font = '<system/bold>',
                enabled = e,
            },
             f:static_text{
                title = LOC '$$$/PMI/Importer/Message/Body=<Body>',
                font = '<system>',
                enabled = e,
            },
            f:scrolled_view {
                fill_horizonal = 1,
                font = '<system/small>',
                width = 700,            
                height = 580,            
                f:column ( rows )
            }
        }

        -- Create the accessory view for the dialog.
        local a = f:row {
            f:push_button {
                title = LOC '$$$/PMI/Importer/Accessory/Action=<Action>',
                tooltip = LOC '$$$/PMI/Importer/Accessory/Tip=<Tip>',
                action = function() saveReport(lines) end,
            },           
        }

        -- Launch the actual dialog...
        local dialogResult = LrDialogs.presentModalDialog {
            title = LOC '$$$/PMI/Importer/Title=<Title>',
            contents = c,
            accessoryView = a,
            resizable = false,
            actionVerb = LOC '$$$/PMI/Importer/Action=<Action>',
            cancelVerb = '< exclude >'
        }        
    end)
end

--[[
    Writes a subset of the PMI Database to Lightroom
]]-- 
function PMIImporter.Import(database, filter)
    local report = {}

    local catalog = LrApplication.activeCatalog ()
    pscope = LrProgressScope( {title = LOC('$$$/PMI/Importer/Import/ProgressScope=<ProgressScope>')} )
    pscope:setCancelable(true)

    LrFunctionContext.callWithContext( "PMIImporter.Import", function(context)
        context:addCleanupHandler(function()
            pscope:cancel()
        end)

        -- Process the album filters 
        if (filter['Album'] ~= nil) then
            local i = 0
            for dkey, rkeys in pairs(filter['Album']) do
                i = i + 1
                pscope:setPortionComplete(i, filter['Album_Count'])
                pscope:setCaption(dkey);

                local info = database.MetaData[dkey]
                local collection = info.lr.id ~= nil and catalog:getCollectionByLocalIdentifier( info.lr.id ) or nil
                local localreport = {}

                -- Handling the 'name' rule as a special case
                if rkeys['name'] ~= nil then
                    local name = rkeys['name'].value
                    catalog:withWriteAccessDo( 'Creating Collection', function( context )
                        if collection == nil then
                            collection = catalog:createCollection( name, nil, true )
                            table.insert(localreport, '\t' .. LOC('$$$/PMI/Importer/Report/Collection/Created=<Created>'))
                        elseif collection:getName() ~= name then
                            table.insert(localreport, '\t' .. LOC("$$$/PMI/Importer/Report/Collection/Renamed=<Renamed>", tostring(collection:getName()), tostring(name)))
                            collection:setName(name);
                        end
                    end)
                end

                -- Handling the 'path' rule as a special case
                if rkeys['path'] ~= nil and collection ~= nil then
                    local name = collection:getName();
                    local path = rkeys['path'].value
                    local newpath = pmiUtil.GetCollectionSet(path)
                    local curpath = collection ~= nil and collection:getParent() or nil
                    if not ((curpath == nil and newpath == nil) or (curpath ~= nil and newpath ~= nil and newpath.localIdentifier == curpath.localIdentifier)) then
                        table.insert(localreport, '\t' .. LOC("$$$/PMI/Importer/Report/Collection/Moved=<Moved>", pmiUtil.GetCollectionSetPath(curPath), tostring(path)))
                        catalog:withWriteAccessDo( 'Moving to Collection Set', function( context )
                            collection:setParent(newpath)
                        end)
                    end
                end

                -- Handling the 'files' rule as a special case
                if rkeys['keys'] ~= nil and collection ~= nil then
                    local files = {}
                    local name = collection:getName();
                    for i, k in ipairs(rkeys['keys']) do
                        if k.lr.id ~= nil then
                            local file = catalog:findPhotoByUuid(k.lr.id)
                            if file ~= nil then
                                table.insert(localreport, '\t' .. LOC("$$$/PMI/Importer/Report/Collection/AddedFile=<AddedFile>", tostring(k.pc.name)))
                                table.insert(files, file)
                            end
                        end
                    end
                    catalog:withWriteAccessDo( 'Adding Photos to Collection', function( context )
                        collection:addPhotos(files)
                    end)
                end

                -- Merge the local report into the master report
                if #localreport > 0 then
                    table.insert(report, LOC("$$$/PMI/Importer/Report/Collection/Title=<Title>", tostring(collection:getName())))
                    for _, line in ipairs(localreport) do
                        table.insert(report, line)
                    end
                end
            end
        end

        -- Process the file filters 
        if (filter['File'] ~= nil) then
            local i = 0
            for dkey, rkeys in pairs(filter['File']) do
                i = i + 1
                pscope:setPortionComplete(i, filter['File_Count'])
                pscope:setCaption(dkey);

                local info = database.MetaData[dkey]
                local photo = info.lr.id ~= nil and catalog:findPhotoByUuid(info.lr.id) or nil
                local localreport = {}

                if photo ~= nil then
                    local fMetadata = photo:getFormattedMetadata()
                    local rMetadata = photo:getRawMetadata()
                    for k, v in pairs(rkeys) do
                        local oldvalue = fMetadata[k] and fMetadata[k] or rMetadata[k]
                        table.insert(localreport, '\t' .. LOC("$$$/PMI/Importer/Report/File/Property", tostring(k), tostring(oldvalue), tostring(v.value)))
                        catalog:withWriteAccessDo( 'Adding Photos to Collection', function( context )
                            photo:setRawMetadata( k, v.value )
                        end)
                    end
                end

                -- Merge the local report into the master report
                if #localreport > 0 then
                    table.insert(report, '\t' .. LOC("$$$/PMI/Importer/Report/File/Property=<Property>", tostring(info.pc.name)))
                    for _, line in ipairs(localreport) do
                        table.insert(report, line)
                    end
                end

            end
        end

    end)
    pscope:done()

    -- Show a Report Dialog
    if #report > 0 then
        showReportDialog(report)
    end
end

--[[
    Return the module
]]--
return PMIImporter
