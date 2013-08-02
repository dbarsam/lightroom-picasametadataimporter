--[[----------------------------------------------------------------------------

--------------------------------------------------------------------------------

Info.lua
Lightroom Plug-in Summary Information for Picasa Metadata Importer plug-in.

--------------------------------------------------------------------------------

Copyright 2010-2012, D. Barsam
You may use this script for any purpose, as long as you include this notice in
any versions derived in whole or part from this file.  

See 'https://github.com/dbarsam/lightroom-picasametadataimporter' for more info.
 
----------------------------------------------------------------------------]]--

return {
    LrPluginName         = LOC '$$$/PMI/Info/LrPluginName=<LrPluginName>',
    LrToolkitIdentifier  = 'com.dbarsam.picasametadataimporter',
    LrPluginInfoUrl      = 'https://github.com/dbarsam/lightroom-picasametadataimporter',

    LrSdkVersion         = 4.0,
    LrSdkMinimumVersion  = 4.0,

    LrInitPlugin         = "Init.lua",
    LrShutdownPlugin     = "Shutdown.lua",
    LrPluginInfoProvider = "PluginInfoProvider.lua",

    LrLibraryMenuItems = {
        {
            title = LOC '$$$/PMI/Info/LrLibraryMenuItems/ImportTask=<ImportTask>',
            file = "PMIImportTask.lua",
        },
    },
    VERSION = { major=4, minor=0, revision=0, build=0, },
    VSTRING = '4.0.0.0'
}
