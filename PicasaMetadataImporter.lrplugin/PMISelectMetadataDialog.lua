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
local LrBinding         = import 'LrBinding'
local LrColor           = import 'LrColor'
local LrDialogs         = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrLogger          = import 'LrLogger'
local LrRecursionGuard  = import 'LrRecursionGuard'
local LrView            = import 'LrView'

-- Initialize the logger
local logger = LrLogger( 'PMISelectMetadataDialog' )
logger:enable('print') -- 'print' or 'logfile'

-- Access the PMI SDK namespaces.
local pmiMetadata            = require "PMIMetadata"
local pmiPrefs               = require "PMIPreferenceManager"
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
                regex = propkeys.file.enabled
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
local function GetFileRow(f, fkey, data, e, binding, view)
    return f:row {
        size = "mini",
        f:checkbox {
            title = fkey,
            value = LrView.bind (binding),
            width = LrView.share ('picasa_metadata_field_width_' .. view),
            enabled = e,
        },            
        f:static_text {
            title = '...',
            width = LrView.share ('lightroom_metadata_field_width_' .. view),
            enabled = e,
        },
        f:static_text {
            title = data.pc.name,
            width = LrView.share ('lightroom_metadata_value_width_' .. view),
            enabled = e,
        },                         
    }                    
end

--[[
    Rule Row
]]--
local function GetRuleRow(f, rkey, rule, e, binding, view)
    return f:row {
        size = "mini",
        f:checkbox {
            title = rkey,
            value = LrView.bind (binding),
            width = LrView.share ('picasa_metadata_field_width_' .. view),
            enabled = e,
        },            
        f:static_text {
            title = rule.name,
            width = LrView.share ('lightroom_metadata_field_width_' .. view),
            enabled = e,
        },
        f:static_text {
            title = rule.value,
            width = LrView.share ('lightroom_metadata_value_width_' .. view),
            enabled = e,
        },                         
    }                    
end

--[[
    The Album View
]]--
local function GetAlbumView(f, properties, keys, database)

    local propkeys = pmiMetadata.MetadataKeys.album
    local userMode = pmiPrefs.GetPref('UserMode')

    properties[propkeys.header] = false
    properties:addObserver( propkeys.header, headerSelected )

    local view = {
        spacing = f:control_spacing(),
        margin_horizontal = 10,
        f:row {
            font = '<system/small/bold>',
            f:checkbox {
                title = LOC '$$$/PMI/SelectMetadataDialog/AlbumView/Header/Title=<Title>',
                value = LrView.bind(propkeys.header),
                width = LrView.share 'picasa_metadata_title_width_album',
            },                              
            f:static_text {
                title = LOC '$$$/PMI/SelectMetadataDialog/View/PicasaField=<PicasaField>',
                width = LrView.share 'picasa_metadata_field_width_album',
            },                       
            f:static_text {
                title = LOC '$$$/PMI/SelectMetadataDialog/View/LightroomField=<LightroomField>',
                width = LrView.share 'lightroom_metadata_field_width_album',
            },            
            f:static_text {
                title = LOC '$$$/PMI/SelectMetadataDialog/View/LightroomValue=<LightroomValue>',
                width = LrView.share 'lightroom_metadata_value_width_album',
            },                       
        },
    }

    for i,akey in ipairs(keys.album) do 
        local data = database.MetaData[akey]

        -- Build the Header Rows
        local headRows = {
            size = "mini",
            spacing = f:label_spacing()
        }
        -- Push a Name Checkbox
        local abinding = string.gsub(propkeys.enabled,"%.%+", akey)
        properties[abinding] = false
        properties:addObserver(abinding, itemSelected)        
        local nameRow = f:row {
            f:checkbox {
                title = data.pc.name,
                value = LrView.bind (abinding),
                width = LrView.share 'picasa_metadata_title_width_album',
            }                    
        }
        table.insert(headRows,nameRow)
        -- Push Debug Information
        if (userMode == pmiPrefs.UserModes.Advanced) then
            local debugColumn = f:column {
                spacing = f:label_spacing(),
                f:static_text {
                    title = data.pc.date and data.pc.date or LOC "$$$/PMI/SelectMetadataDialog/View/Error/NoPicasaAlbumDate=<No Picasa Album Date>",
                    width = LrView.share 'picasa_metadata_title_width_album',
                },
                f:static_text {
                    title = data.pc.token and data.pc.token or LOC "$$$/PMI/SelectMetadataDialog/View/Error/NoPicasaAlbumId=<No Picasa Album Id>",
                    width = LrView.share 'picasa_metadata_title_width_album',
                }
            }
            table.insert(headRows,debugColumn)
        end

        -- Build the Data Rows
        local dataRows = {
            spacing = f:label_spacing()
        }
        -- Push the Album's Rule Rows
        for rkey,rule in pairs(data.lr.rules) do      
            if rule.enabled then
                local rbinding = string.gsub(propkeys.enabled,"%.%+", akey .. "_" .. rkey) or 'nil'
                properties[rbinding] = false
                properties:addObserver(rbinding, ruleSelected)
                table.insert(dataRows, GetRuleRow(f, rkey, rule, true, rbinding, 'album'))
            end
        end   
        -- Push the Album's File Rows
        for _,fkey in ipairs(data.pmi.files) do      
            local idata = database.MetaData[fkey]
            local e = idata.lr.id ~= nil
            local ibinding = e and string.gsub(propkeys.enabled,"%.%+", akey .. "_" .. fkey) or 'nil'
            properties[ibinding] = false
            properties:addObserver(ibinding, ruleSelected)
            table.insert(dataRows, GetFileRow(f, 'file', idata, e, ibinding, 'album'))
        end

        -- Final Album Row
        local albumRow = f:row {
            f:column( headRows ),
            f:column( dataRows )
        }
        table.insert(view, albumRow)

        -- Push the Separator
        local separator = f:row {
            f:separator { fill_horizontal = 1 },
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
    local userMode = pmiPrefs.GetPref('UserMode')

    properties[propkeys.header] = false
    properties:addObserver( propkeys.header, headerSelected )

    local view = {    
        margin_horizontal = 10,
        fill_horizontal = 1,
        spacing = f:control_spacing(),
        f:row {
            fill_horizontal = 1,
            font = '<system/small/bold>',
            f:checkbox {
                title = LOC '$$$/PMI/SelectMetadataDialog/FileView/Header/Title=<Title>',
                value = LrView.bind(propkeys.header),
                width = LrView.share 'picasa_metadata_title_width_file',
            },              
            f:static_text {
                title = LOC '$$$/PMI/SelectMetadataDialog/View/PicasaField=<PicasaField>',
                width = LrView.share 'picasa_metadata_field_width_file',
            },                       
            f:static_text {
                title = LOC '$$$/PMI/SelectMetadataDialog/View/LightroomField=<LightroomField>',
                width = LrView.share 'lightroom_metadata_field_width_file',
            },            
            f:static_text {
                title = LOC '$$$/PMI/SelectMetadataDialog/View/LightroomValue=<LightroomValue>',
                width = LrView.share 'lightroom_metadata_value_width_file',
            },                       
        }
    }

    for i,fkey in ipairs(keys.file) do 
        local data = database.MetaData[fkey]
        local e = data.lr.id ~= nil

        -- Build the Header Rows
        local headRows = {
            size = "mini",
            spacing = f:label_spacing()
        }
        -- Push a Name Checkbox
        local fbinding = e and string.gsub(propkeys.enabled,"%.%+", fkey) or 'nil'
        properties[fbinding] = false
        properties:addObserver(fbinding, itemSelected)        
        local nameRow = f:row {
            f:checkbox {
                title = data.pc.name,
                value = LrView.bind (fbinding),
                width = LrView.share 'picasa_metadata_title_width_file',
                enabled = e,
            },              
        }
        table.insert(headRows,nameRow)
        -- Push Debug Information
        if (userMode == pmiPrefs.UserModes.Advanced) then
            local debugColumn = f:column {
                --margin_horizontal = 16,
                spacing = f:label_spacing(),
                f:static_text {
                    title = data.lr.id and data.lr.id or LOC "$$$/PMI/SelectMetadataDialog/View/Error/FileNotFound=<File Not Found>",
                    enabled = e,
                    width = LrView.share 'picasa_metadata_title_width_file',
                },             
                f:static_text {
                    title = data.pc.albums and data.pc.albums or LOC "$$$/PMI/SelectMetadataDialog/View/Error/NoPicasaAlbum=<No Picasa Album>",
                    enabled = e,
                    width = LrView.share 'picasa_metadata_title_width_file',
                }
            }
            table.insert(headRows, debugColumn)
        end

        -- Build the Data Rows
        local dataRows = {
            spacing = f:label_spacing()
        }
        -- Push the File's Rule Rows
        for rkey,rule in pairs(data.lr.rules) do      
            if rule.enabled then
                local rbinding = e and string.gsub(propkeys.enabled,"%.%+", fkey .. "_" .. rkey) or 'nil'
                properties[rbinding] = false
                properties:addObserver(rbinding, ruleSelected)
                table.insert(dataRows, GetRuleRow(f, rkey, rule, e, rbinding, 'file'))
            end
        end

        -- Final File Row
        local fileRow = f:row {
            f:column( headRows ),
            f:column( dataRows )
        }
        table.insert(view, fileRow)

        -- Push the Separator
        local separator = f:row {
            f:separator { fill_horizontal = 1, },
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

        local userMode = pmiPrefs.GetPref('UserMode')

        local filekeymap = {}

        local f = LrView.osFactory()

        -- Create a bindable table.  Whenever a field in this table changes then notifications will be sent. 
        local props = LrBinding.makePropertyTable( context )

        -- Get the filtered keys from the database
        local keys = database.GetFilteredKeys({'album', 'file'})

         -- Apply User Preferences filters
        local filterApplied = false
        if not pmiPrefs.GetPref('ImportAlbum') then
            local precount = #keys.album
            keys.album = {}
            if not filterApplied then
                filterApplied = precount ~= #keys.album
            end
        end
        if not pmiPrefs.GetPref('ImportImage') then
            local precount = #keys.file
            keys.file = pmiUtil.Filter(keys.file, function(key) return database.MetaData[key].lr.category ~= 'image' end)
            if not filterApplied then
                filterApplied = precount ~= #keys.file
            end
        end
        if not pmiPrefs.GetPref('ImportVideo') then
            local precount = #keys.file
            keys.file = pmiUtil.Filter(keys.file, function(key) return database.MetaData[key].lr.category ~= 'video' end)
            if not filterApplied then
                filterApplied = precount ~= #keys.file
            end
        end

        -- Build the Primary View
        local view = {
            spacing = f:dialog_spacing(),
            f:row {
                f:static_text{
                    title = LOC '$$$/PMI/SelectMetadataDialog/Message/Title=<Message>',
                    font = '<system/bold>',
                },
            },
            f:row {
                f:static_text {
                    title = LOC '$$$/PMI/SelectMetadataDialog/Message/Body=<Body>',
                    font = '<system>',
                },
                f:static_text
                {
                    fill_horizontal = 1,
                    title = LOC '$$$/PMI/SelectMetadataDialog/View/Warning/FilterActive=<FilterActive>',
                    text_color = LrColor( 1, 0, 0 ),
                    font = '<system>',
                    alignment = 'right',
                    visible = filterApplied
                }
            }
        }

        local subviews = {}
        if #keys.album > 0 then
            table.insert(subviews, {
                identifier = LOC '$$$/PMI/Misc/Albums=<Albums>',
                title = LOC '$$$/PMI/Misc/Albums=<Albums>',
                f:scrolled_view {
                    width = pmiPrefs.GetPref('ScrollViewWidth'),            
                    height = pmiPrefs.GetPref('ScrollViewHeight'),
                    bind_to_object = props,
                    f:column ( GetAlbumView(f, props, keys, database) ),
                },
            })            
        end
        if #keys.file > 0 then
            table.insert(subviews, {
                identifier = LOC '$$$/PMI/Misc/Files=<Files>',
                title = LOC '$$$/PMI/Misc/Files=<Files>',
                f:scrolled_view {
                    width = pmiPrefs.GetPref('ScrollViewWidth'),            
                    height = pmiPrefs.GetPref('ScrollViewHeight'),
                    bind_to_object = props,
                    f:column ( GetFileView(f, props, keys, database) ),
                },
            })
        end
        if #subviews > 1 then
            local tabviews = pmiUtil.Map(subviews, function(v) return f:tab_view_item(v) end)
            table.insert(view, f:tab_view(tabviews))
        else
            table.insert(view, f:view(subviews[1]))
        end
        local c = f:column(view)

        -- Build the Accessory View
        local a = nil
        if (userMode == pmiPrefs.UserModes.Advanced) then
            a = f:row {
                f:push_button {
                    title = LOC '$$$/PMI/SelectMetadataDialog/Accessory=<Accessory>',
                    action = function() database.Save() end,
                }
            }
        end

        -- Launch the actual dialog...
        local dialogResult = LrDialogs.presentModalDialog {
            title = LOC '$$$/PMI/SelectMetadataDialog/Title=<Title>',
            contents = c,
            accessoryView = a,
            resizable = false,
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
