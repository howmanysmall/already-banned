--!native
--!optimize 2
--!strict

local FileSystemUtilities = require("../Utilities/FileSystemUtilities")
local FileType = require("../Meta/FileType")
local HttpUtilities = require("../Utilities/HttpUtilities")
local Promise = require("../Packages/PromiseTyped")
local RobloxApiUtilities = require("../Utilities/RobloxApiUtilities")
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Utilities = {}
Utilities.LastKnownCursor = nil :: string?

local function GetWithoutCase(Headers: net.HttpHeaderMap, LookFor: string): string?
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

function Utilities.GetLastKnownCursor(): string?
	if fs.isFile("LastKnownCursor.txt") then
		local Success, Value = pcall(fs.readFile, "LastKnownCursor.txt")
		if Success then
			return Value
		end
	end

	return nil
end

function Utilities.CreateRetry(Url: string, AssetType: string)
	local function Retry(Cursor: string?)
		if Cursor then
			Utilities.LastKnownCursor = Cursor
		end

		return RobloxApiUtilities.PromiseSignedInRequest({
			Method = "GET";
			Url = `{Url}{if Cursor then Cursor else ""}`;
		}):Then(function(ResponseDictionary)
			if not ResponseDictionary.Success then
				local RetryAfter = GetWithoutCase(ResponseDictionary.Headers, "Retry-After")
				if RetryAfter then
					print("Retrying after", RetryAfter)
				end

				return Promise.Delay(tonumber(RetryAfter or 15) or 15):Then(function()
					if Cursor then
						pcall(function()
							fs.writeFile("LastKnownCursor.txt", Cursor)
						end)
					end

					return Promise.Reject(
						`Failed to get {AssetType}: {ResponseDictionary.StatusCode} ({ResponseDictionary.StatusMessage}) (we're on cursor {Cursor})`
					)
				end)
			end

			if ResponseDictionary.StatusCode == 429 then
				local RetryAfter = GetWithoutCase(ResponseDictionary.Headers, "Retry-After")
				if RetryAfter then
					print("Retrying after", RetryAfter)
				end

				return Promise.Delay(tonumber(RetryAfter or 15) or 15):Then(function()
					if Cursor then
						pcall(function()
							fs.writeFile("LastKnownCursor.txt", Cursor)
						end)
					end

					return Promise.Reject(`Unepic error 429... gonna retry... (we're on cursor {Cursor})`)
				end)
			end

			return ResponseDictionary.Body
		end):Then(HttpUtilities.PromiseDecodeUntyped)
	end

	return Retry
end

function Utilities.GuaranteeWriteFile(
	AssetIds: {string},
	WriteLocation: string,
	Type: FileType.FileType,
	ShouldProcessExit: boolean
)
	local WroteFile, FileError = pcall(function()
		FileSystemUtilities.SafeCreate(`{WriteLocation}.{Type}`, "File" :: "File", serde.encode(Type, AssetIds, true))
	end)

	if WroteFile then
		if ShouldProcessExit then
			process.exit(0)
		end

		return
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
			if ShouldProcessExit then
				process.exit(0)
			end

			return
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
end

function Utilities.GuaranteeAppendFile(AssetIds: {string}, WriteLocation: string, ShouldProcessExit: boolean)
	local String = table.concat(AssetIds, "\n")
	local WroteFile, FileError = pcall(function()
		FileSystemUtilities.Append(`{WriteLocation}.txt`, String)
	end)

	if WroteFile then
		if ShouldProcessExit then
			process.exit(0)
		end

		return
	end

	local Tries = 0
	repeat
		WroteFile, FileError = pcall(function()
			FileSystemUtilities.Append(`{WriteLocation}.txt`, String)
		end)

		if WroteFile then
			if ShouldProcessExit then
				process.exit(0)
			end

			return
		end

		Tries += 1
	until WroteFile or Tries > 20

	if WroteFile then
		if ShouldProcessExit then
			process.exit(0)
		end
		return
	end

	if not WroteFile then
		warn(`Failed to write - {FileError}... it's so fucking joever...`)
		print(table.concat(AssetIds, "\n"))
	end
end

return Utilities
