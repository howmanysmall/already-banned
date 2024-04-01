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
local Promise = require("./Packages/PromiseTyped")
local RobloxApiUtilities = require("./Utilities/RobloxApiUtilities")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local Green = Chalk.GreenBright
local BoldGreen = Chalk.Bold .. Green
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

local AssetIds = {}
local Length = 0

local function GetWithoutCase(Headers: HttpUtilities.HttpHeaderMap, LookFor: string): string?
	LookFor = string.lower(LookFor)
	for Key, Value in Headers do
		if type(Value) ~= "string" then
			continue
		end

		if string.lower(`{Key}`) == LookFor then
			return Value
		end
	end

	return nil
end

local function Retry(Cursor: string?)
	return RobloxApiUtilities.PromiseSignedInRequest({
		Method = "GET";
		Url = `{Url}{if Cursor then Cursor else ""}`;
	}):Then(function(ResponseDictionary)
		if not ResponseDictionary.Success then
			return Promise.Delay(tonumber(GetWithoutCase(ResponseDictionary.Headers, "Retry-After") or 15) or 15):Then(
				function()
					if Cursor then
						pcall(function()
							fs.writeFile("LastKnownCursor.txt", Cursor)
						end)
					end

					return Promise.Reject(
						`Failed to get {AssetType}: {ResponseDictionary.StatusCode} ({ResponseDictionary.StatusMessage}) (we're on cursor {Cursor})`
					)
				end
			)
		end

		if ResponseDictionary.StatusCode == 429 then
			return Promise.Delay(tonumber(GetWithoutCase(ResponseDictionary.Headers, "Retry-After") or 15) or 15):Then(
				function()
					if Cursor then
						pcall(function()
							fs.writeFile("LastKnownCursor.txt", Cursor)
						end)
					end

					return Promise.Reject(`Unepic error 429... gonna retry... (we're on cursor {Cursor})`)
				end
			)
		end

		return ResponseDictionary.Body
	end):Then(HttpUtilities.PromiseDecodeUntyped)
end

local function GetLastKnownCursor(): string?
	if fs.isFile("LastKnownCursor.txt") then
		local Success, Value = pcall(fs.readFile, "LastKnownCursor.txt")
		if Success then
			return Value
		end
	end

	return nil
end

local Object: Pages.Pages<RobloxApiUtilities.AssetIdName> = Pages.new(function(Cursor)
	if not Cursor then
		Cursor = GetLastKnownCursor()
	end

	return Promise.Retry(Retry, 1000, Cursor)
end)

local PageIndex = 0

PagesIterator(Object):Then(function(Assets: {RobloxApiUtilities.AssetIdName})
	PageIndex += 1
	print(
		`{BoldGreen("Page: ")}{BoldBlue(`{PageIndex}`)} {BoldGreen("(")}{BoldBlue(`{Length}`)}{BoldGreen(" assets)")}`
	)

	for _, Value in Assets do
		Length += 1
		AssetIds[Length] = `{Value.assetId} - {Value.name}`
	end
end):Catch(function(Exception)
	warn(`Failed to get {AssetType}: {Exception}`)
end):Wait()

print(`Got {BoldBlue(`{Length}`)} assets.`)

-- I recommend yaml for this actually
local FILE_TYPES: {FileType.FileType} = {FileType.Json, FileType.Yaml, FileType.Toml}
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

local WroteFile, FileError = pcall(function()
	FileSystemUtilities.SafeCreate(`{WriteLocation}.{Type}`, "File" :: "File", serde.encode(Type, AssetIds, true))
end)

if WroteFile then
	process.exit(0)
end

warn(`Failed to write - {FileError}`)
for _, TypeOf: FileType.FileType in next, FileType do
	WroteFile, FileError = pcall(function()
		FileSystemUtilities.SafeCreate(
			`{WriteLocation}.{TypeOf}`,
			"File" :: "File",
			serde.encode(TypeOf, AssetIds, true)
		)
	end)
	if WroteFile then
		process.exit(0)
		break
	end
	warn(`Failed to write - {FileError}`)
end

WroteFile, FileError = pcall(function()
	FileSystemUtilities.SafeCreate(`{WriteLocation}.txt`, "File" :: "File", table.concat(AssetIds, "\n"))
end)

if not WroteFile then
	warn(`Failed to write - {FileError}... it's so fucking joever...`)
	print(table.concat(AssetIds, "\n"))
end

-- FileSystemUtilities.SafeCreate(`{WriteLocation}.{Type}`, "File", serde.encode(Type, AssetIds, true))
