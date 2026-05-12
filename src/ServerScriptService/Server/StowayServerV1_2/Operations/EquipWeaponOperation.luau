-- src/server/StowayServerV1.2/Operations/EquipWeaponOperation.luau
-- Handles equipping/unequipping weapon items

local EquipWeaponOperation = {}

local SlotManager = require(script.Parent.Parent.Core.SlotManager)
local EquipOperation = require(script.Parent.EquipOperation)

export type EquipWeaponResult = {
	success: boolean,
	reason: string?,
	previousUUID: string?,
	currentUUID: string?
}

--// Equip weapon by UUID
function EquipWeaponOperation.Equip(state: any, player: Player, uuid: string, slotType: string): EquipWeaponResult
	local item = state.Items[uuid]
	if not item then
		return { success = false, reason = "ITEM_NOT_FOUND" }
	end
	
	-- Check if item is weapon and matches slot
	local metadata = item.Metadata or {}
	if metadata.ItemType ~= "Weapon" or metadata.WeaponSlot ~= slotType then
		return { success = false, reason = "INVALID_ITEM_FOR_SLOT" }
	end
	
	local previousUUID = state.Equipment.Weapons[slotType]
	
	-- Unequip current if different
	if previousUUID and previousUUID ~= uuid then
		EquipWeaponOperation.Unequip(state, player, slotType)
	end
	
	-- Set equipped
	state.Equipment.Weapons[slotType] = uuid
	
	-- If equipping Primary, also equip the tool
	if slotType == "Primary" then
		EquipOperation.Equip(state, player, uuid)
	end
	
	-- TODO: Apply weapon benefits (e.g., damage stats) - implement in separate gameplay scripts
	
	return { success = true, previousUUID = previousUUID, currentUUID = uuid }
end

--// Unequip weapon from slot
function EquipWeaponOperation.Unequip(state: any, player: Player, slotType: string): EquipWeaponResult
	if not state.Equipment.Weapons[slotType] then
		return { success = false, reason = "NOTHING_EQUIPPED" }
	end
	
	local previousUUID = state.Equipment.Weapons[slotType]
	
	-- Clear equipped state
	state.Equipment.Weapons[slotType] = nil
	
	-- If unequipping Primary, also unequip the tool
	if slotType == "Primary" then
		EquipOperation.Unequip(state, player)
	end
	
	-- TODO: Remove weapon benefits - implement in separate gameplay scripts
	
	return { success = true, previousUUID = previousUUID, currentUUID = nil }
end

--// Cycle weapons (for scrollwheel or keybind)
function EquipWeaponOperation.Cycle(state: any, player: Player, direction: number): EquipWeaponResult
	local weapons = state.Equipment.Weapons
	local weaponOrder = { "Primary", "Secondary" }
	
	-- Find current equipped weapon slot
	local currentSlot = nil
	if state.EquippedItemUUID then
		for slot, uuid in pairs(weapons) do
			if uuid == state.EquippedItemUUID then
				currentSlot = slot
				break
			end
		end
	end
	
	-- Determine next slot
	local nextSlot
	if not currentSlot then
		nextSlot = weaponOrder[1] -- Start with Primary
	else
		local currentIndex = table.find(weaponOrder, currentSlot)
		if direction > 0 then
			nextSlot = weaponOrder[currentIndex % #weaponOrder + 1]
		else
			nextSlot = weaponOrder[(currentIndex - 2) % #weaponOrder + 1]
		end
	end
	
	-- Equip next weapon if available
	local nextUUID = weapons[nextSlot]
	if nextUUID then
		return EquipWeaponOperation.Equip(state, player, nextUUID, nextSlot)
	else
		return { success = false, reason = "NO_WEAPON_IN_SLOT" }
	end
end

return EquipWeaponOperation