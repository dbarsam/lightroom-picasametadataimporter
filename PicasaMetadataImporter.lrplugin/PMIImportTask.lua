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
local LrDialogs         = import 'LrDialogs'
local LrErrors          = import 'LrErrors'
local LrFunctionContext = import 'LrFunctionContext'
local LrLogger          = import 'LrLogger'
local LrTasks           = import 'LrTasks'

-- Initialize the logger
local logger = LrLogger( 'PMIImportTask' )
logger:enable('print') -- 'print' or 'logfile'

-- Access the PMI SDK namespaces.
local pmiDatabase             = require "PMIDatabase"
local pmiImporter             = require "PMIImporter"
local pmiPrefs                = require "PMIPreferenceManager"
local pmiSelectMetadataDialog = require "PMISelectMetadataDialog"
local pmiSelectSourceDialog   = require "PMISelectSourceDialog"
local pmiUtil                 = require "PMIUtil"

LrFunctionContext.postAsyncTaskWithContext('PMIImportTask', function(context)
    LrDialogs.attachErrorDialogToFunctionContext(context)

    if pmiUtil.Any({'ImportAlbum', 'ImportImage', 'ImportVideo'}, function(val) return pmiPrefs.GetPref(val) end) then
        local result = pmiSelectSourceDialog.Show()
        if result ~= nil then
            -- Populate the Database
            if #(result.files) == 0 then
                LrErrors.throwUserError(LOC '$$$/PMI/Error/CannotFindFile=<CannotFindFile>')
            elseif result.isImport and not pmiDatabase.Import(result.files) then
                LrErrors.throwUserError(LOC('$$$/PMI/Error/CannotFindMetadata=<CannotFindMetadata>', #(result.files)))
            elseif result.isLoad and not pmiDatabase.Load(result.files[1]) then
                LrErrors.throwUserError(LOC('$$$/PMI/Error/CannotLoadMetdata=<CannotLoadMetdata>', result.files[1]))
            end
            -- Update the Database
            pmiDatabase.Resolve()
            -- Get the selection and import
            local rules = pmiSelectMetadataDialog.Show(pmiDatabase)
            if rules ~= nil then
                pmiImporter.Import(pmiDatabase, rules)
            end
        end
    else
        LrErrors.throwUserError(LOC "$$$/PMI/Error/ImportTypeMissing=<ImportTypeMissing>")
    end
end)



