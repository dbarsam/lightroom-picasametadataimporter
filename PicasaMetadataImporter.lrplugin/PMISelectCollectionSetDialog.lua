--[[----------------------------------------------------------------------------

--------------------------------------------------------------------------------

PMICollectionSetDialog.lua
Displays the Collection CollectionSet Editor dialog

--------------------------------------------------------------------------------

Copyright 2010-2012, D. Barsam
You may use this script for any purpose, as long as you include this notice in
any versions derived in whole or part from this file.  

See 'https://github.com/dbarsam/lightroom-picasametadataimporter' for more info.
 
----------------------------------------------------------------------------]]--

-- Access the Lightroom SDK namespaces.
local LrApplication     = import 'LrApplication'
local LrFunctionContext = import 'LrFunctionContext'
local LrFileUtils       = import 'LrFileUtils'
local LrPathUtils       = import 'LrPathUtils'
local LrBinding         = import 'LrBinding'
local LrDialogs         = import 'LrDialogs'
local LrStringUtils     = import "LrStringUtils"
local LrView            = import 'LrView'
local LrRecursionGuard  = import 'LrRecursionGuard'
local LrLogger          = import 'LrLogger'

-- Initialize the logger
local logger = LrLogger( 'PMISelectionCollectionSetDialog' )
logger:enable("print") -- "print" or "logfile"
 
-- Access the PMI SDK namespaces.
local pmiUtil     = require 'PMIUtil.lua'

--[[
    Define this module
]]--
local PMICollectionSetDialog = {}

--[[
Returns data for the collection set popup_menu
]]
function GetCollectionSets(sets, t, depth)
    local indent = string.rep("  ", depth)
    if sets ~= nil then
        for _,set in ipairs(sets) do
            info = {
                id = set.localIdentifier,
                path = pmiUtil.GetCollectionSetPath(set),
                name = set:getName()
            }
            table.insert(t, {title = (indent .. set:getName()), value = info})
            GetCollectionSets(set:getChildCollectionSets(), t, depth + 1)
        end
    end
end

--[[
    Main 'Show' function of the PMICollectionSetDialog
]]
function PMICollectionSetDialog.Show(collectionset)

    return LrFunctionContext.callWithContext( 'PMICollectionSetDialog.Show', function( context )

        local catalog = LrApplication.activeCatalog ()
        local f = LrView.osFactory()
        local propertyTable = LrBinding.makePropertyTable( context )

        -- Generate the Collection Set List 
        propertyTable.collection_items = { 
            { 
                title = LOC '$$$/PMI/SelectCollectionSetDialog/Show/TopLevel=<TopLevel>', 
                value = 
                {
                    id = nil,
                    path = pmiUtil.GetCollectionSetPath(nil),
                    name = LOC '$$$/PMI/SelectCollectionSetDialog/Show/TopLevel=<TopLevel>'
                }
            }
        }
        GetCollectionSets(catalog:getChildCollectionSets(), propertyTable.collection_items, 0)

        -- Select the collection set
        currentId = (collectionset ~= nil) and collectionset.id or nil
        for _, i in ipairs(propertyTable.collection_items) do
            if i.value.id == currentId then
                propertyTable.collection_value = i.value
                break;
            end
        end

        -- Create the contents for the dialog.
        local c = f:column {
            spacing = f:label_spacing(),
            bind_to_object = propertyTable,
            font = '<system/small>',
            f:row {
                f:static_text {
                    title = LOC '$$$/PMI/SelectCollectionSetDialog/CollectionSet=<CollectionSet>',
                    alignment = 'right',
                    width = LrView.share 'label_width',
                },  
                f:popup_menu {
                    fill_horizontal = 1,
                    value = LrView.bind 'collection_value',
                    items = LrView.bind 'collection_items',
                    immediate = true,
                },
                --f:push_button {
                --    title = LOC '$$$/PMI/SelectCollectionSetDialog/Create/Title=<Title>',
                --    tooltip = LOC '$$$/PMI/SelectCollectionSetDialog/Create/Tip=<Tip>',
                --    enabled = LrView.bind 
                --    {
                --        key = 'collection_value',
                --        transform = function(value, fromTable)
                --            return value ~= nil 
                --        end,
                --    },
                --    action = function() 
                --        info = nil
                --        if info == nil then
                --            cv = collection_value
                --            collection_value = nil
                --            GetCollectionSets(catalog:getChildCollectionSets(), propertyTable.collection_items, 0)
                --            collection_value = cv
                --        end
                --    end,
                --},                
            },
            f:row {
                f:static_text {
                    title = LOC '$$$/PMI/SelectCollectionSetDialog/Path=<Path>',
                    alignment = 'right',
                    width = LrView.share 'label_width',
                },  
                f:static_text {
                    width_in_chars = 55,            
                    title = LrView.bind  
                    {
                        --keys = {collection_value},
                        --operation = function( binder, values, fromTable )
                        --    return values['collection_value']
                        --end,                                
                        key = 'collection_value',
                        transform = function(value, fromTable)
                            return value.path
                        end
                    }
                },                  
            },
--
--            f:row {
--                spacing = f:label_spacing(),
--                f:static_text {
--                    title = 'Metadata:',
--                    alignment = 'right',
--                    width = LrView.share 'label_width',
--                }, 
--                f:popup_menu {
--                    fill_horizontal = 1,
--                    value = LrView.bind 'template_value',
--                    items = LrView.bind 'template_items',
--                    tooltip = 'CollectionSet name...',
--                    immediate = true,
--                },
--                f:push_button {
--                    title = 'Insert',
--                    tooltip = 'Select the Lightroom Collection Set parent.',
--                    action = function() 
--                        propertyTable.template = propertyTable.template .. propertyTable.template_value 
--                    end,
--               },    
--            },             
        }

        -- Launch the actual dialog...
        local dialogResult = LrDialogs.presentModalDialog {
            title = LOC "$$$/PMI/SelectCollectionSetDialog/Title",
            contents = c,
            actionVerb = LOC '$$$/PMI/SelectCollectionSetDialog/Action=<Action>',
        }

        return dialogResult == 'ok' and propertyTable.collection_value or nil

    end ) -- end main function
    
end

--[[
    Return the module
]]--
return PMICollectionSetDialog

