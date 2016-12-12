local ACECURSOR_MAJOR, ACECURSOR_MINOR = "AceCursor-3.0", 1
local AceCursor, oldminor = LibStub:NewLibrary(ACECURSOR_MAJOR, ACECURSOR_MINOR)

if not AceCursor then return end -- No upgrade needed

local AceCore = LibStub("AceCore-3.0")
local _G = AceCore._G
local hooksecurefunc = AceCore.hooksecurefunc

local cursorType, cursorData, cursorSubType, cursorSubData
function _G.GetCursorInfo()
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
	cursorType = "macro"
	cursorData = macroID
	cursorSubType = nil
	cursorSubData = nil
end

--[[------------------------------------
The Action part is not fully working yet
--------------------------------------]]
-- PickupAction
if not _G.AceCore_PickupAction then
	hooksecurefunc("PickupAction",
		function(slot)
			return _G.AceCore_PickupAction(slot)
		end)
end

function _G.AceCore_PickupAction(slot)
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
