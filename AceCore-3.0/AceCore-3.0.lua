local ACECORE_MAJOR, ACECORE_MINOR = "AceCore-3.0", 1
local AceCore, oldminor = LibStub:NewLibrary(ACECORE_MAJOR, ACECORE_MINOR)

if not AceCore then return end -- No upgrade needed

AceCore._G = AceCore._G or getfenv(0)
local _G = AceCore._G
local strsub, strgsub, strfind = string.sub, string.gsub, string.find
local tremove, tconcat = table.remove, table.concat
local tgetn, tsetn = table.getn, table.setn

-- Debug util function, may be no longer necessary when finished
function dbg(...)
	for i=1,tgetn(arg) do
		arg[i] = tostring(arg[i])
	end
	DEFAULT_CHAT_FRAME:AddMessage(table.concat(arg,","))
end

local new, del
do
local list = setmetatable({}, {__mode = "k"})
function new(dbgmsg)
	DEFAULT_CHAT_FRAME:AddMessage(">>>>>>>>>>>>>>>>>>>"..(dbgmsg or ''))
	if not dbgmsg then dbg(debugstack()) end
	local t = next(list)
	if not t then
		return {}
	end
	list[t] = nil
	return t
end

function del(t,dbgmsg)
	DEFAULT_CHAT_FRAME:AddMessage("<<<<<<<<<<<<<<<<<<<"..(dbgmsg or ''))
	setmetatable(t, nil)
	for k in pairs(t) do
		t[k] = nil
	end
	tsetn(t,0)
	list[t] = true
end

-- debug
function AceCore.listcount()
	local count = 0
	for k in list do
		count = count + 1
	end
	return count
end
end	-- AceCore.new, AceCore.del
AceCore.new, AceCore.del = new, del

local function errorhandler(err)
	return geterrorhandler()(err)
end
AceCore.errorhandler = errorhandler

local function CreateDispatcher(argCount)
	local code = [[
		local errorhandler = LibStub("AceCore-3.0").errorhandler
		local method, UP_ARGS
		local function call()
			local func, ARGS = method, UP_ARGS
			method, UP_ARGS = nil, NILS
			return func(ARGS)
		end
		return function(func, ARGS)
			method, UP_ARGS = func, ARGS
			return xpcall(call, errorhandler)
		end
	]]
	local c = 4*argCount-1
	local s = "b01,b02,b03,b04,b05,b06,b07,b08,b09,b10"
	code = strgsub(code, "UP_ARGS", string.sub(s,1,c))
	s = "a01,a02,a03,a04,a05,a06,a07,a08,a09,a10"
	code = strgsub(code, "ARGS", string.sub(s,1,c))
	s = "nil,nil,nil,nil,nil,nil,nil,nil,nil,nil"
	code = strgsub(code, "NILS", string.sub(s,1,c))
	return assert(loadstring(code, "safecall Dispatcher["..tostring(argCount).."]"))()
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher
	if not tonumber(argCount) then dbg(debugstack()) end
	if argCount > 0 then
		dispatcher = CreateDispatcher(argCount)
	else
		dispatcher = function(func) return xpcall(func,errorhandler) end
	end
	rawset(self, argCount, dispatcher)
	return dispatcher
end})

function AceCore.safecall(func,argc,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	-- we check to see if the func is passed is actually a function here and don't error when it isn't
	-- this safecall is used for optional functions like OnInitialize OnEnable etc. When they are not
	-- present execution should continue without hinderance
	if type(func) == "function" then
		return Dispatchers[argc](func,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	end
end

-- some string functions
-- vanilla available string operations:
--    sub, gfind, rep, gsub, char, dump, find, upper, len, format, byte, lower
-- we will just replace every string.match with string.find in the code
function AceCore.strtrim(s)
	return strgsub(s, "^%s*(.-)%s*$", "%1")
end

local function strsplit(delim, s, n)
	if n and n < 2 then return s end
	beg = beg or 1
	local i,j = string.find(s,delim,beg)
	if not i then
		return s, nil
	end
	return string.sub(s,1,j-1), strsplit(delim, string.sub(s,j+1), n and n-1 or nil)
end
AceCore.strsplit = strsplit

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

local function issecurevariable(x)
	return protFuncs[x] and 1 or nil
end
AceCore.issecurevariable = issecurevariable

local function hooksecurefunc(arg1, arg2, arg3)
	if type(arg1) == "string" then
		arg1, arg2, arg3 = _G, arg1, arg2
	end
	local orig = arg1[arg2]
	if type(orig) ~= "function" then
		error("The function "..arg2.." does not exist", 2)
	end
	arg1[arg2] = function(...)
		local tmp = {orig(unpack(arg))}
		arg3(unpack(arg))
		return unpack(tmp)
	end
end
AceCore.hooksecurefunc = hooksecurefunc

-- pickfirstset() - picks the first non-nil value and returns it
local function pickfirstset(argc,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	if argc <= 1 or a1 then
		return a1
	else
		return pickfirstset(argc-1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	end
end
AceCore.pickfirstset = pickfirstset

-- wipe preserves metatable
function AceCore.wipe(t)
	for k,v in pairs(t) do t[k] = nil end
	tsetn(t,0)
	return t
end

function AceCore.truncate(t,e)
	e = e or tgetn(t)
	for i=1,e do
		if t[i] == nil then
			tsetn(t,i-1)
			return
		end
	end
	tsetn(t,e)
end

-- Some modern wow api
local cursorType, cursorData, cursorSubType, cursorSubData
function GetCursorInfo()
	return cursorType, cursorData, cursorSubType, cursorSubData
end

local function setcursoritem(link)
	local _,_,id = strfind(link,"|Hitem:(%d+):")
	cursorType = "item"
	cursorData = tonumber(id)
	cursorSubType = link
	cursorSubData = nil
end

-- ClearCursor
if not AceCore_ClearCursor then
	hooksecurefunc("ClearCursor", function()
		return _G.AceCore_ClearCursor()
	end)
end

function _G.AceCore_ClearCursor()
	cursorType, cursorData, cursorSubType, cursorSubData = nil,nil,nil,nil
end

-- PickupContainerItem
if not AceCore_PickupContainerItem then
	hooksecurefunc("PickupContainerItem",
		function(container, slot)
			return _G.AceCore_PickupContainerItem(container, slot)
		end)
end

function _G.AceCore_PickupContainerItem(container, slot)
	if CursorHasItem() then
		return setcursoritem(GetContainerItemLink(container, slot))
	end
end

-- PickupBagFromSlot
if not _G.AceCore_PickupBagFromSlot then
	hooksecurefunc("PickupBagFromSlot",
		function(inventoryID)
			return _G.AceCore_PickupBagFromSlot(inventoryID)
		end)
end

function _G.AceCore_PickupBagFromSlot(inventoryID)
	return setcursoritem(GetInventoryItemLink("player", inventoryID))
end

-- PutItemInBag
if not _G.AceCore_PutItemInBag then
	hooksecurefunc("PutItemInBag",
		function(inventoryID)
			return _G.AceCore_PutItemInBag(inventoryID)
		end)
end

function _G.AceCore_PutItemInBag(inventoryID)
	cursorType, cursorData, cursorSubType, cursorSubData = nil,nil,nil,nil
end

-- PickupSpell
if not _G.AceCore_PickupSpell then
	hooksecurefunc("PickupSpell",
		function(spellbookID, bookType)
			return _G.AceCore_PickupSpell(spellbookID, bookType)
		end)
end

function _G.AceCore_PickupSpell(spellbookID, bookType)
	cursorType = "spell"
	cursorData = spellbookID
	cursorSubType = bookType
	cursorSubData = nil	-- Ace3v: how to get spellID?
end

-- PickupMacro
if not _G.AceCore_PickupMacro then
	hooksecurefunc("PickupMacro",
		function(macroID)
			return _G.AceCore_PickupMacro(macroID)
		end)
end

function _G.AceCore_PickupMacro(macroID)
	dbg("AceCore_PickupMacro")
	cursorType = "macro"
	cursorData = macroID
	cursorSubType = nil
	cursorSubData = nil
end

-- PickupAction
if not _G.AceCore_PickupAction then
	hooksecurefunc("PickupAction",
		function(slot)
			return _G.AceCore_PickupAction(slot)
		end)
end

function _G.AceCore_PickupAction(slot)
	dbg("AceCore_PickupAction")
	cursorType = nil
	cursorData = nil
	cursorSubType = nil
	cursorSubData = nil
end

-- PlaceAction
if not _G.AceCore_PlaceAction then
	hooksecurefunc("PlaceAction",
		function(slot)
			return _G.AceCore_PlaceAction(slot)
		end)
end

function _G.AceCore_PlaceAction(slot)
	cursorType, cursorData, cursorSubType, cursorSubData = nil,nil,nil,nil
end

local function ActionButton_OnClick()
	dbg("ActionButton_OnClick")
	if ( IsShiftKeyDown() ) then
		PickupAction(ActionButton_GetPagedID(this));
	else
		if ( MacroFrame_SaveMacro ) then
			MacroFrame_SaveMacro();
		end
		UseAction(ActionButton_GetPagedID(this), 1);
	end
	ActionButton_UpdateState();
end

local function ActionButton_OnDragStart()
	if ( LOCK_ACTIONBAR ~= "1" ) then
		PickupAction(ActionButton_GetPagedID(this));
		ActionButton_UpdateHotkeys(this.buttonType);
		ActionButton_UpdateState();
		ActionButton_UpdateFlash();
	end
end

local function ActionButton_OnReceiveDrag()
	dbg("ActionButton_OnReceiveDrag")
	if ( LOCK_ACTIONBAR ~= "1" ) then
		PlaceAction(ActionButton_GetPagedID(this));
		ActionButton_UpdateHotkeys(this.buttonType);
		ActionButton_UpdateState();
		ActionButton_UpdateFlash();
	end
end

local actionButtons = {
	"ActionButton",
	"BonusActionButton",
	"MultiBarLeftButton",
	"MultiBarRightButton",
	"MultiBarBottomLeftButton",
	"MultiBarBottomRightButton",
}

for _,btn in actionButtons do
	for i=1,12 do
		local frame = _G[btn..i]
		frame:SetScript("OnDragStart",ActionButton_OnDragStart)
		frame:SetScript("OnReceiveDrag",ActionButton_OnReceiveDrag)
		frame:SetScript("OnClick",ActionButton_OnClick)
	end
end
for i=1,10 do
	local frame = _G["PetActionButton"..i]
	frame:SetScript("OnDragStart",ActionButton_OnDragStart)
	frame:SetScript("OnReceiveDrag",ActionButton_OnReceiveDrag)
	frame:SetScript("OnClick",ActionButton_OnClick)
end
