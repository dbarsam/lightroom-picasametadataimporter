--[[----------------------------------------------------------------------------

--------------------------------------------------------------------------------

PMIMetadata.lua
The Plugin's Metadata Defintions repository

--------------------------------------------------------------------------------

Copyright 2010-2012, D. Barsam
You may use this script for any purpose, as long as you include this notice in
any versions derived in whole or part from this file.  

See 'https://github.com/dbarsam/lightroom-picasametadataimporter' for more info.
 
----------------------------------------------------------------------------]]--

-- Access the Lightroom SDK namespaces.
local LrApplication = import 'LrApplication'
local LrLogger      = import 'LrLogger'

-- Initialize the logger
local logger = LrLogger( 'PMIMetadata' )
logger:enable("print") -- "print" or "logfile"

--[[
    Define this module
]]-- 
local PMIMetadata = {}

--[[
    Keys used to define importation rule for metadata (defined by user in
    the plugins preferences.  In cases where the string is a regex, the 
    string is evaluted at runtime and formatted with the name of a Picasa
    metadata token.

    header
        The "Select All" functionality in various UIs. True if all
        selected, False if none select, nil if mixed.  
    name
        Maps a Picasa metadata token to a Lightroom metadata token.  The key
        is completed at runtime and evaluates to a respetive Lightroom metadata
        token.
    enabled
        The enable/disable state of metadata token mapping operation.  The value
        is True if the Picasa-Lightroom mapping should be executed; false otherwise
    template
        Describes how a Picasa metadata value should be formatted for the paired
        Lightroom metadata.  The value is interepreted based on the type of
        Lightroom metatdata token stored in 'name' as follows
            string        : string's format string
            number        : numeric conversion function
            collectionSet : colection set local identifier
]]--
PMIMetadata.MetadataKeys = {
    file = 
        {
            header   = 'Metadata_FileHeader',
            name     = 'Metadata_File_.+',
            enabled  = 'Metadata_File_.+_enabled',
            template = 'Metadata_File_.+_template',
        },
        album = 
        {
            header   = 'Metadata_AlbumHeader',
            name     = 'Metadata_Album_.+',
            enabled  = 'Metadata_Album_.+_enabled',
            template = 'Metadata_Album_.+_template',
        }
}

--[[
    Keys used to pair Lightroom metadata types to numeric conversion functions:
        {default} => a straight 'tonumber({value})' operation

    Presented as a popup_menu item for various UI elements.
]]--
PMIMetadata.LrConverterTokens = {
    gpsAltitude = {
        { title = LOC '$$$/PMI/Metadata/Converter/Default=<Default>', value = LOC '$$$/PMI/Metadata/Converter/DefaultToken=<DefaultToken>' },
    },    
    maxAvailHeight = {
        { title = LOC '$$$/PMI/Metadata/Converter/Default=<Default>', value = LOC '$$$/PMI/Metadata/Converter/DefaultToken=<DefaultToken>' },
    },    
    maxAvailWidth = {
        { title = LOC '$$$/PMI/Metadata/Converter/Default=<Default>', value = LOC '$$$/PMI/Metadata/Converter/DefaultToken=<DefaultToken>' },
    },    
    pickStatus = {
        { title = LOC '$$$/PMI/Metadata/Converter/Default=<Default>', value = LOC '$$$/PMI/Metadata/Converter/DefaultToken=<DefaultToken>' },
    },    
    rating = {
        { title = LOC '$$$/PMI/Metadata/Converter/Default=<Default>', value = LOC '$$$/PMI/Metadata/Converter/DefaultToken=<DefaultToken>' },
    },    
}
--[[
    Keys of numeric conversion functions 
]]--
PMIMetadata.LrConverter = {
    [LOC '$$$/PMI/Metadata/Converter/DefaultToken=<DefaultToken>'] = function(value) return tonumber(value) end,
}
--[[
    Keys used to convert Picasa metadata tokens into string format tokens.
    Using the tokens in a string will insert the Picasa metadata value.

    Presented as a popup_menu item for various UI elements.
]]--
PMIMetadata.PcTemplateTokens = {
    album = {
        { title = LOC '$$$/PMI/Metadata/PCTemplate/Album/Name=<Name>',        value = LOC '$$$/PMI/Metadata/PCTemplate/Album/NameToken=<NameToken>' },
        { title = LOC '$$$/PMI/Metadata/PCTemplate/Album/Date=<Date>',        value = LOC '$$$/PMI/Metadata/PCTemplate/Album/DateToken=<DateToken>' },
        { title = LOC '$$$/PMI/Metadata/PCTemplate/Album/ID=<ID>',            value = LOC '$$$/PMI/Metadata/PCTemplate/Album/IDToken=<IDToken>' },
    },
    file = {
        { title = LOC '$$$/PMI/Metadata/PCTemplate/File/Name=<Name>',         value = LOC '$$$/PMI/Metadata/PCTemplate/File/NameToken=<NameToken>' },
        { title = LOC '$$$/PMI/Metadata/PCTemplate/File/Caption=<Caption>',   value = LOC '$$$/PMI/Metadata/PCTemplate/File/CaptionToken=<CaptionToken>' },
        { title = LOC '$$$/PMI/Metadata/PCTemplate/File/Rotation=<Rotation>', value = LOC '$$$/PMI/Metadata/PCTemplate/File/RotationToken=<RotationToken>' },
        { title = LOC '$$$/PMI/Metadata/PCTemplate/File/Star=<Star>',         value = LOC '$$$/PMI/Metadata/PCTemplate/File/StarToken=<StarToken>' },
    }
}

--[[
    Keys used to store enumerations of various Picasa Metadata tokens
]]--
PMIMetadata.PcEnumValues = {
    rotate  = {
        { title = 'rotate(0)', value =   0 },
        { title = 'rotate(1)', value =  90 },
        { title = 'rotate(2)', value = 180 },
        { title = 'rotate(3)', value = 270 },
    },
    star    = {
        { title = 'yes', value = true },
        { title = 'no',  value = false },
    }
}

--[[
    Keys used to store enumerations of various Lightroom metadata tokens
]]--
PMIMetadata.LrEnumValues = {
    rating = { 
        { title = LOC '$$$/PMI/Metadata/LrEnum/Rating/0=<0>', value = 0 },
        { title = LOC '$$$/PMI/Metadata/LrEnum/Rating/1=<1>', value = 1 },
        { title = LOC '$$$/PMI/Metadata/LrEnum/Rating/2=<2>', value = 2 },
        { title = LOC '$$$/PMI/Metadata/LrEnum/Rating/3=<3>', value = 3 },
        { title = LOC '$$$/PMI/Metadata/LrEnum/Rating/4=<4>', value = 4 },
        { title = LOC '$$$/PMI/Metadata/LrEnum/Rating/5=<5>', value = 5 },
    },
    pickStatus = {
        { title = LOC '$$$/PMI/Metadata/LrEnum/Rating/Picked=<Picked>',     value = 1},
        { title = LOC '$$$/PMI/Metadata/LrEnum/Rating/NotSet=<NotSet>',     value = 0},
        { title = LOC '$$$/PMI/Metadata/LrEnum/Rating/Rejected=<Rejected>', value = -1},
    },
    copyrightState = { 
        { title = LOC '$$$/PMI/Metadata/LrEnum/Copyright/Unknown=<Unknown>',      value = 'unknown' },
        { title = LOC '$$$/PMI/Metadata/LrEnum/Copyright/Copyrighted=<Copyrighted>',  value = 'copyrighted' },
        { title = LOC '$$$/PMI/Metadata/LrEnum/Copyright/PublicDomain=<PublicDomain>', value = 'public domain' },
    },
}

--[[
    Keys used to enumerate the supported Picasa metadata tokens and their
    respective types
]]--
PMIMetadata.PcType = {
    album = {
        name    = "string",
        path    = "collectionSet",
    },
    file = {
        caption = "string",
        star    = "number"
    }
}

--[[
    Keys used to enumerate the supported Lightroom metadata tokens and their
    respective types
]]--
PMIMetadata.LrType = {
    album = {
        collectionName        = "string",
        collectionSet         = "collectionSet",
    },
    file = {
        additionalModelInfo   = "string",
        artworksShown         = "table",
        caption               = "string",
        city                  = "string",
        codeOfOrgShown        = "string",
        colorNameForLabel     = "string",
        copyName              = "string",
        copyright             = "string",
        copyrightInfoUrl      = "string",
        copyrightOwner        = "table",
        copyrightState        = "string",
        country               = "string",
        creator               = "string",
        creatorAddress        = "string",
        creatorCity           = "string",
        creatorCountry        = "string",
        creatorEmail          = "string",
        creatorJobTitle       = "string",
        creatorPhone          = "string",
        creatorPostalCode     = "string",
        creatorStateProvince  = "string",
        creatorUrl            = "string",
        dateCreated           = "string",
        descriptionWriter     = "string",
        event                 = "string",
        gps                   = "table",
        gpsAltitude           = "number",
        headline              = "string",
        imageCreator          = "table",
        imageSupplier         = "table",
        instructions          = "string",
        intellectualGenre     = "string",
        iptcCategory          = "string",
        iptcOtherCategories   = "string",
        iptcSubjectCode       = "string",
        isoCountryCode        = "string",
        jobIdentifier         = "string",
        label                 = "string",
        licensor              = "table",
        location              = "string",
        locationCreated       = "table",
        locationShown         = "table",
        maxAvailHeight        = "number",
        maxAvailWidth         = "number",
        minorModelAge         = "string",
        modelAge              = "string",
        modelReleaseID        = "string",
        modelReleaseStatus    = "string",
        nameOfOrgShown        = "string",
        personShown           = "string",
        pickStatus            = "number",
        propertyReleaseID     = "string",
        propertyReleaseStatus = "string",
        provider              = "string",
        rating                = "number",
        registryId            = "table",
        rightsUsageTerms      = "string",
        scene                 = "string",
        source                = "string",
        sourceType            = "string",
        stateProvince         = "string",
        title                 = "string",
    }
}


--[[
    Makes a popup_menu items table from a types look-up table
]]--
function PMIMetadata.GetTypeMenu(types, filters)
    local lookup = {}
    for i, t in ipairs(filters) do
        lookup[t] = t
    end

    result = {}
    for k, v in pairs(types) do
        if lookup[v] ~= nil then
            table.insert(result, {title = k, value = k})
        end
    end

    table.sort(result, function(l,r) 
        return string.lower(l.title) < string.lower(r.title)
    end)

    return result;
end

--[[
    Makes a popup_menu items table from a types look-up table
]]--
function PMIMetadata.GetTemplateTokens(category)
    local tokens = {}
    for _,t in ipairs(PMIMetadata.PcTemplateTokens[category]) do
        table.insert(tokens, t.value)   
    end
    return tokens
end

--[[
    Processes a Template string by replacing matching tokens with respective data
]]--
function PMIMetadata.ResolveTemplate(template, tokens, data)
    result = template
    for _, t in ipairs(tokens) do
        if result:match(t) then
            local i,j,key = t:find("{(.-)}")
            local value = data[key]
            if value ~= nil then
                result = result:gsub(t, value)
            end
        end            
    end    
    return result;
end

--[[
    Processes a Convert by evaluating it
]]--
function PMIMetadata.ResolveConverter(converter, input)
    local converter = pmiMetadata.LrConverter[converter]
    return converter ~= nil and converter(input) or nil
end

--[[
    Return the module
]]--
return PMIMetadata
