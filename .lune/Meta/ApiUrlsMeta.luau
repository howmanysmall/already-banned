--!native
--!optimize 2
--!strict

local ApiUrls = require("./ApiUrls")

type ApiUrl = ApiUrls.ApiUrl

type Metadata = {
	Url: string,
}

local LIMIT = 100
assert(LIMIT == 10 or LIMIT == 25 or LIMIT == 50 or LIMIT == 100, `Bad limit {LIMIT}`)

local ApiUrlsMeta: {[ApiUrl]: Metadata} = {
	[ApiUrls.GetPants] = {
		Url = `https://itemconfiguration.roblox.com/v1/creations/get-assets?assetType=Pants&limit={LIMIT}&cursor=`;
	};

	[ApiUrls.GetShirts] = {
		Url = `https://itemconfiguration.roblox.com/v1/creations/get-assets?assetType=Shirt&limit={LIMIT}&cursor=`;
	};
}

return table.freeze(ApiUrlsMeta)
