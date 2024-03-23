--!native
--!optimize 2
--!nonstrict

local Promise = require("../Packages/PromiseTyped")

local TsUtilities = {}

function TsUtilities.Async<T, A...>(Function: (A...) -> T)
	return function(...: A...): Promise.TypedPromise<T>
		local Arguments = table.pack(...)
		return Promise.new(function(Resolve, Reject)
			local Success, Value = pcall(Function, table.unpack(Arguments, 1, Arguments.n))
			if Success then
				Resolve(Value)
			else
				Reject(Value)
			end
		end)
	end
end

function TsUtilities.Await<T>(PromiseObject: Promise.TypedPromise<T>): T
	if not Promise.Is(PromiseObject) then
		return PromiseObject :: any
	end

	local Status, Value = PromiseObject:WaitStatus()
	if Status == Promise.Status.Resolved then
		return Value
	end

	if Status == Promise.Status.Rejected then
		error(Value, 2)
	end

	error("The awaited Promise was cancelled", 2)
end

TsUtilities.TRY_RETURN = 1
TsUtilities.TRY_BREAK = 2
TsUtilities.TRY_CONTINUE = 3
function TsUtilities.Try<R...>(
	Function: () -> (number, R...),
	OnCatch: nil | ((Error: string, Traceback: string) -> (number?, R...) | nil),
	OnFinally: nil | (() -> (number?, R...) | nil)
)
	local Error: string
	local Traceback: string

	local Success, ExitType, Returns = xpcall(Function, function(InnerError: string)
		Error = InnerError
		Traceback = debug.traceback()
	end)

	if not Success and OnCatch then
		local NewExitType, NewReturns = OnCatch(Error, Traceback)
		if NewExitType then
			ExitType, Returns = NewExitType, NewReturns
		end
	end

	if OnFinally then
		local NewExitType, NewReturns = OnFinally()
		if NewExitType then
			ExitType, Returns = NewExitType, NewReturns
		end
	end

	return ExitType, Returns
end

return table.freeze(TsUtilities)
