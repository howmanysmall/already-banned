--!native
--!optimize 2
--!strict

local Promise = require("../Packages/PromiseTyped")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

--[=[
	Utilities for working with the file system.
	@class FileSystemUtilities
]=]
local FileSystemUtilities = {}

FileSystemUtilities.PromiseReadFile = Promise.Promisify(fs.readFile)
FileSystemUtilities.PromiseWriteFile = Promise.Promisify(fs.writeFile)

--[=[
	Gets the file extension of the file at the path.
	@param FilePath string -- The path to the file.
	@return string? -- The file extension.
]=]
function FileSystemUtilities.GetFileExtension(FilePath: string)
	return string.match(FilePath, "%.([^%.]+)$") or string.match(FilePath, "%.(%a+)$")
end

local EXTENSION_TO_XCODE: {[string]: serde.EncodeDecodeFormat} = {
	json = "json";
	toml = "toml";
	yaml = "yaml";
	yml = "yaml";
}

function FileSystemUtilities.GetEncodeDecodeType(FilePath: string): serde.EncodeDecodeFormat?
	local FileExtension = FileSystemUtilities.GetFileExtension(FilePath)
	return if FileExtension then EXTENSION_TO_XCODE[FileExtension] else nil
end

--[=[
	Gets the name of the file.
	@param FilePath string -- The path to the file.
	@return string? -- The name of the file.
]=]
function FileSystemUtilities.GetFileName(FilePath: string)
	return string.match(FilePath, "([^/]+)$")
end

function FileSystemUtilities.WithoutExtension(Path: string): string
	return string.match(Path, "^(.+)%..+$") or Path
end
function FileSystemUtilities.GetExtension(Path: string)
	return string.match(Path, "%.([^%.]+)$")
end

type CreatorFunction = (Path: string, Contents: string?) -> ()
type SafeCreate = ((Name: string, Type: "File", Contents: string) -> ()) & ((Name: string, Type: "Directory") -> ())

local function SafeCreate(Name: string, Type: "File" | "Directory", Contents: string?)
	local CheckerFunction: typeof(fs.isDir) = if Type == "File" then fs.isFile else fs.isDir
	local CreatorFunction = (if Type == "File" then fs.writeFile else fs.writeDir) :: CreatorFunction

	if not CheckerFunction(Name) then
		CreatorFunction(Name, Contents)
	else
		local Index = 1
		while CheckerFunction(`{FileSystemUtilities.WithoutExtension(Name)} ({Index})`) do
			Index += 1
		end

		local Extension = FileSystemUtilities.GetExtension(Name)
		local NewFilePath = if Extension
			then `{FileSystemUtilities.WithoutExtension(Name)} ({Index}).{Extension}`
			else `{FileSystemUtilities.WithoutExtension(Name)} ({Index})`

		CreatorFunction(NewFilePath, Contents)
	end
end
FileSystemUtilities.SafeCreate = SafeCreate :: SafeCreate

return table.freeze(FileSystemUtilities)
