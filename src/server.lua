------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- If some thing don´t make sense then its because i am an amature and because i originaly put some debug prints inside put removed them. (I only removed the print)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local waited = 0
while GetResourceState('ox_inventory') ~= 'started' and waited < 10000 do
    Wait(500)
    waited += 500
end

local usingOx = GetResourceState('ox_inventory') == 'started'
if not usingOx then
    print('^3[next-kevlar] ^1[error]^0 ⚠️ Could not find a valid ox_inventory resource running. ^4This script requires ox_inventory to function.^0')
    return
end

local PlatesCache = {}

RegisterNetEvent('next-kevlar:openVest', function(slot)
    local playerId = source
    local itemdata = exports.ox_inventory:GetSlot(playerId, slot)
    if not slot or not itemdata or not itemdata.metadata then
        PunishPlayer(playerId, 'Invalid vest parameters provided.')
        return
    end
    if not Config.PlateCarriers[itemdata.name] then
        PunishPlayer(playerId, 'Invalid vest item parsed.')
        return
    end

    local metadata = itemdata.metadata
    if not metadata.carrierId then
        metadata = {
            carrierId = 'carrier_' .. os.time() .. math.random(1000, 9999),
            plate_type = Config.PlateCarriers[itemdata.name].plateType
        }
        exports.ox_inventory:SetMetadata(playerId, itemdata.slot, metadata)
    end

    local items = { { itemdata.name, 1, metadata } }
    local plates = metadata.plates or {}
    if next(plates) then
        for _, plate in ipairs(plates) do
            table.insert(items, { plate.itemName, 1, { itemName = plate.itemName, health = plate.health or 0 } })
        end
    end

    local cachedPlates = {}
    for _, plate in ipairs(plates) do
        table.insert(cachedPlates, {
            slot = plate.slot,
            itemName = plate.itemName,
            health = plate.health
        })
    end
    PlatesCache[metadata.carrierId] = cachedPlates
    for i, plate in ipairs(cachedPlates) do
    end

    local plateType = metadata.plate_type or 'light'
    local slots = plateType == 'heavy' and 3 or 2
    local stash = exports.ox_inventory:CreateTemporaryStash({
        label = 'Vest Plate Slots',
        slots = slots,
        maxWeight = 5000,
        owner = true,
        items = items
    })

    TriggerClientEvent('jaksam_inventory:openInventory', playerId, stash)
end)

RegisterNetEvent('next-kevlar:syncArmor', function(itemName, carrier, meta)
    local playerId = source
    local charInventory = exports.ox_inventory:GetInventory(playerId, false)
    if not charInventory or not charInventory.items then
        return
    end
    
    local carrierItem = nil
    local carrierSlot = nil
    
    for slotId, item in pairs(charInventory.items) do
        if item and item.name == itemName and item.metadata and item.metadata.carrierId == carrier then
            carrierItem = item
            carrierSlot = slotId
            break
        end
    end
    
    if not carrierItem then
        return
    end

    local filteredPlates = {}
    for i, plate in ipairs(meta or {}) do
        if plate.health and plate.health > 0 then
            table.insert(filteredPlates, {
                slot = plate.slot,
                itemName = plate.itemName,
                health = plate.health
            })
        elseif Config.UseBrokenPlates then
            table.insert(filteredPlates, { itemName = Config.BrokenPlateItem })
        end
    end

    carrierItem.metadata.plates = filteredPlates
    local success = exports.ox_inventory:SetMetadata(playerId, carrierSlot, carrierItem.metadata)
    
    TriggerClientEvent('next-kevlar:onMetadataUpdate', playerId, itemName, carrierItem.metadata)
end)


lib.callback.register('next-kevlar:registerCarrier', function(playerId, slot)
    local data = exports.ox_inventory:GetSlot(playerId, slot)
    if not data or not Config.PlateCarriers[data.name] then
        PunishPlayer(playerId, 'Tried to register a plate carrier using an executor.')
        return
    end
    local metadata = {
        carrierId = 'carrier_' .. os.time() .. math.random(1000, 9999),
        plate_type = Config.PlateCarriers[data.name].plateType
    }
    exports.ox_inventory:SetMetadata(playerId, data.slot, metadata)
    return metadata
end)

exports.jaksam_inventory:registerHook('onItemAdded', function(payload)
    if payload.item and payload.item.name and Config.Plates[payload.item.name] then
        local meta = payload.metadata or {}
        if not meta.health then
            meta.health = Config.Plates[payload.item.name] or 50
            meta.itemName = payload.item.name
            exports.ox_inventory:SetMetadata(payload.inventory, payload.slot, meta)
        end
    end
end)

exports.jaksam_inventory:registerHook('onItemTransferred', function(payload)
    SetTimeout(50, function()
        
        local playerId = payload.playerId or payload.source
        if not playerId then
            playerId = exports.ox_inventory:GetOwnerFromInventory(payload.inventoryIdFrom) or exports.ox_inventory:GetOwnerFromInventory(payload.inventoryIdTo)
        end
        if not playerId then 
            return 
        end

        local function isVestEditStash(name)
            return name and tostring(name):match('^temp%-%d+$')
        end
        
        local function isCharInventory(name)
            return name and tostring(name):match('^char%d+:')
        end
        
        local isRemovalFromStash = isVestEditStash(payload.inventoryIdFrom) and isCharInventory(payload.inventoryIdTo)
        
        if not (isVestEditStash(payload.inventoryIdFrom) or isVestEditStash(payload.inventoryIdTo)) then 
            return 
        end


        local charInventory = exports.ox_inventory:GetInventory(playerId, false)
        if not charInventory or not charInventory.items then 
            return 
        end

        local vestStash = isVestEditStash(payload.inventoryIdFrom) and payload.inventoryIdFrom or payload.inventoryIdTo
        local stashData = exports.ox_inventory:GetInventory(vestStash, false)
        local stashItems = stashData and stashData.items or {}

        for i, item in pairs(stashItems) do
            if item then
            end
        end

        local stashCarrierItem = stashItems[1]
        if not stashCarrierItem or not stashCarrierItem.metadata or not stashCarrierItem.metadata.carrierId then 
            return 
        end
        local carrierId = stashCarrierItem.metadata.carrierId

        local carrierItem
        for slotId, item in pairs(charInventory.items) do
            if item and Config.PlateCarriers[item.name] and item.metadata and item.metadata.carrierId == carrierId then
                carrierItem = item
                carrierItem.slot = slotId
                break
            end
        end
        if not carrierItem then 
            return 
        end
        local plates = {}
        for slotId, item in pairs(stashItems) do
            if slotId ~= 1 and item and item.name and item.metadata and item.metadata.health then
                plates[#plates + 1] = {
                    slot = slotId,
                    itemName = item.name,
                    health = item.metadata.health
                }
            end
        end
        
        for i, plate in ipairs(plates) do
        end

        local cachedPlates = PlatesCache[carrierId] or {}
        for i, plate in ipairs(cachedPlates) do
        end

        if isRemovalFromStash and #cachedPlates >= 2 and #plates < #cachedPlates then
            if #plates == 1 and plates[1].slot == 3 then
                plates[1].slot = 2
            elseif #plates == 0 then
                for _, plate in ipairs(cachedPlates) do
                    if plate.slot == 3 then
                        plates = {
                            {
                                slot = 2,
                                itemName = plate.itemName,
                                health = plate.health
                            }
                        }
                        break
                    end
                end
            end
        else
        end

        PlatesCache[carrierId] = plates

        carrierItem.metadata.plates = plates
        exports.ox_inventory:SetMetadata(playerId, carrierItem.slot, carrierItem.metadata)

        TriggerClientEvent('next-kevlar:onMetadataUpdate', playerId, carrierItem.name, carrierItem.metadata)
    end)
end, { inventoryFilter = { '^temp%-%d+$' } })


local ValidCarriers = {}
for item, carrier in pairs(Config.PlateCarriers) do
    ValidCarriers[item] = true
end

exports.jaksam_inventory:registerHook('onItemTransferred', function(payload)
    local playerId = payload.playerId or payload.source
    if not playerId then
        playerId = exports.ox_inventory:GetOwnerFromInventory(payload.inventoryIdFrom)
    end
    if not playerId then return end
    
    if not (payload.itemName and ValidCarriers[payload.itemName]) then
        return
    end
    
    local function isCharInventory(name)
        return name and tostring(name):match('^char%d+:')
    end
    
    local fromInv = payload.inventoryIdFrom
    local toInv = payload.inventoryIdTo
    
    local function isVestEditStash(name)
        return name and tostring(name):match('^temp%-%d+$')
    end
    
    if isCharInventory(fromInv) and not isVestEditStash(toInv) then
        local metadata = payload.metadata or {}
        TriggerClientEvent('next-kevlar:droppedVest', playerId, metadata)
    end
end, { itemFilter = ValidCarriers })



exports.jaksam_inventory:registerHook('onItemTransferred', function(payload)
    local function isVestEditStash(name)
        return name and tostring(name):match('^temp%-%d+$')
    end
    
    if not isVestEditStash(payload.inventoryIdFrom) then
        return 
    end
    
    
    if payload.slotIdFrom ~= 1 then
        return 
    end
    
    if payload.itemName and Config.PlateCarriers[payload.itemName] then
        return false, "The vest cannot be removed from this slot", "error"
    end
end, { 
    inventoryFilter = { '^temp%-%d+$' },
    priority = 100 
})

local playerInventories = {}

local function convertJaksamToOx(inv)
    if not inv or not inv.items then return {} end
    local oxItems = {}

    for slot, item in pairs(inv.items) do
        local slotNum = tonumber(string.match(slot, "%d+")) or 0
        table.insert(oxItems, {
            name = item.name or "unknown",
            label = (item.name or "unknown"):gsub("_", " "):gsub("^%l", string.upper),
            count = item.amount or 1,
            weight = 100,
            slot = slotNum,
            metadata = item.metadata or {}
        })
    end

    return oxItems
end

RegisterNetEvent('inventory:clientSendInventory', function(inv)
    local src = source
    if type(inv) ~= "table" or not inv.id then
        print(("^1[InventoryBridge]^0 Ungültige Daten von %s"):format(src))
        return
    end

    playerInventories[src] = convertJaksamToOx(inv)
end)

AddEventHandler('__cfx_export_ox_inventory_GetPlayerItems', function(setCallback)
    setCallback(function(playerId)
        if not playerId then playerId = source end
        return playerInventories[playerId] or {}
    end)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    playerInventories[src] = nil
end)



local ESX = exports.es_extended:getSharedObject()


RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)

    local src = playerId or source
    if not src then return end

    TriggerClientEvent('next-kevlar:resetArmorOnLogin', src)
end)
