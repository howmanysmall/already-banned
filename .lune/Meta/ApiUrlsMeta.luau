--!native
--!optimize 2
--!strict

local ApiUrls = require("./ApiUrls")

type ApiUrl = ApiUrls.ApiUrl

type Metadata = {
	Url: string,
}

local ApiUrlsMeta: {[ApiUrl]: Metadata} = {
	[ApiUrls.GetPants] = {
		Url = "https://itemconfiguration.roblox.com/v1/creations/get-assets?assetType=Pants&limit=10&cursor=";
	};

	[ApiUrls.GetShirts] = {
		Url = "https://itemconfiguration.roblox.com/v1/creations/get-assets?assetType=Shirt&limit=10&cursor=";
	};
}

return table.freeze(ApiUrlsMeta)
