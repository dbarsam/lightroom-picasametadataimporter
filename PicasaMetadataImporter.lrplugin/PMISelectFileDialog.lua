--[[----------------------------------------------------------------------------

--------------------------------------------------------------------------------

PMISelectFileDialog.lua
Displays the Select Lightroom File dialog

--------------------------------------------------------------------------------

Copyright 2010-2012, D. Barsam
You may use this script for any purpose, as long as you include this notice in
any versions derived in whole or part from this file.  

See 'https://github.com/dbarsam/lightroom-picasametadataimporter' for more info.
 
----------------------------------------------------------------------------]]--

-- Access the Lightroom SDK namespaces.
local LrApplication     = import 'LrApplication'
local LrProgressScope   = import 'LrProgressScope'
local LrBinding         = import 'LrBinding'
local LrDialogs         = import 'LrDialogs'
local LrFileUtils       = import 'LrFileUtils'
local LrTasks           = import 'LrTasks'
local LrLogger          = import 'LrLogger'
local LrFunctionContext = import 'LrFunctionContext'
local LrPathUtils       = import 'LrPathUtils'
local LrView            = import 'LrView'

-- Initialize the logger
local logger = LrLogger( 'PMISelectFileDialog' )
logger:enable("print")  -- "print" or "logfile"

-- Access the PMI SDK namespaces.
local pmiPrefs = require "PMIPreferenceManager"
local pmiUtil  = require "PMIUtil"

-- Get The Plugin's Lightroom Preferences
local LrPrefs = pmiPrefs.GetPreferences()

--[[
    Define this module
]]--
local PMISelectFileDialog = {}

--[[
    Observer for the searchText changed event
]]--
local function searchTextChanged(propertyTable, key, val)

    LrFunctionContext.postAsyncTaskWithContext('searchTextChanged', function(context)
        LrDialogs.attachErrorDialogToFunctionContext(context)    

        local catalog = LrApplication.activeCatalog()

        local pscope = LrDialogs.showModalProgressDialog({
            title = "Doing something",
            cannotCancel = false,
            functionContext = context
        })        

        context:addCleanupHandler(function()
            pscope:cancel()
        end)  

        LrTasks.sleep( 0.1 )            

        if propertyTable.searchText == nil or propertyTable.searchText == "" or propertyTable.searchOperation == nil or propertyTable.searchOperation == "" then
            propertyTable.searchText = ''
            propertyTable.fileMatches = {}
        else
            pscope:setPortionComplete(0, 1)
            pscope:setCaption(LOC('$$$/PMI/SelectFileDialog/ProgressDialog/Querying=<Querying>'));
            local files = catalog:findPhotos {
                searchDesc = {
                    {
                        criteria = "filename",
                        operation = propertyTable.searchOperation,
                        value = propertyTable.searchText,
                        value2 = "",
                    },
                    combine = "intersect",
                }
            }
            local matches = {}

            pscope:setCaption(LOC('$$$/PMI/SelectFileDialog/ProgressDialog/ProcessingResults=<ProcessingResults>'));
            for i = 1,#files do
                local p = files[i]
                if pscope:isCanceled() then
                    return nil
                end 
                pscope:setPortionComplete(i, #files)
                matches[#matches+1] = {title = p:getFormattedMetadata("fileName"), value = p}
            end

            propertyTable.fileMatches = matches 
        end
        pscope:done()
    end)
end

--[[
    Main 'Show' function of the PMISelectFileDialog
]]
function PMISelectFileDialog.Show(initialText)

    return LrFunctionContext.callWithContext( 'PMISelectFileDialog.Show', function( context )

        local f = LrView.osFactory()

        -- Create a bindable table and initialize with plug-in preferences
        local propertyTable = LrBinding.makePropertyTable( context )

        -- Add an observer of the recent paths property.
        propertyTable.fileMatch = {}
        propertyTable.fileMatches = nil
        propertyTable.searchText = initialText or ""
        propertyTable.searchOperation = "all"

        -- Create the contents for the dialog.
        local c = f:column {
            spacing = f:control_spacing(),
            bind_to_object = propertyTable,
            f:row {
                spacing = f:label_spacing(),
                f:static_text {
                    title = LOC '$$$/PMI/SelectFileDialog/SearchText=<SearchText>',
                    alignment = 'right',
                    width = LrView.share 'label_width',
                },
                f:edit_field {
                    fill_horizontal  = 1,
                    immediate = true,
                    value = LrView.bind 'searchText',
                },
                f:push_button {
                    title = LOC '$$$/PMI/SelectFileDialog/Search/Action=<Action>',
                    tooltip = LOC '$$$/PMI/SelectFileDialog/Search/Tip=<Tip>',
                    enabled = LrView.bind  
                    {
                        key = 'searchText',
                        transform = function(value, fromTable)
                            return value ~= nil and value ~= ""
                        end
                    },
                    action = function() searchTextChanged(propertyTable, 'searchText', propertyTable.searchText) end,
               }, 
 
            }, 
            f:row {
                f:static_text {
                    title = LOC '$$$/PMI/SelectFileDialog/SearchOptions=<SearchOptions>',
                    alignment = 'right',
                    width = LrView.share 'label_width',
                },                
                f:popup_menu {
                    fill_horizontal = 1,
                    value = LrView.bind 'searchOperation',
                    items = {
                        { title = LOC '$$$/PMI/SelectFileDialog/SearchOp/ContainingAny=<contains>', value = "any" },
                        { title = LOC '$$$/PMI/SelectFileDialog/SearchOp/ContainingAll=<containsall>', value = "all" },
                        { title = LOC '$$$/PMI/SelectFileDialog/SearchOp/NotContaining=<doesn^}tContain>', value = "noneOf" },
                        { separator = true },
                        { title = LOC '$$$/PMI/SelectFileDialog/SearchOp/StartingWith=<startingwith>', value = "beginsWith" },
                        { title = LOC '$$$/PMI/SelectFileDialog/SearchOp/EndingWith=<endswith>', value = "endsWith" },
                    },
                    tooltip = LOC '$$$/PMI/SelectFileDialog/SearchOp/Tip=<Tip>',
                    enabled = LrView.bind  
                    {
                        key = 'searchText',
                        transform = function(value, fromTable)
                            return value ~= nil and value ~= ""
                        end
                    }                    
                },           
            },
            f:row {
                spacing = f:label_spacing(),
                f:static_text {
                    title = LOC '$$$/PMI/SelectFileDialog/SearchResults=<SearchResults>',
                    alignment = 'right',
                    width = LrView.share 'label_width' ,
                }, 
                f:simple_list {
                    fill_horizontal  = 1,
                    font = '<system/small>',
                    width = pmiPrefs.GetPref('ScrollViewWidth'),            
                    height = pmiPrefs.GetPref('ScrollViewHeight'),
                    value = LrView.bind 'fileMatch',
                    items = LrView.bind 'fileMatches',
                }                
            }
        }
        
        -- Launch the actual dialog...
        local dialogResult = LrDialogs.presentModalDialog {
            title = LOC '$$$/PMI/SelectFileDialog/Title=<Title>',
            contents = c,
            actionVerb = LOC '$$$/PMI/SelectFileDialog/Action=<Action>',
        }

        return dialogResult == 'ok' and propertyTable.fileMatch[1] or nil

    end ) -- end main function
    
end

--[[
    Return the module
]]--
return PMISelectFileDialog

