-- src/client/StowayClientv1.2/Operations/EquipArmorOperationClient.luau
-- Client-side armor equipping operations

local EquipArmorOperationClient = {}

local NetworkHandler = require(script.Parent.Parent.NetworkFunctions.NetworkHandler)

--// Equip armor by UUID
function EquipArmorOperationClient.Equip(uuid: string, slotType: string)
	NetworkHandler.Send("EquipArmor", { uuid = uuid, slotType = slotType })
	return { success = true } -- Assume success, replication will update state
end

--// Unequip armor from slot
function EquipArmorOperationClient.Unequip(slotType: string)
	NetworkHandler.Send("UnequipArmor", { slotType = slotType })
	return { success = true } -- Assume success, replication will update state
end

return EquipArmorOperationClient