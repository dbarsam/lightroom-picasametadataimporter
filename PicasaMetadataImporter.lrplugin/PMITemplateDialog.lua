--[[----------------------------------------------------------------------------

--------------------------------------------------------------------------------

PMITemplateDialog.lua
Displays the Collection Template Editor dialog

--------------------------------------------------------------------------------

Copyright 2010-2012, D. Barsam
You may use this script for any purpose, as long as you include this notice in
any versions derived in whole or part from this file.  

See 'https://github.com/dbarsam/lightroom-picasametadataimporter' for more info.
 
----------------------------------------------------------------------------]]--

-- Access the Lightroom SDK namespaces.
local LrBinding         = import 'LrBinding'
local LrDialogs         = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrLogger          = import 'LrLogger'
local LrView            = import 'LrView'

-- Initialize the logger
local logger = LrLogger( 'PMITemplateDialog' )
logger:enable("print") -- "print" or "logfile"

--[[
    Define this module
]]--
local PMITemplateDialog = {}

--[[
    Main 'Show' function of the PMITemplateDialog
]]
function PMITemplateDialog.Show(template, templates)

    return LrFunctionContext.callWithContext( 'PMITemplateDialog.Show', function( context )

        local f = LrView.osFactory()

        -- Create a bindable table and initialize with plug-in preferences
        local propertyTable = LrBinding.makePropertyTable( context )
        propertyTable.template       = template
        propertyTable.template_value = nil
        propertyTable.template_items = templates

        -- Create the contents for the dialog.
        local c = f:column {
            spacing = f:control_spacing(),
            bind_to_object = propertyTable,
            font = '<system/small>',
            
            f:row {
                f:static_text {
                    title = LOC '$$$/PMI/TemplateDialog/Template=<Template>',
                    alignment = 'right',
                    width = LrView.share 'label_width',
                },                 
                f:edit_field {
                    immediate = false,
                    value = LrView.bind 'template',
                    width_in_chars = 55,            
                }, 
            },

            f:row {
                spacing = f:label_spacing(),
                f:static_text {
                    title = LOC '$$$/PMI/TemplateDialog/Metadata=<Metadata>',
                    alignment = 'right',
                    width = LrView.share 'label_width',
                }, 
                f:popup_menu {
                    fill_horizontal = 1,
                    value = LrView.bind 'template_value',
                    items = LrView.bind 'template_items',
                    tooltip = LOC '$$$/PMI/TemplateDialog/TemplateName=<TemplateName>',
                    immediate = true,
                },
                f:push_button {
                    title = LOC '$$$/PMI/TemplateDialog/Insert/Action=<Action>',
                    tooltip = LOC '$$$/PMI/TemplateDialog/Insert/Tip=<Tip>',
                    action = function() 
                        propertyTable.template = propertyTable.template == nil and propertyTable.template_value or propertyTable.template .. propertyTable.template_value 
                    end,
               },    
            },             
        }

        -- Launch the actual dialog...
        local dialogResult = LrDialogs.presentModalDialog {
            title = LOC '$$$/PMI/TemplateDialog/Title=<Title>',
            contents = c,
            actionVerb = LOC '$$$/PMI/TemplateDialog/Action=<Action>',
        }

        return dialogResult == 'ok' and propertyTable.template or template

    end ) -- end main function
    
end

--[[
    Return the module
]]--
return PMITemplateDialog

