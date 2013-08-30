--[[----------------------------------------------------------------------------

--------------------------------------------------------------------------------

PMISelectSourceDialog.lua
Displays the Import Picasa Metadata browse dialog

--------------------------------------------------------------------------------

Copyright 2010-2012, D. Barsam
You may use this script for any purpose, as long as you include this notice in
any versions derived in whole or part from this file.  

See 'https://github.com/dbarsam/lightroom-picasametadataimporter' for more info.
 
----------------------------------------------------------------------------]]--

-- Access the Lightroom SDK namespaces.
local LrBinding         = import 'LrBinding'
local LrDialogs         = import 'LrDialogs'
local LrFileUtils       = import 'LrFileUtils'
local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils       = import 'LrPathUtils'
local LrView            = import 'LrView'

-- Access the PMI SDK namespaces.
local pmiPrefs = require "PMIPreferenceManager"

-- Get The Plugin's Lightroom Preferences
local LrPrefs = pmiPrefs.GetPreferences()

--[[
    Define this module
]]--
local IPMSelectSourceDialog = {}

--[[
    Wrapper around thr SDK's Browse File Dialog - selects a folder file
]]--
local function selectPicasaPath(propertyTable)

    local paths = LrDialogs.runOpenPanel {
        title = LOC '$$$/PMI/SelectSourceDialog/SelectPicasaPath/Title=<Title>',
        label = LOC '$$$/PMI/SelectSourceDialog/SelectPicasaPath/Action=<Action>',
        canChooseFiles = false,
        canChooseDirectories = true,
        canCreateDirectories = false,
        allowsMultipleSelection = false,
        initialDirectory = propertyTable.sourcePath,
    }
    
    if paths ~= nil and #paths > 0 then
        propertyTable.sourcePath = paths[1]
    end
    
end

--[[
    Wrapper around the SDK's Browse File Dialog - selects a database file
]]--
local function selectDatabasePath(propertyTable)

    local paths = LrDialogs.runOpenPanel {
        title = LOC '$$$/PMI/SelectSourceDialog/SelectDatabasePath/Title=<Title>',
        label = LOC '$$$/PMI/SelectSourceDialog/SelectDatabasePath/Action=<Action>',
        requiredFileType = 'lua',
        canChooseFiles = true,
        canChooseDirectories = false,
        canCreateDirectories = true,
        allowsMultipleSelection = false,
        initialDirectory = propertyTable.sourcePath,
    }
    
    if paths ~= nil and #paths > 0 then
        propertyTable.sourcePath = paths[1]
    end
    
end

--[[
    Manages the list of recent data paths
]]--
local function sourcePathAdded(propertyTable, key, value)

    -- A 'clear recent paths' has a value of 'nil'
    if value == nil then
        propertyTable.sourcePath = ''
        propertyTable.sourcePaths = {}
    else
        local paths = propertyTable.sourcePaths
        
        -- Rebuild the menu...
        if paths == nil or #paths == 0 then
            paths = {
                { separator = true },
                { title = LOC '$$$/PMI/SelectSourceDialog/Clear=<Clear>', value = nil }
            }
        end
        
        -- Filter out duplicates
        local inList
        for i, v in ipairs( paths ) do
            if v == value then 
                inList = true 
                break
            end
        end
        if not inList then
            table.insert(paths, 1, value)
        end

        propertyTable.sourcePaths = paths 
    end
end

--[[
    Main 'Show' function of the IPMSelectSourceDialog
]]
function IPMSelectSourceDialog.Show()

    return LrFunctionContext.callWithContext( 'IPMSelectSourceDialog.Show', function( context )

        local f = LrView.osFactory()

        -- Create a bindable table and initialize with plug-in preferences
        local props = LrBinding.makePropertyTable( context )
        props.isRecursive = LrPrefs.IsRecursive
        props.sourcePath = LrPrefs.SourcePath
        props.sourcePaths = LrPrefs.SourcePaths
        props.dataFile = 'picasa.ini'

        -- Add an observer of the recent paths property.
        props:addObserver( 'sourcePath', sourcePathAdded )

        -- Create the contents for the dialog.
        local c = f:column {
            spacing = f:control_spacing(),
            bind_to_object = props,
            f:row {
                spacing = f:label_spacing(),
                f:static_text {
                    title = LOC '$$$/PMI/SelectSourceDialog/ImportPath=<ImportPath>',
                    alignment = 'right',
                    width = LrView.share 'label_width',
                }, 
                f:popup_menu {
                    value = LrView.bind 'sourcePath',
                    items = LrView.bind 'sourcePaths',
                    tooltip = LOC '$$$/PMI/SelectSourceDialog/Path/Tip=<Tip>',
                    immediate = true,
                    width_in_chars = 30,            
                },
                f:push_button {
                    title = LOC '$$$/PMI/SelectSourceDialog/Path/Action=<Action>',
                    tooltip = LOC '$$$/PMI/SelectSourceDialog/Path/Tip=<Tip>',
                    action = function() selectPicasaPath(props) end,
               },         
            }, 
            f:row {
                spacing = f:label_spacing(),
                f:static_text {
                    title = '',
                    alignment = 'right',
                    width = LrView.share 'label_width' ,
                }, 
                f:checkbox {
                    fill_horizonal = 1,
                    title = LOC '$$$/PMI/SelectSourceDialog/SubFolders/Action=<Action>',
                    tooltip = LOC '$$$/PMI/SelectSourceDialog/SubFolders/Tip=<Tip>',
                    value = LrView.bind 'isRecursive',
                    enabled = LrView.bind {
                        key = 'sourcePath',
                        transform = function(value, fromTable) 
                            return value ~= nil and value ~= '' and LrPathUtils.extension(value) == ''
                        end 
                    },
                },         
            },
        }

        -- Create the accessory view for the dialog.
        local a = f:row {
            f:push_button {
                    title = LOC '$$$/PMI/SelectSourceDialog/OpenDatabase/Action=<Action>',
                    tooltip = LOC '$$$/PMI/SelectSourceDialog/OpenDatabase/Tip=<Tip>',
                    action = function() selectDatabasePath(props) end,
               },           
           }

        -- Launch the actual dialog...
        local dialogResult = LrDialogs.presentModalDialog {
            title = LOC '$$$/PMI/SelectSourceDialog/Title=<Title>',
            accessoryView = a,
            contents = c,
            actionVerb = LOC '$$$/PMI/SelectSourceDialog/Action=<Action>',
        }

        -- Process a succesful browse
        if dialogResult == 'ok' then
            -- Store the Path only upon success
            LrPrefs.SourcePaths = props.sourcePaths
            LrPrefs.SourcePath = props.sourcePath
            LrPrefs.IsRecursive = props.isRecursive
            LrPrefs.DataFile = props.dataFile

            local result = {}
            result.files = {}
            local exists = LrFileUtils.exists( props.sourcePath )
            if exists then
                result.isImport = (exists == 'directory')
                result.isLoad   = not result.isImport
                if result.isImport then
                    files = props.isRecursive and LrFileUtils.recursiveFiles( props.sourcePath ) or LrFileUtils.files( props.sourcePath )
                    for file in files do
                        if file:match(props.dataFile) then
                            table.insert(result.files, file)
                        end
                    end    
                else
                    table.insert(result.files, props.sourcePath)
                end

                -- Return our results
                return result
            end
        end

        return nil

    end ) -- end main function
    
end

--[[
    Return the module
]]--
return IPMSelectSourceDialog

