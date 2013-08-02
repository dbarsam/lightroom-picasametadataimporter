--[[----------------------------------------------------------------------------

--------------------------------------------------------------------------------

Init.lua
Lightroom Plug-in Initialization for Picasa Metadata Importer plug-in.

--------------------------------------------------------------------------------

Copyright 2010-2012, D. Barsam
You may use this script for any purpose, as long as you include this notice in
any versions derived in whole or part from this file.  

See 'https://github.com/dbarsam/lightroom-picasametadataimporter' for more info.
 
----------------------------------------------------------------------------]]--

-- Access the PMI SDK namespaces.
local pmiPrefs = require "PMIPreferenceManager"

-- Reset preferences to default if none exist
pmiPrefs.InitPreferences()
