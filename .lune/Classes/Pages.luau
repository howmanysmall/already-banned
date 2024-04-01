--!native
--!optimize 2
--!strict

local Promise = require("../Packages/PromiseTyped")

local Pages = {}
Pages.ClassName = "Pages"
Pages.__index = Pages

local function Constructor<T>(RequestFunction: (Cursor: string?) -> Promise.TypedPromise<PagesResponse<T>>)
	local self = setmetatable({}, Pages)
	self.IsFinished = false

	self.CurrentPage = nil :: {T}?
	self.NextPageCursor = nil :: string?
	self.RequestFunction = RequestFunction

	return self
end

function Pages.new<T>(RequestFunction: (Cursor: string?) -> Promise.TypedPromise<PagesResponse<T>>): Pages<T>
	local self: any = Constructor(RequestFunction)
	return self
end

function Pages.GetCurrentPage<T>(self: Class)
	return Promise.Promisify(function()
		if not self.CurrentPage then
			self:AdvanceToNextPageAsync():Expect()
		end

		return self.CurrentPage
	end)()
end

function Pages.AdvanceToNextPageAsync(self: Class): Promise.Promise
	return Promise.Promisify(function()
		if self.IsFinished then
			error("No more pages to fetch.")
		end

		local Response = self.RequestFunction(self.NextPageCursor):Expect()
		self.CurrentPage = Response.data
		self.NextPageCursor = Response.nextPageCursor
		self.IsFinished = self.NextPageCursor == nil
	end)()
end

export type PagesResponse<T> = {
	data: {T},
	nextPageCursor: string?,
	previousPageCursor: string?,
}

type Class = typeof(Constructor(function()
	return Promise.Resolve({} :: PagesResponse<any>)
end))
export type Pages<T = any> = {
	ClassName: "Pages",
	IsFinished: boolean,

	GetCurrentPage: (self: Pages<T>) -> Promise.TypedPromise<{T}>,
	AdvanceToNextPageAsync: (self: Pages<T>) -> Promise.Promise,
}
return table.freeze(Pages)
