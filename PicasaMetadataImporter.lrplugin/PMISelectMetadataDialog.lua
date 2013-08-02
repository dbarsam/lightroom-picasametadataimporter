--[[----------------------------------------------------------------------------

--------------------------------------------------------------------------------

PMISelectMetadataDialog.lua
Displays the Picasa Metadata Importer preview dialog.

--------------------------------------------------------------------------------

Copyright 2010-2012, D. Barsam
You may use this script for any purpose, as long as you include this notice in
any versions derived in whole or part from this file.  

See 'https://github.com/dbarsam/lightroom-picasametadataimporter' for more info.
 
----------------------------------------------------------------------------]]--

-- Access the Lightroom SDK namespaces.
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding         = import 'LrBinding'
local LrDialogs         = import 'LrDialogs'
local LrView            = import 'LrView'
local LrRecursionGuard  = import 'LrRecursionGuard'
local LrLogger          = import 'LrLogger'

-- Initialize the logger
local logger = LrLogger( 'PMISelectMetadataDialog' )
logger:enable('print') -- 'print' or 'logfile'

-- Access the PMI SDK namespaces.
local pmiMetadata            = require "PMIMetadata"
local pmiUtil                = require "PMIUtil"

--[[
    Recursion guard for selection
]]--
local recursionGuard = {
    ['header'] = LrRecursionGuard ("header"),
    ['item']   = LrRecursionGuard ("item"),
    ['rule']   = LrRecursionGuard ("rule")
}

--[[
    Define this module
]]--
local PMISelectMetadataDialog = {}

--[[
    Observer for the header checkbox.  
    - On change it will set the respective value to all its children (items)
]]--
local function headerSelected(propertyTable, key, value)
    recursionGuard.header:performWithGuard (function ()
        if value ~= nil then
            propkeys = pmiMetadata.MetadataKeys
            local regex = nil
            if key == propkeys.album.header then
                regex = propkeys.album.enabled
            elseif key == propkeys.file.header then
                regex = propkeys.album.enabled
            end

            if regex ~= nil then 
                for k,v in propertyTable:pairs() do
                    if k:match(regex) then
                        recursionGuard.item:performWithGuard (function ()
                            propertyTable[k] = value
                        end)
                    end
                end          
            end
        end
    end)
end

--[[
    Observer for the item checkbox.
    - On change it will set the respective value to all its children (rules)
    - On change it will set the parent state (header) based on the state of its siblings
]]--
local function itemSelected(propertyTable, key, value)
    local propkeys = nil
    if key:match(pmiMetadata.MetadataKeys.album.enabled) then
        propkeys = pmiMetadata.MetadataKeys.album
    elseif key:match(pmiMetadata.MetadataKeys.file.enabled) then
        propkeys = pmiMetadata.MetadataKeys.file
    end
    if value == nil then
        propertyTable[propkeys.header] = nil
    else
        recursionGuard.item:performWithGuard (function ()
            local pregex = string.gsub(propkeys.enabled,"%.%+", "([^_]+)")
            local itemkey = key:match(pregex)
            if itemkey ~= nil then
                local parent_value = value
                local cregex = string.gsub(propkeys.enabled,"%.%+", itemkey .."_([^_]+)")
                for k,v in propertyTable:pairs() do
                    if k:match(cregex) then
                        recursionGuard.rule:performWithGuard (function ()
                            propertyTable[k] = value
                        end)
                    end
                    if parent_value ~= nil and k ~= key and v~=value and k:match(pregex) then
                        parent_value = nil
                    end
                end
                recursionGuard.header:performWithGuard (function ()
                    propertyTable[propkeys.header] = parent_value
                end)
            end
        end)
    end
end

--[[
    Observer for the rule checkbox.
    - On change it will set the parent state (item) based on the state of its siblings
]]--
local function ruleSelected(propertyTable, key, value)
    recursionGuard.rule:performWithGuard (function ()
        local propkeys = nil
        if key:match(pmiMetadata.MetadataKeys.album.enabled) then
            propkeys = pmiMetadata.MetadataKeys.album
        elseif key:match(pmiMetadata.MetadataKeys.file.enabled) then
            propkeys = pmiMetadata.MetadataKeys.file
        end
        regex = string.gsub(propkeys.enabled,"%.%+", "([^_]+)_([^_]+)")
        pkey, ckey = key:match(regex)
        if pkey ~= nil and ckey ~= nil then
            regex = string.gsub(propkeys.enabled,"%.%+", pkey .. "_([^_]+)")
            local pvalue = value
            for k,v in propertyTable:pairs() do
                if k ~= key and v ~= value and k:match(regex) then
                    pvalue = nil
                    break
                end
            end                    
            recursionGuard.item:performWithGuard (function ()
                propertyTable[string.gsub(propkeys.enabled,"%.%+", pkey)] = pvalue
            end)
        end
    end)
end

--[[
    File Row
]]--
local function GetFileRow(f, rkey, rule, binding)
    return f:row {
        margin_horizontal = 30,
        f:checkbox {
            title = rkey,
            size = "mini",
            value = LrView.bind (binding),
            width = LrView.share "rkey_width",
            enabled = e,
        },            
        f:static_text {
            title = rule.name,
            size = "mini",
            width = LrView.share "rname_width",
            enabled = e,
        },
        f:static_text {
            title = rule.value,
            size = "mini",
            width = LrView.share "rvalue_width",
            enabled = e,
        },                         
    }                    
end

--[[
    File Row
]]--
local function GetFileRow(f, fkey, data, e, binding)
    return f:row {
        margin_horizontal = 30,
        f:checkbox {
            title = fkey,
            size = "mini",
            value = LrView.bind (binding),
            width = LrView.share "rkey_width",
            enabled = e,
        },            
        f:static_text {
            title = '...',
            size = "mini",
            width = LrView.share "rname_width",
            enabled = e,
        },
        f:static_text {
            title = data.pc.name,
            size = "mini",
            width = LrView.share "rvalue_width",
            enabled = e,
        },                         
    }                    
end

--[[
    Rule Row
]]--
local function GetRuleRow(f, rkey, rule, e, binding)
    return f:row {
        margin_horizontal = 30,
        f:checkbox {
            title = rkey,
            size = "mini",
            value = LrView.bind (binding),
            width = LrView.share "rkey_width",
            enabled = e,
        },            
        f:static_text {
            title = rule.name,
            size = "mini",
            width = LrView.share "rname_width",
            enabled = e,
        },
        f:static_text {
            title = rule.value,
            size = "mini",
            width = LrView.share "rvalue_width",
            enabled = e,
        },                         
    }                    
end

--[[
    The Album View
]]--
local function GetAlbumView(f, properties, keys, database)

    local propkeys = pmiMetadata.MetadataKeys.album

    properties[propkeys.header] = false
    properties:addObserver( propkeys.header, headerSelected )

    local view = {
        f:row {
            margin_horizontal = 10,
            spacing = f:label_spacing(),
            f:checkbox {
                title = LOC '$$$/PMI/SelectMetadataDialog/AlbumView/Header/Name=<Name>',
                size = 'small',
                value = LrView.bind(propkeys.header),
                font = '<system/small/bold>',
                width = LrView.share 'name_width',
            },                              
            f:static_text {
                title = LOC '$$$/PMI/SelectMetadataDialog/AlbumView/Header/Date=<Date>',
                font = '<system/small/bold>',
                width = LrView.share 'date_width',
            },                       
            f:static_text {
                title = LOC '$$$/PMI/SelectMetadataDialog/AlbumView/Header/Token=<Token>',
                font = '<system/small/bold>',
                width = LrView.share 'token_width',
            },             
        },               
    }

    for i,akey in ipairs(keys.album) do 
        local data = database.MetaData[akey]
        local abinding = string.gsub(propkeys.enabled,"%.%+", akey)
        properties[abinding] = false
        properties:addObserver(abinding, itemSelected)

        local albumRow = f:row {
            margin_horizontal = 10,
            f:checkbox {
                title = data.pc.name,
                size = "small",
                value = LrView.bind (abinding),
                width = LrView.share "name_width",
            }, 
            f:static_text {
                title = data.pc.date and data.pc.date or "",
                size = "small",
                width = LrView.share "date_width",
            },
            f:static_text {
                title = data.pc.token and data.pc.token or "",
                size = "small",
                width = LrView.share "token_width",
            },             
        }
        table.insert(view, albumRow)

        for rkey,rule in pairs(data.lr.rules) do      
            if rule.enabled then
                local rbinding = string.gsub(propkeys.enabled,"%.%+", akey .. "_" .. rkey) or 'nil'
                properties[rbinding] = false
                properties:addObserver(rbinding, ruleSelected)
                table.insert(view, GetRuleRow(f, rkey, rule, true, rbinding))
            end
        end   

        for _,fkey in ipairs(data.pmi.files) do      
            local idata = database.MetaData[fkey]
            local e = idata.lr.id ~= nil
            local ibinding = e and string.gsub(propkeys.enabled,"%.%+", akey .. "_" .. fkey) or 'nil'
            properties[ibinding] = false
            properties:addObserver(ibinding, ruleSelected)
            table.insert(view, GetFileRow(f, 'file', idata, e, ibinding))
        end

        local separator = f:row {
            margin_horizontal = 10,
            f:separator {
                fill_horizontal = 1,
            },
        }
        table.insert(view, separator)
    end

    return view
end

--[[
    The File View
]]--
local function GetFileView(f, properties, keys, database)
    local propkeys = pmiMetadata.MetadataKeys.file

    properties[propkeys.header] = false
    properties:addObserver( propkeys.header, headerSelected )

    local view = {    
        margin_horizontal = 10,
        spacing = f:label_spacing(),
        f:row {
            margin_horizontal = 10,
            f:checkbox {
                title = LOC '$$$/PMI/SelectMetadataDialog/FileView/Header/Name=<Name>',
                size = 'small',
                value = LrView.bind(propkeys.header),
                font = '<system/small/bold>',
                width = LrView.share 'name_width',
            },                              
            f:static_text {
                title = LOC '$$$/PMI/SelectMetadataDialog/FileView/Header/Album=<Album>',
                title = 'Picasa Album',
                font = '<system/small/bold>',
                width = LrView.share 'token_width',
            },
            f:static_text {
                title = LOC '$$$/PMI/SelectMetadataDialog/FileView/Header/Token=<Token>',
                font = '<system/small/bold>',
                width = LrView.share 'uuid_width',
            },                            
        },              
    }
    for i,fkey in ipairs(keys.file) do 
        local data = database.MetaData[fkey]
        local e = data.lr.id ~= nil
        local fbinding = e and string.gsub(propkeys.enabled,"%.%+", fkey) or 'nil'
        properties[fbinding] = false
        properties:addObserver(fbinding, itemSelected)

        local fileRow = f:row {
            margin_horizontal = 10,
            spacing = f:label_spacing(),
            f:checkbox {
                title = data.pc.name,
                size = "mini",
                value = LrView.bind (fbinding),
                width = LrView.share "name_width",
                enabled = e,
            },   
            f:static_text {
                title = data.pc.albums and data.pc.albums or "",
                size = "mini",
                width = LrView.share "token_width",
                enabled = e,
            },             
            f:static_text {
                title = data.lr.id and data.lr.id or "",
                size = "mini",
                width = LrView.share "uuid_width",
                enabled = e,
            },             
        }            
        table.insert(view, fileRow)
        for rkey,rule in pairs(data.lr.rules) do      
            if rule.enabled then
                local rbinding = e and string.gsub(propkeys.enabled,"%.%+", fkey .. "_" .. rkey) or 'nil'
                properties[rbinding] = false
                properties:addObserver(rbinding, ruleSelected)
                table.insert(view, GetRuleRow(f, rkey, rule, e, rbinding))
            end
        end   
        local separator = f:row {
            margin_horizontal = 10,
            f:separator {
                fill_horizontal = 1,
            },
        }
        table.insert(view, separator)
    end    
    return view
end

--[[
    Main 'Show' function of the PMISelectMetadataDialog
]]--
function PMISelectMetadataDialog.Show(database)

    return LrFunctionContext.callWithContext( 'PMISelectMetadataDialog.Show', function( context )

        local filekeymap = {}

        local f = LrView.osFactory()

        -- Create a bindable table.  Whenever a field in this table changes then notifications will be sent. 
        local props = LrBinding.makePropertyTable( context )

        -- Get the filtered keys from the database
        local keys = database.GetFilteredKeys({'album', 'file'})

        -- Build the Primary View
        local c = f:tab_view {
            f:tab_view_item {
                identifier = LOC '$$$/PMI/Misc/Albums=<Albums>',
                title = LOC '$$$/PMI/Misc/Albums=<Albums>',
                f:scrolled_view {
                    fill_horizonal = 1,
                    width = 700,            
                    height = 600,            
                    spacing = f:control_spacing(),
                    bind_to_object = props,
                    f:column ( GetAlbumView(f, props, keys, database) ),
                },
            },
            f:tab_view_item {
                identifier = LOC '$$$/PMI/Misc/Files=<Files>',
                title = LOC '$$$/PMI/Misc/Files=<Files>',
                title = "Images",
                f:scrolled_view {
                    spacing = f:label_spacing(),
                    fill_horizonal = 1,
                    width = 700,            
                    height = 600,            
                    spacing = f:control_spacing(),
                    bind_to_object = props,
                    f:column ( GetFileView(f, props, keys, database) ),
                },
            },
        }

        -- Build the Accessory View
        local a = f:row {
            f:push_button {
                title = LOC '$$$/PMI/SelectMetadataDialog/Accessory=<Accessory>',
                action = function() database.Save() end,
            }
        }

        -- Launch the actual dialog...
        local dialogResult = LrDialogs.presentModalDialog {
            title = LOC '$$$/PMI/SelectMetadataDialog/Title=<Title>',
            contents = c,
            accessoryView = a,
            resizable = true,
            actionVerb = LOC '$$$/PMI/SelectMetadataDialog/Action=<Action>',
        }

        -- Process a succesful preview
        if dialogResult == 'ok' then
            local result = {}
            for k, v in props:pairs() do
                if v == true then
                    category, key, rule = k:match("Metadata_([^_]+)_([^_]+)_([^_]+)_enabled")
                    if category ~= nil and key ~= nil and rule ~= nil then
                        if result[category] == nil then
                            result[category] = {}
                            result[category.."_Count"] = 0
                        end

                        if result[category][key] == nil then
                            result[category][key] = {}
                            result[category.."_Count"] = result[category.."_Count"] + 1
                        end

                        relatedKey = database.MetaData[rule]
                        if relatedKey ~= nil then
                            if result[category][key]['keys'] == nil then
                                result[category][key]['keys'] = {}
                            end
                            table.insert(result[category][key]['keys'], relatedKey)
                        else
                            relatedKey = database.MetaData[key]
                            relatedRules = relatedKey.lr.rules
                            relatedRule = relatedRules[rule]
                            result[category][key][rule] = database.MetaData[key].lr.rules[rule]
                        end
                    end
                end
            end

            -- Process a succesful preview
            return result
        end

        return nil

    end ) -- end main function
end

--[[
    Return the module
]]--
return PMISelectMetadataDialog
