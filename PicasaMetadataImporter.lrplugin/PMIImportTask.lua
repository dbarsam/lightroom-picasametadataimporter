--[[----------------------------------------------------------------------------

--------------------------------------------------------------------------------

PMIImportTask.lua
Entry point for the Picasa Metadata Importer's Import Task

--------------------------------------------------------------------------------

Copyright 2010-2012, D. Barsam
You may use this script for any purpose, as long as you include this notice in
any versions derived in whole or part from this file.  

See 'https://github.com/dbarsam/lightroom-picasametadataimporter' for more info.
 
----------------------------------------------------------------------------]]--

-- Access the Lightroom SDK namespaces.
local LrTasks           = import 'LrTasks'
local LrDialogs         = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrLogger          = import 'LrLogger'

-- Initialize the logger
local logger = LrLogger( 'PMIImportTask' )
logger:enable('print') -- 'print' or 'logfile'

-- Access the PMI SDK namespaces.
local pmiSelectSourceDialog   = require "PMISelectSourceDialog"
local pmiSelectMetadataDialog = require "PMISelectMetadataDialog"
local pmiImporter             = require "PMIImporter"
local pmiDatabase             = require "PMIDatabase"

local result = pmiSelectSourceDialog.Show()
if result ~= nil then
    LrFunctionContext.postAsyncTaskWithContext('PMIImportTask', function(context)
        LrDialogs.attachErrorDialogToFunctionContext(context)

        -- Populate the Database
        if (result.isImport) then
            pmiDatabase.Import(result.files)
        else
            pmiDatabase.Load(result.files[1])
        end
        pmiDatabase.Resolve()

        -- Get the selection and import
        local rules = pmiSelectMetadataDialog.Show(pmiDatabase)
        if rules ~= nil then
            pmiImporter.Import(pmiDatabase, rules)
        end
    end) 
end
