--!native
--!optimize 2
--!strict

local FileType = table.freeze({
	Json = "json" :: "json";
	Yaml = "yaml" :: "yaml";
	Toml = "toml" :: "toml";
})

export type FileType = "json" | "yaml" | "toml"
return FileType
