-- src/client/StowayClientv1.2/Operations/EquipWeaponOperationClient.luau
-- Client-side weapon equipping operations

local EquipWeaponOperationClient = {}

local NetworkHandler = require(script.Parent.Parent.NetworkFunctions.NetworkHandler)

--// Equip weapon by UUID
function EquipWeaponOperationClient.Equip(uuid: string, slotType: string)
	NetworkHandler.Send("EquipWeapon", { uuid = uuid, slotType = slotType })
	return { success = true } -- Assume success, replication will update state
end

--// Unequip weapon from slot
function EquipWeaponOperationClient.Unequip(slotType: string)
	NetworkHandler.Send("UnequipWeapon", { slotType = slotType })
	return { success = true } -- Assume success, replication will update state
end

--// Cycle weapons
function EquipWeaponOperationClient.Cycle(direction: number)
	NetworkHandler.Send("CycleWeapons", { direction = direction })
	return { success = true } -- Assume success, replication will update state
end

return EquipWeaponOperationClient
