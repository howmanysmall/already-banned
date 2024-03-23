--!native
--!optimize 2
--!strict

local ApiUrls = table.freeze({
	GetShirts = "Shirts" :: "Shirts";
	GetPants = "Pants" :: "Pants";
})

export type ApiUrl = "Shirts" | "Pants"
return ApiUrls
