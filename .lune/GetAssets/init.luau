--!native
--!optimize 2
--!strict

local ApiUrls = require("../Meta/ApiUrls")
local ApiUrlsMeta = require("../Meta/ApiUrlsMeta")
local Chalk = require("../Packages/Chalk")
local FileType = require("../Meta/FileType")
local Pages = require("../Classes/Pages")
local PagesIterator = require("../Utilities/PagesIterator")
local Promise = require("../Packages/PromiseTyped")
local RobloxApiUtilities = require("../Utilities/RobloxApiUtilities")
local Utilities = require("./Utilities")
local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local Green = Chalk.GreenBright
local BoldGreen = Chalk.Bold .. Green
local Blue = Chalk.Ansi256(39)
local BoldBlue = Chalk.Bold .. Blue

local ASSET_TYPES: {ApiUrls.ApiUrl} = {ApiUrls.GetPants, ApiUrls.GetShirts}
local AssetIndex: number = stdio.prompt("select", "What type of asset do you want to get?", ASSET_TYPES)

if AssetIndex == 0 or not AssetIndex then
	process.exit(0)
end

-- I recommend yaml for this actually
local FILE_TYPES: {FileType.FileType} = {FileType.Json, FileType.Yaml, FileType.Toml}
local TypeIndex: number = stdio.prompt("select", "What do you want to write the file as?", FILE_TYPES)

if TypeIndex == 0 or not TypeIndex then
	process.exit(0)
end

local Resume, LastCursor = (function(): (boolean, string?)
	local LastKnownCursor = Utilities.GetLastKnownCursor()
	if LastKnownCursor and LastKnownCursor ~= "" then
		return stdio.prompt("confirm", `Do you want to resume from the last cursor ({LastKnownCursor})?`, false),
			LastKnownCursor
	end

	return false, nil
end)()

local Type: FileType.FileType = FILE_TYPES[TypeIndex]
local AssetType: ApiUrls.ApiUrl = ASSET_TYPES[AssetIndex]
local Retry = Utilities.CreateRetry(ApiUrlsMeta[AssetType].Url, AssetType)

local PageIndex = 0
local WriteLocation = stdio.prompt("text", "Where do you want to write the file to?", `{process.cwd}{AssetType}Assets`)
if WriteLocation == "" or WriteLocation == 0 or not WriteLocation then
	process.exit(0)
end

local Object: Pages.Pages<RobloxApiUtilities.AssetIdName> = Pages.new(function(Cursor)
	if not Cursor and Resume and LastCursor then
		Cursor = LastCursor --Utilities.GetLastKnownCursor()
	end

	return Promise.Retry(Retry, 20, Cursor)
end)

PagesIterator(Object):Then(function(Assets: {RobloxApiUtilities.AssetIdName})
	PageIndex += 1
	print(`{BoldGreen("Page: ")}{BoldBlue(`{PageIndex}`)}`)

	local AssetIds: {string} = {}
	local Length = 0

	for _, Value in Assets do
		Length += 1
		AssetIds[Length] = `{Value.assetId} - {Value.name}`
	end

	Utilities.GuaranteeAppendFile(AssetIds, WriteLocation, Type, false)
end):Catch(function(Exception)
	local LastKnownCursor = Utilities.LastKnownCursor
	if LastKnownCursor then
		pcall(function()
			fs.writeFile("LastKnownCursor.txt", LastKnownCursor)
		end)
	end

	warn(`Failed to get {AssetType}: {Exception}`)
end):Wait()
