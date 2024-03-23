--!native
--!optimize 2
--!strict

local HttpUtilities = require("./HttpUtilities")
local Promise = require("../Packages/PromiseTyped")
local roblox = require("@lune/roblox")

local RobloxApiUtilities = {}

local XsrfCache: {[string]: string} = {}

function RobloxApiUtilities.ClearCache()
	table.clear(XsrfCache)
end

export type AssetIdName = {
	assetId: number,
	name: string,
}

export type IterableWithData<T> = {
	data: {T},
	nextPageCursor: string?,
	previousPageCursor: string?,
}

local function PromiseXsrf(): Promise.TypedPromise<string>
	local Cookie = roblox.getAuthCookie(false)
	if not Cookie then
		return Promise.Reject("Failed to get cookie?")
	end

	if XsrfCache[Cookie] then
		return Promise.Resolve(XsrfCache[Cookie])
	end

	return (HttpUtilities.PromiseRequest({
		Headers = {
			cookie = Cookie;
			["content-type"] = "application/json;charset=utf-8";
		};
		Method = "POST";
		Url = "https://auth.roblox.com/v2/login";
	}, true) :: any):Then(function(ResponseDictionary)
		local Xsrf = ResponseDictionary.Headers["x-csrf-token"]
		XsrfCache[Cookie] = Xsrf
		return Xsrf
	end)
end

local function PromiseSignedInHeaders(): Promise.TypedPromise<{[string]: string}>
	return PromiseXsrf():Then(function(Xsrf)
		local Cookie = roblox.getAuthCookie(false)
		assert(Cookie, "Failed to get cookie (after getting Xsrf?)")
		return {
			["x-csrf-token"] = Xsrf;
			cookie = Cookie;
		}
	end)
end

function RobloxApiUtilities.PromiseSignedInRequest(RequestDictionary: HttpUtilities.RequestDictionary)
	return PromiseSignedInHeaders():Then(function(Headers)
		local NewHeaders = table.clone(RequestDictionary.Headers or {})
		for Key, Value in Headers do
			NewHeaders[Key] = Value
		end

		local NewRequestDictionary = table.clone(RequestDictionary)
		NewRequestDictionary.Headers = NewHeaders
		return HttpUtilities.PromiseRequest(NewRequestDictionary, false)
	end)
end

return table.freeze(RobloxApiUtilities)
