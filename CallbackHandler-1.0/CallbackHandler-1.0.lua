--[[ $Id: CallbackHandler-1.0.lua 1131 2015-06-04 07:29:24Z nevcairiel $ ]]
local MAJOR, MINOR = "CallbackHandler-1.0", 6
local CallbackHandler = LibStub:NewLibrary(MAJOR, MINOR)

if not CallbackHandler then return end -- No upgrade needed

local AceCore = LibStub("AceCore-3.0")
local new, del = AceCore.new, AceCore.del

local meta = {__index = function(tbl, key) rawset(tbl, key ,new("CallbackHandler -> events["..tostring(key).."]")) return tbl[key] end}

-- Lua APIs
local tconcat, tinsert, tgetn = table.concat, table.insert, table.getn
local assert, error, loadstring = assert, error, loadstring
local setmetatable, rawset, rawget = setmetatable, rawset, rawget
local next, pairs, type, tostring = next, pairs, type, tostring
local strgsub = string.gsub

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: geterrorhandler

local xpcall = xpcall
local function errorhandler(err)
	return geterrorhandler()(err)
end

local function CreateDispatcher(argCount)
	local code = [[
		local function errorhandler(err)
			return geterrorhandler()(err)
		end
		local method, UP_ARGS
		local function call() method(UP_ARGS) end
		local function abc(handlers, ARGS)
			local index
			index, method = next(handlers)
			if not method then return end
			local OLD_ARGS = UP_ARGS
			UP_ARGS = ARGS
			repeat
				xpcall(call, errorhandler)
				index, method = next(handlers, index)
			until not method
			UP_ARGS = OLD_ARGS
		end
		return abc
	]]
	local ARGS = new("CallbackHandler -> CreateDispatcher "..tostring(argCount))
	for i=1,argCount do ARGS[i]="c"..tostring(i) end
	code = strgsub(code, "OLD_ARGS", tconcat(ARGS,',',1,argCount))
	for i=1,argCount do ARGS[i]="b"..tostring(i) end
	code = strgsub(code, "UP_ARGS", tconcat(ARGS,',',1,argCount))
	for i=1,argCount do ARGS[i]="a"..tostring(i) end
	code = strgsub(code, "ARGS", tconcat(ARGS,',',1,argCount))
	del(ARGS,"CallbackHandler <- CreateDispatcher "..tostring(argCount))
	return assert(loadstring(code, "safecall Dispatcher["..tostring(argCount).."]"))()
end
--DEFAULT_CHAT_FRAME:SetMaxLines(1024)
--CreateDispatcher(0)
--assert(false)
local Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher = CreateDispatcher(argCount)
	rawset(self, argCount, dispatcher)
	return dispatcher
end})

--------------------------------------------------------------------------
-- CallbackHandler:New
--
--   target            - target object to embed public APIs in
--   RegisterName      - name of the callback registration API, default "RegisterCallback"
--   UnregisterName    - name of the callback unregistration API, default "UnregisterCallback"
--   UnregisterAllName - name of the API to unregister all callbacks, default "UnregisterAllCallbacks". false == don't publish this API.
function CallbackHandler:New(target, RegisterName, UnregisterName, UnregisterAllName)

	RegisterName = RegisterName or "RegisterCallback"
	UnregisterName = UnregisterName or "UnregisterCallback"
	if UnregisterAllName==nil then	-- false is used to indicate "don't want this method"
		UnregisterAllName = "UnregisterAllCallbacks"
	end

	-- we declare all objects and exported APIs inside this closure to quickly gain access
	-- to e.g. function names, the "target" parameter, etc


	-- Create the registry object
	local events = setmetatable({}, meta)
	local registry = { recurse=0, events=events }

	-- registry:Fire() - fires the given event/message into the registry
	function registry:Fire(eventname, ...)
		if not rawget(events, eventname) or not next(events[eventname]) then return end
		local oldrecurse = registry.recurse
		registry.recurse = oldrecurse + 1

		Dispatchers[tgetn(arg)+1](events[eventname], eventname, unpack(arg))

		registry.recurse = oldrecurse

		if registry.insertQueue and oldrecurse==0 then
			-- Something in one of our callbacks wanted to register more callbacks; they got queued
			for eventname,callbacks in pairs(registry.insertQueue) do
				local first = not rawget(events, eventname) or not next(events[eventname])	-- test for empty before. not test for one member after. that one member may have been overwritten.
				for self,func in pairs(callbacks) do
					events[eventname][self] = func
					-- fire OnUsed callback?
					if first and registry.OnUsed then
						registry.OnUsed(registry, target, eventname)
						first = nil
					end
				end
				del(callbacks, "CallbackHandler <- insertQueue["..eventname.."].callbaks")
			end
			del(registry.insertQueue, "CallbackHandler <- insertQueue")
			registry.insertQueue = nil
		end
	end

	-- Registration of a callback, handles:
	--   self["method"], leads to self["method"](self, ...)
	--   self with function ref, leads to functionref(...)
	--   "addonId" (instead of self) with function ref, leads to functionref(...)
	-- all with an optional arg, which, if present, gets passed as first argument (after self if present)
	target[RegisterName] = function(self, eventname, method, ...)
		if type(eventname) ~= "string" then
			error("Usage: "..RegisterName.."(eventname, method[, arg]): 'eventname' - string expected.", 2)
		end

		method = method or eventname

		local first = not rawget(events, eventname) or not next(events[eventname])	-- test for empty before. not test for one member after. that one member may have been overwritten.

		if type(method) ~= "string" and type(method) ~= "function" then
			error("Usage: "..RegisterName.."(eventname, method[, arg]): 'method' - string or function expected.", 2)
		end

		local regfunc
		local a1 = arg[1]

		if type(method) == "string" then
			-- self["method"] calling style
			if type(self) ~= "table" then
				error("Usage: "..RegisterName.."(eventname, method[, arg]): self was not a table?", 2)
			elseif self==target then
				error("Usage: "..RegisterName.."(eventname, method[, arg]): do not use Library:"..RegisterName.."(), use your own 'self'.", 2)
			elseif type(self[method]) ~= "function" then
				error("Usage: "..RegisterName.."(eventname, method[, arg]): 'method' - method '"..tostring(method).."' not found on 'self'.", 2)
			end

			if tgetn(arg) >= 1 then
				regfunc = function (...) return self[method](self,a1,unpack(arg)) end
			else
				regfunc = function (...) return self[method](self,unpack(arg)) end
			end
		else
			-- function ref with self=object or self="addonId"
			if type(self)~="table" and type(self)~="string" then
				error("Usage: "..RegisterName.."(self or addonId, eventname, method[, arg]): 'self or addonId': table or string expected.", 2)
			end

			if tgetn(arg) >= 1 then
				regfunc = function (...) return method(a1, unpack(arg)) end
			else
				regfunc = method
			end
		end


		if events[eventname][self] or registry.recurse<1 then
		-- if registry.recurse<1 then
			-- we're overwriting an existing entry, or not currently recursing. just set it.
			events[eventname][self] = regfunc
			-- fire OnUsed callback?
			if registry.OnUsed and first then
				registry.OnUsed(registry, target, eventname)
			end
		else
			-- we're currently processing a callback in this registry, so delay the registration of this new entry!
			-- yes, we're a bit wasteful on garbage, but this is a fringe case, so we're picking low implementation overhead over garbage efficiency
			registry.insertQueue = registry.insertQueue or setmetatable(new("CallbackHandler -> insertQueue"),meta)
			registry.insertQueue[eventname][self] = regfunc
		end
	end

	-- Unregister a callback
	target[UnregisterName] = function(self, eventname)
		if not self or self==target then
			error("Usage: "..UnregisterName.."(eventname): bad 'self'", 2)
		end
		if type(eventname) ~= "string" then
			error("Usage: "..UnregisterName.."(eventname): 'eventname' - string expected.", 2)
		end
		if rawget(events, eventname) and events[eventname][self] then
			events[eventname][self] = nil

			-- Fire OnUnused callback?
			if registry.OnUnused and not next(events[eventname]) then
				registry.OnUnused(registry, target, eventname)
			end

			if rawget(events, eventname) and not next(events[eventname]) then
				del(events[eventname], "CallbackHandler <- events["..eventname.."]")
				events[eventname] = nil
				dbg("SetNIL")
			end
		end
		if registry.insertQueue and rawget(registry.insertQueue, eventname) and registry.insertQueue[eventname][self] then
			registry.insertQueue[eventname][self] = nil
		end
	end

	-- OPTIONAL: Unregister all callbacks for given selfs/addonIds
	if UnregisterAllName then
		target[UnregisterAllName] = function(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
			if not a1 then
				error("Usage: "..UnregisterAllName.."([whatFor]): missing 'self' or 'addonId' to unregister events for.", 2)
			end
			if a1 == target then
				error("Usage: "..UnregisterAllName.."([whatFor]): supply a meaningful 'self' or 'addonId'", 2)
			end

			local arg = new("CallbackHandler -> UnregisterAllName")
			arg[1] = a1
			arg[2] = a2
			arg[3] = a3
			arg[4] = a4
			arg[5] = a5
			arg[6] = a6
			arg[7] = a7
			arg[8] = a8
			arg[9] = a9
			arg[10] = a10
			for i=1,10 do
				local self = arg[i]
				if not self then break end
				if registry.insertQueue then
					for eventname, callbacks in pairs(registry.insertQueue) do
						if callbacks[self] then
							callbacks[self] = nil
						end
					end
				end
				for eventname, callbacks in pairs(events) do
					if callbacks[self] then
						callbacks[self] = nil
						-- Fire OnUnused callback?
						if registry.OnUnused and not next(callbacks) then
							registry.OnUnused(registry, target, eventname)
						end
					end
				end
			end
			del(arg,"CallbackHandler <- UnregisterAllName")
		end
	end

	return registry
end

-- CallbackHandler purposefully does NOT do explicit embedding. Nor does it
-- try to upgrade old implicit embeds since the system is selfcontained and
-- relies on closures to work.

