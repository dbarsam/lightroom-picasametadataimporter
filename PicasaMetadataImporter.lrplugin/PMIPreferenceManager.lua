--[[----------------------------------------------------------------------------

--------------------------------------------------------------------------------

PMIPreferenceManager.lua
Lightroom Plug-in Info Provider for Picasa Metadata Importer plug-in.

--------------------------------------------------------------------------------

Copyright 2010-2012, D. Barsam
You may use this script for any purpose, as long as you include this notice in
any versions derived in whole or part from this file.  

See 'https://github.com/dbarsam/lightroom-picasametadataimporter' for more info.
 
----------------------------------------------------------------------------]]--

-- Access the Lightroom SDK namespaces.
local LrTasks          = import 'LrTasks'
local LrDialogs        = import 'LrDialogs'
local LrView           = import 'LrView'
local LrPrefs          = import 'LrPrefs'.prefsForPlugin(_PLUGIN)
local LrRecursionGuard = import 'LrRecursionGuard'
local LrLogger         = import 'LrLogger'

-- Initialize the logger
local logger = LrLogger( 'PMIPreferenceManager' )
logger:enable("print") -- "print" or "logfile"

-- Access the PMI SDK namespaces.
local pmiMetadata            = require "PMIMetadata"
local pmiTemplateDialog      = require "PMITemplateDialog"
local pmiCollectionsetDialog = require "PMISelectCollectionsetDialog"
local pmiUtil                = require "PMIUtil"

--[[
    Define this module
]]--
local PMIPreferenceManager = {}

--[[
    Recursion guard for selection
]]--
local recursionGuard = LrRecursionGuard ("selection")

--[[
    Access to Lightroom Preferences
]]--
function PMIPreferenceManager.GetPreferences()
    return LrPrefs
end

--[[
    Access to Lightroom Preferences
]]--
function PMIPreferenceManager.GetPref(key)
    return LrPrefs[key]
end

--[[
    Retrieve a Metadata Import Rule Preference
]]--
function PMIPreferenceManager.GetRule(category, token)
    local keys = pmiMetadata.MetadataKeys[category]
    local key = string.gsub(keys.name, "%.%+", token)
    return {
        ['name']     = LrPrefs[string.gsub(keys.name, "%.%+", token)],
        ['enabled']  = LrPrefs[string.gsub(keys.enabled, "%.%+", token)],
        ['template'] = LrPrefs[string.gsub(keys.template, "%.%+", token)]
    }
end

--[[
    The Preference Initialization
]]--
function PMIPreferenceManager.InitPreferences()
    if LrPrefs.UserMode == nil then
        LrPrefs.UserMode = false
    end   
end

--[[
    The Preference Clear
]]--
function PMIPreferenceManager.ClearPreferences()
    for k in LrPrefs:pairs() do
        LrPrefs[k] = nil
    end
end

--[[
    Builds the View for the Album Metadata Preferences
]]--
local function GetGeneralPreferencesView( f, properties )
    local view ={
        f:row {
            font = '<system/small>',
            f:static_text {
                title = LOC '$$$/PMI/PreferenceManager/PreferencesView/CollectionSet/Title=<Title>',
                alignment = 'right',
                width = LrView.share 'label_width' ,
            }, 
            f:static_text {
                truncation = 'middle',
                width_in_chars = 40,
                width = LrView.share 'text_field',
                title = LrView.bind  
                {
                    key = 'Metadata_CollectionSet',
                    transform = function(value, fromTable)
                        return value == nil and "<Top Level>" or value.path
                    end
                },
                tooltip = LOC '$$$/PMI/PreferenceManager/PreferencesView/CollectionSet/Tip=<Tip>',
            },                

            f:push_button {
                title = LOC '$$$/PMI/PreferenceManager/PreferencesView/Select/Title=<Title>',
                tooltip = LOC '$$$/PMI/PreferenceManager/PreferencesView/Select/Tip=<Tip>',
                action = function() 
                    LrTasks.startAsyncTask( function()
                        LrPrefs.Metadata_CollectionSet = pmiCollectionsetDialog.Show(LrPrefs.Metadata_CollectionSet)
                    end)
                end,
            },               
        },              
    }
    return view
end

--[[
    Observer Method to handle recursive selection
]]--
function PMIPreferenceManager.MetadataSelected(propertyTable, key, value)
    local category = key:match('^Metadata_([^_]+)'):lower();

    recursionGuard:performWithGuard (function ()
        if category:match('header') and value ~= nil then
            category = category:match('(%a+)header')
            local regex = pmiMetadata.MetadataKeys[category].enabled
            for k,v in LrPrefs:pairs() do
                if k:match(regex) then
                    propertyTable[k] = value
                end
            end            
        else
            local regex = pmiMetadata.MetadataKeys[category].enabled
            local header = pmiMetadata.MetadataKeys[category].header
            if key:match(regex) then
                local parent_value = value
                for k,v in propertyTable:pairs() do
                    if k ~= key and k:match(regex) and v ~= value then
                        parent_value = nil
                        break
                    end
                end
                propertyTable[pmiMetadata.MetadataKeys[category].header] = parent_value
            end
        end
    end)
end

--[[
    Builds the Metadata Mapping Table for the given type
]]--
local function GetMetadataRuleTable(f, metaCategory)

    local ruleKeys = pmiMetadata.MetadataKeys[metaCategory]
    local metaHeader = ruleKeys.header

    LrPrefs:addObserver( metaHeader,  PMIPreferenceManager.MetadataSelected )

    local view = {
        fill_horizontal = 1,
        spacing = f:label_spacing(),
        f:row {
            f:checkbox {
                title = LOC '$$$/PMI/PreferenceManager/RuleTable/Pc/Title=<Title>',
                value = LrView.bind( metaHeader ),
                width = LrView.share 'label_width',
            },                              
            f:static_text {
                fill_horizontal = 1,
                title = LOC '$$$/PMI/PreferenceManager/RuleTable/Lr/Title=<Title>',
            },                       
        }
    }
    for k, t in pairs(pmiMetadata.PcType[metaCategory]) do        
        local ruleName     = ruleKeys.name:gsub('%.%+', tostring(k))
        local ruleEnabled  = ruleKeys.enabled:gsub('%.%+', tostring(k))
        local ruleTemplate = ruleKeys.template:gsub('%.%+', tostring(k))
        local metaEnum     = pmiMetadata.PcEnumValues[k]
        local metaType     = metaEnum ~= nil and {"string", "number"} or {t}
        local metaTypes    = pmiMetadata.LrType[metaCategory]

        if LrPrefs[ruleEnabled] == nil then
            LrPrefs[ruleEnabled] = false
        end
        LrPrefs:addObserver( ruleEnabled, PMIPreferenceManager.MetadataSelected )

        table.insert(view, f:row {
            bind_to_object = LrPrefs,
            font = '<system/small>',
            f:checkbox {
                title = k,
                width = LrView.share 'label_width' ,
                value = LrView.bind (ruleEnabled)
            }, 
            f:popup_menu {
                fill_horizontal = 1,
                value = LrView.bind(ruleName),
                enabled = LrView.bind
                {
                    keys = {ruleEnabled},
                    operation = function( binder, values, fromTable )
                        return values[ruleEnabled] == true
                    end,                                
                },                  
                items = pmiMetadata.GetTypeMenu(metaTypes, metaType),
                tooltip = LOC '$$$/PMI/PreferenceManager/RuleTable/Rule/Tip=<Tip>',
                immediate = true,
            },
        })

        -- If the Picasa's value is an enum we need to map each individual value to a Lightroom equivalent
        -- Otherwise map the single Picasa value to single Lightroom value of one of the supported types
        if metaEnum ~= nil then
            LrPrefs[ruleTemplate] = {}
            for i, pair in ipairs(metaEnum) do
                local ruleTemplateEnum = ruleKeys.template:gsub('%.%+', tostring(k) .. "_enum_" .. tostring(pair.title))
                LrPrefs[ruleTemplate][pair.title] = ruleTemplateEnum

                r = f:row {
                    fill_horizontal = 1,
                    font = '<system/small>',
                    f:static_text {
                        title = '',
                        width = LrView.share 'label_width',
                    },                   
                    f:spacer {
                        width = 10,
                    },                      
                    f:static_text {
                        title = pair.title,
                        width = LrView.share 'enum_width',
                        enabled = LrView.bind
                        {
                            keys = {ruleName, ruleEnabled},
                            operation = function( binder, values, fromTable )
                                return values[ruleEnabled] == true and values[ruleName] ~= nil
                            end,                                
                        },                           
                    },                         
                    f:view {
                        -- Overlapping View:
                        -- if value == nil then "..."
                        -- if value ~= nil and pmiMetadata.LrEnumValues[value] == nil then edit_field
                        -- if value ~= nil and pmiMetadata.LrEnumValues[value] ~= nil then popup_menu
                        place = "overlapping",
                        fill_horizontal = 1,
                        f:static_text {
                            enabled = LrView.bind
                            {
                                keys = {ruleName, ruleEnabled},
                                operation = function( binder, values, fromTable )
                                    return values[ruleEnabled] == true and values[ruleName] ~= nil
                                end,                                
                            },                              
                            visible = LrView.bind
                            {
                                key = ruleName,
                                transform = function( value, fromTable ) 
                                    return value == nil
                                end,
                            },                            
                            title = "...",
                            tooltip = "$$$/PMI/PreferenceManager/RuleTable/Rule/NilTip",
                        },                         
                        f:edit_field {
                            enabled = LrView.bind
                            {
                                keys = {ruleName, ruleEnabled},
                                operation = function( binder, values, fromTable )
                                    return values[ruleEnabled] == true and values[ruleName] ~= nil
                                end,                                
                            },                              
                            visible = LrView.bind
                            {
                                key = ruleName,
                                transform = function( value, fromTable ) 
                                    return value ~= nil and pmiMetadata.LrEnumValues[value] == nil 
                                end,
                            },                            
                            immediate = true,
                            value = LrView.bind(ruleTemplateEnum),
                            tooltip = "$$$/PMI/PreferenceManager/RuleTable/Rule/TemplateTip",
                        }, 
                        f:popup_menu {
                            enabled = LrView.bind
                            {
                                keys = {ruleName, ruleEnabled},
                                operation = function( binder, values, fromTable )
                                    return values[ruleEnabled] == true and values[ruleName] ~= nil
                                end,                                
                            },   
                            visible = LrView.bind
                            {
                                key = ruleName,
                                transform = function( value, fromTable )
                                    return value ~= nil and pmiMetadata.LrEnumValues[value] ~= nil 
                                end,
                            },                            
                            items = LrView.bind
                            {
                                key = ruleName,
                                transform = function( value, fromTable )
                                    return pmiMetadata.LrEnumValues[value]
                                end,
                            },
                            value = LrView.bind(ruleTemplateEnum),
                            tooltip = "$$$/PMI/PreferenceManager/RuleTable/Rule/EnumTip",
                            immediate = true,
                        },                        
                    }
                }
                table.insert(view, r)
            end
        else
            r = f:view{
                -- Overlapping View:
                fill_horizontal = 1,
                font = '<system/small>',
                place = "overlapping",
                f:view {
                    visible = LrView.bind
                    {
                        key = ruleName,
                        transform = function( value, fromTable )
                            return metaTypes[value] == nil 
                        end,
                    },                      
                    f:row {
                        f:static_text {
                            title = '',
                            width = LrView.share 'label_width',
                        },
                        f:spacer {
                            width = 10,
                        },  
                        f:static_text {
                            enabled = LrView.bind
                            {
                                keys = {ruleName, ruleEnabled},
                                operation = function( binder, values, fromTable )
                                    return values[ruleEnabled] == true and values[ruleName] ~= nil
                                end,                                
                            },                              
                            title = '...',
                            tooltip = "$$$/PMI/PreferenceManager/RuleTable/Rule/NilTip",
                        }, 
                    }
                },
                f:view {
                    fill_horizontal = 1,
                    visible = LrView.bind
                    {
                        key = ruleName,
                        transform = function( value, fromTable ) 
                            return metaTypes[value] == "string" 
                        end,
                    },                     
                    f:row {
                        f:static_text {
                            title = '',
                            width = LrView.share 'label_width',
                        },
                        f:spacer {
                            width = 10,
                        },  
                        f:static_text {
                            title = 'Template:',
                            width = LrView.share 'enum_width',
                            enabled = LrView.bind
                            {
                                keys = {ruleName, ruleEnabled},
                                operation = function( binder, values, fromTable )
                                    return values[ruleEnabled] == true and values[ruleName] ~= nil
                                end,                                
                            },                     
                        },
                        f:edit_field {
                            fill_horizontal = 1,
                            value = LrView.bind(ruleTemplate),
                            tooltip = "$$$/PMI/PreferenceManager/RuleTable/Rule/Template/Tip",
                            enabled = LrView.bind
                            {
                                keys = {ruleName, ruleEnabled},
                                operation = function( binder, values, fromTable )
                                    return values[ruleEnabled] == true and values[ruleName] ~= nil 
                                end,                                
                            },                      
                        },
                        f:push_button {
                            title = LOC '$$$/PMI/PreferenceManager/RuleTable/RuleTemplateEdit/Title=<Title>',
                            tooltip = LOC '$$$/PMI/PreferenceManager/RuleTable/RuleTemplateEdit/Tip=<Tip>',
                            action = function() 
                                LrPrefs[ruleTemplate] = pmiTemplateDialog.Show( LrPrefs[ruleTemplate], pmiMetadata.PcTemplateTokens[metaCategory])
                            end,
                            enabled = LrView.bind
                            {
                                keys = {ruleName, ruleEnabled},
                                operation = function( binder, values, fromTable )
                                    return values[ruleEnabled] == true and values[ruleName] ~= nil
                                end,                                
                            },                      
                        },
                    }
                },
                f:view {
                    fill_horizontal = 1,
                    visible = LrView.bind
                    {
                        key = ruleName,
                        transform = function( value, fromTable ) 
                            return metaTypes[value] == "number" 
                        end,
                    },                      
                    f:row {
                        f:static_text {
                            title = '',
                            width = LrView.share 'label_width',
                        },    
                        f:spacer {
                            width = 10,
                        },  
                        f:static_text {
                            margin_horizontal = 10,
                            title = LOC '$$$/PMI/PreferenceManager/RuleTable/RuleConverter/Title=<Title>',
                            width = LrView.share 'enum_width',
                            enabled = LrView.bind
                            {
                                keys = {ruleName, ruleEnabled},
                                operation = function( binder, values, fromTable )
                                    return values[ruleEnabled] == true and values[ruleName] ~= nil
                                end,                                
                            },                     
                        },
                        f:popup_menu {
                            fill_horizontal = 1,
                            enabled = LrView.bind
                            {
                                keys = {ruleName, ruleEnabled},
                                operation = function( binder, values, fromTable )
                                    return values[ruleEnabled] == true and values[ruleName] ~= nil
                                end,                                
                            },                             
                            value = LrView.bind(ruleTemplate),
                            items = LrView.bind
                            {
                                key = ruleName,
                                transform = function( value, fromTable )
                                    return pmiMetadata.LrConverter[value]
                                end,
                            },                            
                            tooltip = "$$$/PMI/PreferenceManager/RuleTable/RuleConverter/Tip",
                            immediate = true,
                        },                        
                    }

                },
                f:view {
                    fill_horizontal = 1,
                    visible = LrView.bind
                    {
                        key = ruleName,
                        transform = function( value, fromTable ) 
                            return metaTypes[value] == "collectionSet" 
                        end,
                    },                     
                    f:row {
                        f:static_text {
                            title = '',
                            width = LrView.share 'label_width',
                        },
                        f:spacer {
                            width = 10,
                        },  
                        f:static_text {
                            title = LOC '$$$/PMI/PreferenceManager/RuleTable/RuleCollectionSet/Title=<Title>',
                            width = LrView.share 'enum_width',
                            enabled = LrView.bind
                            {
                                keys = {ruleName, ruleEnabled},
                                operation = function( binder, values, fromTable )
                                    return values[ruleEnabled] == true and values[ruleName] ~= nil
                                end,                                
                            },                     
                        },
                        f:static_text {
                            width_in_chars = 29,
                            truncation = 'middle',
                            title = LrView.bind  
                            {
                                key = ruleTemplate,
                                transform = function(value, fromTable)
                                    return value == nil and "<Top Level>" or value.path
                                end
                            },
                            tooltip = '$$$/PMI/PreferenceManager/RuleTable/RuleCollectionSet/Tip=<Tip>',
                            enabled = LrView.bind
                            {
                                keys = {ruleName, ruleEnabled},
                                operation = function( binder, values, fromTable )
                                    return values[ruleEnabled] == true and values[ruleName] ~= nil 
                                end,                                
                            },                  
                        },                
                        f:push_button {
                            title = LOC '$$$/PMI/PreferenceManager/RuleTable/RuleCollectionSetEdit/Title=<Title>',
                            tooltip = LOC '$$$/PMI/PreferenceManager/RuleTable/RuleCollectionSetEdit/Tip=<Tip>',
                            action = function() 
                                LrTasks.startAsyncTask( function()
                                    LrPrefs[ruleTemplate] = pmiCollectionsetDialog.Show(LrPrefs[ruleTemplate])
                                end)
                            end,
                            enabled = LrView.bind
                            {
                                keys = {ruleName, ruleEnabled},
                                operation = function( binder, values, fromTable )
                                    return values[ruleEnabled] == true and values[ruleName] ~= nil
                                end,                                
                            },                   
                        },                         
                    }
                },
            }
            table.insert(view, r)
        end

    end
    return view
end

--[[
    The Preference Section
]]--
function PMIPreferenceManager.GetPreferencesPanel( f, properties )

    return f:column
    {
        fill_horizontal = 1,
        f:group_box {
            title = LOC '$$$/PMI/PreferenceManager/PreferencesPanel/General=<General>',
            bind_to_object = LrPrefs,
            fill_horizontal = 1,
            font = '<system/small>',
            f:row {
                f:static_text {
                    title = LOC '$$$/PMI/PreferenceManager/PreferencesPanel/General/UserMode=<UserMode>',
                    alignment = 'right',
                    width = LrView.share 'label_width' ,
                }, 
                f:radio_button {
                    title = LOC '$$$/PMI/PreferenceManager/PreferencesPanel/General/UserMode/Normal=<Normal>',
                    value = LrView.bind 'UserMode',
                    checked_value = false,
                },   
                f:radio_button {
                    title = LOC '$$$/PMI/PreferenceManager/PreferencesPanel/General/UserMode/Advanced=<Advanced>',
                    value = LrView.bind 'UserMode',
                    checked_value = true,
                },                 
            },               
            f:row {
                f:static_text {
                    title = LOC '$$$/PMI/PreferenceManager/PreferencesPanel/General/Import=<Import>',
                    alignment = 'right',
                    width = LrView.share 'label_width' ,
                }, 
                f:checkbox {
                    title = LOC '$$$/PMI/PreferenceManager/PreferencesPanel/General/Import/Albums=<Albums>',
                    value = LrView.bind 'UserMode',
                    checked_value = false,
                }, 
                 
                f:checkbox {
                    title = LOC '$$$/PMI/PreferenceManager/PreferencesPanel/General/Import/Images=<Images>',
                    value = LrView.bind 'UserMode',
                    checked_value = true,
                },                 
                
                f:checkbox {
                    title = LOC '$$$/PMI/PreferenceManager/PreferencesPanel/General/Import/Videos=<Videos>',
                    value = LrView.bind 'UserMode',
                    checked_value = true,
                },                 
            },               
        },
        f:group_box {
            title = LOC '$$$/PMI/PreferenceManager/PreferencesPanel/Rules/Album/Header=<Header>',
            bind_to_object = LrPrefs,
            font = '<system/small>',
            fill_horizontal = 1,
            spacing = f:label_spacing(),
            f:view(GetMetadataRuleTable(f, 'album')),
        },
        f:group_box {
            fill_horizontal = 1,
            bind_to_object = LrPrefs,
            title = LOC '$$$/PMI/PreferenceManager/PreferencesPanel/Rules/File/Header=<Header>',
            font = '<system/small>',
            spacing = f:label_spacing(),
            f:view(GetMetadataRuleTable(f, 'file'))
        },
        f:row {
            f:static_text {
                fill_horizontal = 1,
                title = '',
                alignment = 'right',
            },              
            f:push_button {
                title = LOC '$$$/PMI/PreferenceManager/PreferencesPanel/Preferences/Export/Export/Title=<Title>',
                tooltip = LOC '$$$/PMI/PreferenceManager/PreferencesPanel/Preferences/Export/Export/Tip=<Tip>',
                action = function() 
                    pmiUtil.Save("D:\\pref.lua", LrPrefs)
                end,
            },              
            f:push_button {
                title = LOC '$$$/PMI/PreferenceManager/PreferencesPanel/Preferences/Reset/Reset/Title=<Title>',
                tooltip = LOC '$$$/PMI/PreferenceManager/PreferencesPanel/Preferences/Reset/Reset/Tip=<Tip>',
                action = function() 
                    if LrDialogs.confirm(LOC '$$$/PMI/PreferenceManager/PreferencesPanel/Preferences/Reset/Confirm/Title=<Title>', '$$$/PMI/PreferenceManager/PreferencesPanel/Preferences/Reset/Confirm/Message=<Message>', LOC '$$$/PMI/Misc/Ok=<Ok>', LOC '$$$/PMI/Misc/Cancel=<Cancel>') == LOC '$$$/PMI/Misc/Ok=<Ok>' then
                        PMIPreferenceManager.ClearPreferences()
                        PMIPreferenceManager.InitPreferences()
                    end
                end,
            },           
        }
    }
end

--[[
    Return the module
]]--
return PMIPreferenceManager

