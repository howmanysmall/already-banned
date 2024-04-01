--!native
--!optimize 2
--!strict

local Promise = require("../Packages/PromiseTyped")
local net = require("@lune/net")
local serde = require("@lune/serde")

local HttpUtilities = {}

local JSON: "json" = "json"

export type Promise<T...> = Promise.TypedPromise<T...>
export type RequestDictionary = {
	Body: string?,
	Headers: HttpHeaderMap?,
	Method: net.HttpMethod?,
	Url: string,
}

export type ResponseDictionary = {
	Body: string,
	Headers: HttpHeaderMap,
	StatusCode: number,
	StatusMessage: string,
	Success: boolean,
}
export type HttpHeaderMap = net.HttpHeaderMap

local function ReturnBody(ResponseDictionary: ResponseDictionary)
	return ResponseDictionary.Body
end
HttpUtilities.ReturnBody = ReturnBody

function HttpUtilities.PromiseRequest(
	RequestDictionary: RequestDictionary,
	IgnoreStatus: boolean?
): Promise<ResponseDictionary>
	return Promise.new(function(Resolve, Reject)
		local Success, Value = pcall(net.request, {
			body = RequestDictionary.Body;
			headers = RequestDictionary.Headers;
			method = RequestDictionary.Method;
			url = RequestDictionary.Url;
		})

		if Success then
			if not IgnoreStatus then
				if Value.ok then
					Resolve({
						Body = Value.body;
						Headers = Value.headers;
						StatusCode = Value.statusCode;
						StatusMessage = Value.statusMessage;
						Success = true;
					})
				else
					Reject(`HTTP {Value.statusCode}: {Value.statusMessage} ({RequestDictionary.Url})`)
				end
			else
				Resolve({
					Body = Value.body;
					Headers = Value.headers;
					StatusCode = Value.statusCode;
					StatusMessage = Value.statusMessage;
					Success = Value.ok;
				})
			end
		else
			Reject(`{Value}`)
		end
	end)
end

function HttpUtilities.PromiseDecode<T>(Input: string, _TemplateType: T): Promise.TypedPromise<T>
	return Promise.new(function(Resolve, Reject)
		local Success, ValueOrError = pcall(serde.decode, JSON, Input)
		if Success then
			Resolve(ValueOrError)
		else
			Reject(ValueOrError)
		end
	end)
end

function HttpUtilities.PromiseDecodeUntyped(Input: string): Promise.TypedPromise<any>
	return HttpUtilities.PromiseDecode(Input, nil :: any)
end

return table.freeze(HttpUtilities)
