--!native
--!optimize 2
--!strict

local ApiUrls = require("./Meta/ApiUrls")
local ApiUrlsMeta = require("./Meta/ApiUrlsMeta")
local Chalk = require("./Packages/Chalk")
local FileSystemUtilities = require("./Utilities/FileSystemUtilities")
local FileType = require("./Meta/FileType")
local HttpUtilities = require("./Utilities/HttpUtilities")
local Pages = require("./Classes/Pages")
local PagesIterator = require("./Utilities/PagesIterator")
local RobloxApiUtilities = require("./Utilities/RobloxApiUtilities")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local BoldGreen = Chalk.Bold .. Chalk.GreenBright
local Blue = Chalk.Ansi256(39)
local BoldBlue = Chalk.Bold .. Blue

local ASSET_TYPES: {ApiUrls.ApiUrl} = {ApiUrls.GetPants, ApiUrls.GetShirts}
local AssetIndex: number = stdio.prompt("select", "What type of asset do you want to get?", ASSET_TYPES)

if AssetIndex == 0 or not AssetIndex then
	print("Exiting...")
	process.exit(0)
end

local AssetType: ApiUrls.ApiUrl = ASSET_TYPES[AssetIndex]
local Metadata = ApiUrlsMeta[AssetType]
local Url = Metadata.Url

-- local Success, ResponseDictionary = RobloxApiUtilities.PromiseSignedInRequest({
-- 	Method = "GET";
-- 	Url = Url;
-- }):Wait()

-- if not Success then
-- 	warn(`Failed to get {AssetType}: {ResponseDictionary}`)
-- 	process.exit(0)
-- end

local AssetIds = {}
local Length = 0

local Object: Pages.Pages<RobloxApiUtilities.AssetIdName> = Pages.new(function(Cursor)
	return RobloxApiUtilities.PromiseSignedInRequest({
		Method = "GET";
		Url = `{Url}{if Cursor then Cursor else ""}`;
	}):Then(HttpUtilities.ReturnBody):Then(HttpUtilities.PromiseDecodeUntyped)
end)

PagesIterator(Object):Then(function(Assets: {RobloxApiUtilities.AssetIdName})
	for _, Value in Assets do
		Length += 1
		AssetIds[Length] = `{Value.assetId} - {Value.name}`
	end
end):Catch(function(Exception)
	warn(`Failed to get {AssetType}: {Exception}`)
	process.exit(1)
end):Wait()

print(`Got {BoldBlue(`{Length}`)} assets.`)

local FILE_TYPES: {FileType.FileType} = {FileType.Json, FileType.Toml, FileType.Yaml}
local TypeIndex: number = stdio.prompt("select", "What do you want to write the file as?", FILE_TYPES)

if TypeIndex == 0 or not TypeIndex then
	print("Exiting...")
	process.exit(0)
end

local Type: FileType.FileType = FILE_TYPES[TypeIndex]
local WriteLocation = stdio.prompt("text", "Where do you want to write the file to?", `{process.cwd}{AssetType}Assets`)

if WriteLocation == "" or WriteLocation == 0 or not WriteLocation then
	print("Exiting...")
	process.exit(0)
end

print(`Writing {BoldBlue(`{Length}`)} assets to {BoldGreen(`{WriteLocation}.{Type}`)}...`)
FileSystemUtilities.SafeCreate(`{WriteLocation}.{Type}`, "File", serde.encode(Type, AssetIds, true))
