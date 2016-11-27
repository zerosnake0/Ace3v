_G = _G or getfenv(0)
local tremove, tgetn = table.remove, table.getn
local unpack = unpack

function errorhandler(err)
	return geterrorhandler()(err)
end

do
local method, args
local function call() return method(unpack(args)) end
function safecall(func, ...)
	-- we check to see if the func is passed is actually a function here and don't error when it isn't
	-- this safecall is used for optional functions like OnInitialize OnEnable etc. When they are not
	-- present execution should continue without hinderance
	if type(func) == "function" then
		method, args = func, arg
		return xpcall(call, errorhandler)
	end
end
end -- safecall

-- some string functions
function strtrim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function strmatch(s,pattern,init)
	local tmp = {string.find(s,pattern,init)}
	tremove(tmp,2)
	tremove(tmp,1)
	return unpack(tmp)
end

function strsplit(delim, s, n)
	if n and n < 2 then return s end
	beg = beg or 1
	local i,j = string.find(s,delim,beg)
	if not i then
		return s, nil
	end
	return string.sub(s,1,j-1), strsplit(delim, string.sub(s,j+1), n and n-1 or nil)
end

-- Ace3v: fonctions copied from AceHook-2.1
local protFuncs = {
	CameraOrSelectOrMoveStart = true, 	CameraOrSelectOrMoveStop = true,
	TurnOrActionStart = true,			TurnOrActionStop = true,
	PitchUpStart = true,				PitchUpStop = true,
	PitchDownStart = true,				PitchDownStop = true,
	MoveBackwardStart = true,			MoveBackwardStop = true,
	MoveForwardStart = true,			MoveForwardStop = true,
	Jump = true,						StrafeLeftStart = true,
	StrafeLeftStop = true,				StrafeRightStart = true,
	StrafeRightStop = true,				ToggleMouseMove = true,
	ToggleRun = true,					TurnLeftStart = true,
	TurnLeftStop = true,				TurnRightStart = true,
	TurnRightStop = true,
}

function issecurevariable(x)
	return protFuncs[x] and 1 or nil
end

function hooksecurefunc(arg1, arg2, arg3)
	if type(arg1) == "string" then
		arg1, arg2, arg3 = _G, arg1, arg2
	end
	local orig = arg1[arg2]
	arg1[arg2] = function(...)
		local tmp = {orig(unpack(arg))}
		arg3(unpack(arg))
		return unpack(tmp)
	end
end

-- pickfirstset() - picks the first non-nil value and returns it
function pickfirstset(...)
	for i=1,tgetn(arg) do
		if arg[i] then
			return arg[i]
		end
	end
end

function wipe(t)
	setmetatable(t, nil)
	for k,v in pairs(t) do t[k] = nil end
	return t
end
