# lightroom-picasametadataimporter
-----

This plug-in does not import files from Picasa to Lightroom.  Instead this plug-in extracts Picasa metadata from one or more picasa.ini files created by Picasa and writes the metadata to the Lightroom catalogue using the Lightroom API.

The import process is a one way import from Picasa to Lightroom.  There is no undo.  Backup your catalogue before use.

The plug-in uses filenames to match a file in Picasa to a file in Lightroom.  If different files have the same name, metadata will be written to the wrong file.  If the same file has different filename the plug-in will not see the file and report it unavailable.

## Supported Metadata
The imported metadata is written to existing Lightroom metadata fields as defined by the Lightroom API.  Custom metadata fields are not created.  This plug-in can read the following Picasa metadata and write the following Lightroom metadata:

| Picasa  | Lightroom           |                      |                      |
|---------|---------------------|----------------------|----------------------|
| caption | additionalModelInfo | creatorStateProvince | minorModelAge        |
| star    | caption             | creatorUrl           | modelAge             |
|         | city                | dateCreated          | modelReleaseID       |
|         | codeOfOrgShown      | descriptionWriter    | modelReleaseStatus   |
|         | colorNameForLabel   | event                | nameOfOrgShown       |
|         | copyName            | gpsAltitude          | personShown          |
|         | copyright           | headline             | pickStatus           |
|         | copyrightInfoUrl    | instructions         | propertyReleaseID    |
|         | copyrightState      | intellectualGenre    | propertyReleaseStatu |
|         | country             | iptcCategory         | provider             |
|         | creator             | iptcOtherCategories  | rating               |
|         | creatorAddress      | iptcSubjectCode      | rightsUsageTerms     |
|         | creatorCity         | isoCountryCode       | scene                |
|         | creatorCountry      | jobIdentifier        | source               |
|         | creatorEmail        | label                | sourceType           |
|         | creatorJobTitle     | location             | stateProvince        |
|         | creatorPhone        | maxAvailHeight       | title                |
|         | creatorPostalCode   | maxAvailWidth        |                      |

## External Code
This plug-in uses third party code listed below:

* [Lua Table Persistence](http://the-color-black.net/blog/LuaTablePersistence) ([GitHub](https://github.com/hipe/lua-table-persistence))

## Supplementary Reading
This plug-in is a personal project.  If it is not what you're looking for, you are welcome to try one of the following links.  They contain helpful information and were beneficial in creating this plug-in.

* [add face recognition to lightroom w/ picasa!](http://creativetechs.com/tipsblog/add-face-recognition-to-lightroom-with-picasa/)
* [.picasa.ini file structure](https://gist.github.com/1073823/9986cc61ae67afeca2f4a2f984d7b5d4a818d4f0#file-picasa-ini)
* [PHP: decode date from picasa.ini](http://itxv.wordpress.com/2012/12/21/php-decode-date-from-picasa-ini/)
* [picasa3meta: accessing Picasa metadata](http://projects.mindtunnel.com/blog/2012/08/30/picasa3meta/)
* [Migrating from Picasa to Lightroom on OS X](http://atotic.wordpress.com/2011/01/14/importing-picasa-folders-into-lightroom-on-os-x/)
* [faceextract](https://github.com/gregersn/faceextract/blob/master/faceextract.pl)
* [How to convert Picasa Albums into Lightroom Collections](http://www.worldinmyeyes.be/2083/convert-picasa-albums-lightroom-collections/)

There is also this plug-in that does the same thing but slightly differently:

* [Picasa Metadata Import](https://code.google.com/p/lightroom-import-from-picasa-plugin/)
