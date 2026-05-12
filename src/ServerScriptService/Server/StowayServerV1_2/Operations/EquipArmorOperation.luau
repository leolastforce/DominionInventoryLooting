-- src/server/StowayServerV1.2/Operations/EquipArmorOperation.luau
-- Handles equipping/unequipping armor items

local EquipArmorOperation = {}

local SlotManager = require(script.Parent.Parent.Core.SlotManager)

export type EquipArmorResult = {
	success: boolean,
	reason: string?,
	previousUUID: string?,
	currentUUID: string?
}

--// Equip armor by UUID
function EquipArmorOperation.Equip(state: any, player: Player, uuid: string, slotType: string): EquipArmorResult
	local item = state.Items[uuid]
	if not item then
		return { success = false, reason = "ITEM_NOT_FOUND" }
	end
	
	-- Check if item is armor and matches slot
	local metadata = item.Metadata or {}
	if metadata.ItemType ~= "Armor" or metadata.ArmorSlot ~= slotType then
		return { success = false, reason = "INVALID_ITEM_FOR_SLOT" }
	end
	
	local previousUUID = state.Equipment.Armor[slotType]
	
	-- Unequip current if different
	if previousUUID and previousUUID ~= uuid then
		EquipArmorOperation.Unequip(state, player, slotType)
	end
	
	-- Set equipped
	state.Equipment.Armor[slotType] = uuid
	
	-- TODO: Apply armor benefits (e.g., defense stats) - implement in separate gameplay scripts
	
	return { success = true, previousUUID = previousUUID, currentUUID = uuid }
end

--// Unequip armor from slot
function EquipArmorOperation.Unequip(state: any, player: Player, slotType: string): EquipArmorResult
	if not state.Equipment.Armor[slotType] then
		return { success = false, reason = "NOTHING_EQUIPPED" }
	end
	
	local previousUUID = state.Equipment.Armor[slotType]
	
	-- Clear equipped state
	state.Equipment.Armor[slotType] = nil
	
	-- TODO: Remove armor benefits - implement in separate gameplay scripts
	
	return { success = true, previousUUID = previousUUID, currentUUID = nil }
end

return EquipArmorOperation