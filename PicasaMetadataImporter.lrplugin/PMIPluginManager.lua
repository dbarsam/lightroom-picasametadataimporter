--[[----------------------------------------------------------------------------

--------------------------------------------------------------------------------

PMIPluginManager.lua
Plugin Manager Module for Picasa Metadata Importer plug-in.

--------------------------------------------------------------------------------

Copyright 2010-2012, D. Barsam
You may use this script for any purpose, as long as you include this notice in
any versions derived in whole or part from this file.  

See 'https://github.com/dbarsam/lightroom-picasametadataimporter' for more info.
 
----------------------------------------------------------------------------]]--

-- Access the Lightroom SDK namespaces.
local LrPathUtils = import 'LrPathUtils'
local LrHttp      = import 'LrHttp'
local LrView      = import 'LrView'
local LrLogger    = import 'LrLogger'

-- Initialize the logger
local logger = LrLogger( 'PMIPluginManager' )
logger:enable("print") -- "print" or "logfile"

-- Access the PMI SDK namespaces.
local info        = require 'Info.lua'
local pmiPrefs    = require "PMIPreferenceManager"
local pmiMetadata = require "PMIMetadata"

--[[
    Define this module
]]--
local PMIPluginManager = {}

--[[
    The Splash Screen Section
]]--
function PMIPluginManager.GetSplashScreenSection( f, properties )
    local minimumSdkVersion = info.LrSdkMinimumVersion

    return  {
        title = LOC '$$$/PMI/PluginManager/SplashScreen/Title=<Title>',
        synopsis = LOC '$$$/PMI/PluginManager/SplashScreen/Synopsis=<Synopsis>',
        f:row {
            f:column {
                f:picture {
                    alignment='left',
                    value = _PLUGIN:resourceId( "splash.png" )
                },
            }
        },
        f:row {
            spacing = f:control_spacing(),
            f:static_text {
                font = '<system/bold>',
                size = 'regular',
                fill_horizontal = 1,
                title = LOC '$$$/PMI/PluginManager/SplashScreen/Title=<Title>',
            },
        },
        f:row {
            f:column {
                f:row {
                    f:static_text {
                        title = LOC '$$$/PMI/PluginManager/SplashScreen/Maintained=<Maintained>',
                        width = LrView.share 'aboutlabel_width',
                    },
                    f:static_text {
                        title = LOC '$$$/PMI/PluginManager/SplashScreen/Maintainer=<Maintainer>',
                        text_color = import 'LrColor'( 0, 0, 1 ),
                        mouse_down = function(self)
                            LrHttp.openUrlInBrowser(LOC '$$$/PMI/PluginManager/SplashScreen/Maintainer=<Maintainer>')
                        end,
                    },
                },
                f:row {
                    f:static_text {
                        title = LOC '$$$/PMI/PluginManager/SplashScreen/Latest=<Latest>',
                        width = LrView.share 'aboutlabel_width',
                    },
                    f:static_text {
                        title = LOC '$$$/PMI/PluginManager/SplashScreen/GitHub=<GitHub>',
                        text_color = import 'LrColor'( 0, 0, 1 ),
                        mouse_down = function(self)
                            LrHttp.openUrlInBrowser(LOC '$$$/PMI/PluginManager/SplashScreen/GitHubSite=<GitHubSite>')
                        end,
                    },
                },
                f:row {
                    f:static_text {
                        title = 'Support:',
                        width = LrView.share 'aboutlabel_width',
                    },
                    f:static_text {
                        title = 'Issue Tracker',
                        font = '<system/small>',
                        text_color = import 'LrColor'( 0, 0, 1 ),
                        mouse_down = function(self)
                            LrHttp.openUrlInBrowser(LOC '$$$/PMI/PluginManager/SplashScreen/TrackerSite=<TrackerSite>')
                        end,
                    },
                },
            },
            f:spacer{},
            f:column {
                f:row {
                    f:static_text {
                        title = LOC '$$$/PMI/PluginManager/SplashScreen/Version=<Version>',
                        width = LrView.share 'aboutlabel_width',
                    },
                    f:static_text {
                        fill_horizontal = 1,
                        title = info.VSTRING
                    },
                },                
                f:row {
                    f:static_text {
                        title = LOC '$$$/PMI/PluginManager/SplashScreen/LrVersion=<LrVersion>',
                        width = LrView.share 'aboutlabel_width',
                    },
                    f:static_text {
                        fill_horizontal = 1,
                        title = LOC('$$$/PMI/PluginManager/SplashScreen/SDKVersion=<SDKVersion>', info.LrSdkMinimumVersion),
                    },
                },
            },
        },
    }
end

--[[
    The Preference Section
]]--
function PMIPluginManager.GetPreferencesSection( f, properties )
    return  {
        title = LOC '$$$/PMI/PluginManager/Preferences/Title=<Title>',
        synopsis = LOC '$$$/PMI/PluginManager/Preferences/Synopsis=<Synopsis>',
        pmiPrefs.GetPreferencesPanel(f, properties)
    }
end

--[[
    The Preference Section
]]--
function PMIPluginManager.GetAboutSection( f, properties )
    local view = {
        title = LOC '$$$/PMI/PluginManager/About/Title=<Title>',
        synopsis = LOC '$$$/PMI/PluginManager/About/Synopsis=<Synopsis>',
        spacing = f:label_spacing(),
        f:row {
            f:static_text {
                title = LOC '$$$/PMI/PluginManager/About/About/Title=<Title>',
                width = LrView.share 'legal_width',
            },
            f:static_text {
                title = LOC '$$$/PMI/PluginManager/About/About/Message/Title=<Title>',
				height_in_lines = -1,
				width_in_digits = 70,                
            }
        }
    }

    -- Supported Metadata
    local pcColumn = {
        margin_horizontal = 10,
        f:static_text {
            title = LOC '$$$/PMI/Misc/Picasa=<Picasa>',
            font = '<system/small/bold>',
        }
    }
    for _, p in ipairs(pmiMetadata.GetTypeMenu(pmiMetadata.PcType.file, {'string', 'number'})) do
        table.insert(pcColumn, f:static_text { title = p.title })
    end
    local lrColumns = 
    { 
        {
            f:static_text {
                title = LOC '$$$/PMI/Misc/Lightroom=<Lightroom>',
                font = '<system/small/bold>',
            }
        },
        {
            f:static_text {
                title = '',
                font = '<system/small/bold>',
            }
        }, 
        {
            f:static_text {
                title = '',
                font = '<system/small/bold>',
            }
        }
    }
    local metakeys = pmiMetadata.GetTypeMenu(pmiMetadata.LrType.file, {'string', 'number'})
    local columnlength = math.ceil(#metakeys / #lrColumns)
    for i, p in ipairs(metakeys) do
        local c = math.ceil(i / columnlength) 
        table.insert(lrColumns[c], f:static_text { title = p.title })
    end    
    table.insert(view, f:row {
        f:static_text {
            title = LOC '$$$/PMI/PluginManager/About/Supported/Title=<Title>',
            width = LrView.share 'legal_width',
        },
        f:static_text {
            title = LOC '$$$/PMI/PluginManager/About/Supported/Message/Title=<Title>',
            height_in_lines = -1,
            width_in_digits = 70,                
        },
    })
    local metadataRow =  {
        f:static_text {
            title = '',
            width = LrView.share 'legal_width',
        },
        f:column(pcColumn)
    }
    for i, c in ipairs(lrColumns) do
        table.insert(metadataRow, f:column(c))
    end
    table.insert(view, f:row(metadataRow))

    -- Third Party
    table.insert(view, f:row {
        f:static_text {
            title = LOC '$$$/PMI/PluginManager/About/ThirdParty/Title=<Title>',
            width = LrView.share 'legal_width',
        },
        f:static_text {
            title = LOC '$$$/PMI/PluginManager/About/ThirdParty/Message/Title=<Title>',
            height_in_lines = -1,
            width_in_digits = 70,                
        },
    })
    table.insert(view, f:row {
        margin_horizontal = 10,
        f:static_text {
            title = '',
            width = LrView.share 'legal_width',
        },
        f:static_text
        {
            title = 'Lua Table Persistence',
            font = '<system/small>',
            text_color = import 'LrColor'( 0, 0, 1 ),
            mouse_down = function(self)
                LrHttp.openUrlInBrowser('http://the-color-black.net/blog/LuaTablePersistence')
            end,
        },        
        f:static_text
        {
            title = '(GitHub)',
            font = '<system/small>',
            text_color = import 'LrColor'( 0, 0, 1 ),
            mouse_down = function(self)
                LrHttp.openUrlInBrowser('https://github.com/hipe/lua-table-persistence')
            end,
        },  
    })
    -- References
    table.insert(view, f:row {
        f:static_text {
            title = LOC '$$$/PMI/PluginManager/About/References/Title=<Title>',
            width = LrView.share 'legal_width',
        },
        f:static_text {
            title = LOC '$$$/PMI/PluginManager/About/References/Message/Title=<Title>',
            height_in_lines = -1,
            width_in_digits = 70,                
        },
    })
    local references = {
        ['add face recognition to lightroom w/ picasa!'] = 'http://creativetechs.com/tipsblog/add-face-recognition-to-lightroom-with-picasa/',
        ['.picasa.ini file structure']                   = 'https://gist.github.com/1073823/9986cc61ae67afeca2f4a2f984d7b5d4a818d4f0#file-picasa-ini',
        ['PHP: decode date from picasa.ini']             = 'http://itxv.wordpress.com/2012/12/21/php-decode-date-from-picasa-ini/',
        ['picasa3meta: accessing Picasa metadata']       = 'http://projects.mindtunnel.com/blog/2012/08/30/picasa3meta/',
        ['Migrating from Picasa to Lightroom on OS X']   = 'http://atotic.wordpress.com/2011/01/14/importing-picasa-folders-into-lightroom-on-os-x/',
        ['faceextract']                                  = 'https://github.com/gregersn/faceextract/blob/master/faceextract.pl',
    }
    for label, url in pairs(references) do
        local r = f:row
        {
        margin_horizontal = 10,
            f:static_text {
                title = '',
                width = LrView.share 'legal_width',
            },            
            f:static_text
            {
                title = label,
                font = '<system/small>',
                text_color = import 'LrColor'( 0, 0, 1 ),
                mouse_down = function(self)
                    LrHttp.openUrlInBrowser(url)
                end,
            }
        }
        table.insert(view, r)
    end

    -- License
    table.insert(view, f:row {
        f:static_text {
            title = LOC '$$$/PMI/PluginManager/About/License/Title=<Title>',
            width = LrView.share 'legal_width',
        },
        f:static_text {
            title = LOC '$$$/PMI/PluginManager/About/License/Message/Title=<Title>',
            height_in_lines = -1,
            width_in_digits = 70,                
        },
    }) 
    return view
end
--[[
    The Top Section
]]--
function PMIPluginManager.GetSectionsForTopOfDialog( f, properties )

    return {
        PMIPluginManager.GetSplashScreenSection(f, properties)
    }

end
--[[
    The Bottom Section
]]--
function PMIPluginManager.GetSectionsForBottomOfDialog( f, properties )

    return {
        PMIPluginManager.GetPreferencesSection(f, properties),
        PMIPluginManager.GetAboutSection(f, properties),
    }

end

--[[
    Return the module
]]--
return PMIPluginManager

