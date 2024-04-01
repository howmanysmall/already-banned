--!native
--!optimize 2
--!strict

local Pages = require("../Classes/Pages")
local Promise = require("../Packages/PromiseTyped")
local TsUtilities = require("./TsUtilities")

type Pages<T = any> = Pages.Pages<T>

local function PagesIterator<T>(Object: Pages<T>): Promise.TypedPromise<T>
	return Promise.new(TsUtilities.Async(function(Resolve, Reject)
		local Items: {T} = {}
		local Length = 0

		TsUtilities.Try(function()
			while true do
				local CurrentPage = Object:GetCurrentPage():Expect()
				local NewLength = #CurrentPage
				table.move(CurrentPage, 1, NewLength, Length + 1, Items)
				Length += NewLength

				if Object.IsFinished then
					break
				end

				Object:AdvanceToNextPageAsync():Expect()
			end
			Resolve(Items)
			return 1
		end, function(Exception)
			Reject(`Failure: {Exception}`)
			return 1
		end)

		return 1
	end))
end

return PagesIterator
