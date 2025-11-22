-- Warten auf ox_inventory
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

-- ** CACHE für Plates pro CarrierId **
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

    -- ** Cache die aktuellen Plates beim Öffnen (deep copy) **
    local cachedPlates = {}
    for _, plate in ipairs(plates) do
        table.insert(cachedPlates, {
            slot = plate.slot,
            itemName = plate.itemName,
            health = plate.health
        })
    end
    PlatesCache[metadata.carrierId] = cachedPlates

    -- print("========================================")
    -- print("[DEBUG] Vest geöffnet für carrierId: " .. metadata.carrierId)
    -- print("[DEBUG] Cache gesetzt mit " .. #cachedPlates .. " Plates:")
    for i, plate in ipairs(cachedPlates) do
        -- print("  [" .. i .. "] Slot: " .. plate.slot .. ", Item: " .. plate.itemName .. ", Health: " .. plate.health)
    end
    -- print("========================================")

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
    local data = exports.ox_inventory:GetSlotWithItem(playerId, itemName, { carrierId = carrier }, false)
    if not data then
        PunishPlayer(playerId, 'Tried to sync metadata using an executor.')
        return
    end

    local filteredPlates = {}
    for _, plate in ipairs(meta or {}) do
        if plate.health and plate.health > 0 then
            table.insert(filteredPlates, plate)
        elseif Config.UseBrokenPlates then
            table.insert(filteredPlates, { itemName = Config.BrokenPlateItem })
        end
    end

    data.metadata.plates = filteredPlates
    exports.ox_inventory:SetMetadata(playerId, data.slot, data.metadata)
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
            -- print("[DEBUG] onItemAdded: Plate mit health gesetzt:", payload.item.name, meta.health)
        end
    end
end)

exports.jaksam_inventory:registerHook('onItemTransferred', function(payload)
    SetTimeout(50, function()
        -- print("\n========================================")
        -- print("[DEBUG] onItemTransferred getriggert!")
        
        local playerId = payload.playerId or payload.source
        if not playerId then
            playerId = exports.ox_inventory:GetOwnerFromInventory(payload.inventoryIdFrom) or exports.ox_inventory:GetOwnerFromInventory(payload.inventoryIdTo)
        end
        if not playerId then 
            -- print("[DEBUG] Kein playerId gefunden, Abbruch")
            -- print("========================================\n")
            return 
        end
        -- print("[DEBUG] PlayerId: " .. playerId)

        local function isVestEditStash(name)
            return name and tostring(name):match('^temp%-%d+$')
        end
        
        local function isCharInventory(name)
            return name and tostring(name):match('^char%d+:')
        end
        
        -- Prüfe: Transfer AUS temp-Stash INS char-Inventar (= Plate wurde entfernt)
        local isRemovalFromStash = isVestEditStash(payload.inventoryIdFrom) and isCharInventory(payload.inventoryIdTo)
        
        if not (isVestEditStash(payload.inventoryIdFrom) or isVestEditStash(payload.inventoryIdTo)) then 
            -- print("[DEBUG] Kein Vest-Stash beteiligt, Abbruch")
            -- print("========================================\n")
            return 
        end
        -- print("[DEBUG] Vest-Stash erkannt!")

        local charInventory = exports.ox_inventory:GetInventory(playerId, false)
        if not charInventory or not charInventory.items then 
            -- print("[DEBUG] Spieler-Inventar nicht gefunden, Abbruch")
            -- print("========================================\n")
            return 
        end

        local vestStash = isVestEditStash(payload.inventoryIdFrom) and payload.inventoryIdFrom or payload.inventoryIdTo
        local stashData = exports.ox_inventory:GetInventory(vestStash, false)
        local stashItems = stashData and stashData.items or {}
        
        -- print("[DEBUG] Stash Items nach Transfer:")
        for i, item in pairs(stashItems) do
            if item then
                -- print("  Slot " .. i .. ": " .. item.name .. " (health: " .. tostring(item.metadata and item.metadata.health or "N/A") .. ")")
            end
        end

        local stashCarrierItem = stashItems[1]
        if not stashCarrierItem or not stashCarrierItem.metadata or not stashCarrierItem.metadata.carrierId then 
            -- print("[DEBUG] Kein Carrier im Stash gefunden, Abbruch")
            -- print("========================================\n")
            return 
        end
        local carrierId = stashCarrierItem.metadata.carrierId
        -- print("[DEBUG] CarrierId: " .. carrierId)

        local carrierItem
        for slotId, item in pairs(charInventory.items) do
            if item and Config.PlateCarriers[item.name] and item.metadata and item.metadata.carrierId == carrierId then
                carrierItem = item
                carrierItem.slot = slotId
                break
            end
        end
        if not carrierItem then 
            -- print("[DEBUG] Carrier im Spieler-Inventar nicht gefunden, Abbruch")
            -- print("========================================\n")
            return 
        end
        -- print("[DEBUG] Carrier gefunden in Slot: " .. carrierItem.slot)

        -- WICHTIG: Mit pairs() arbeiten, nicht mit numerischer Schleife!
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
        
        -- print("[DEBUG] Plates aus Stash gelesen: " .. #plates .. " Stück")
        for i, plate in ipairs(plates) do
            -- print("  [" .. i .. "] Slot: " .. plate.slot .. ", Item: " .. plate.itemName .. ", Health: " .. plate.health)
        end

        local cachedPlates = PlatesCache[carrierId] or {}
        -- print("[DEBUG] Gecachte Plates: " .. #cachedPlates .. " Stück")
        for i, plate in ipairs(cachedPlates) do
            -- print("  [" .. i .. "] Slot: " .. plate.slot .. ", Item: " .. plate.itemName .. ", Health: " .. plate.health)
        end

        -- WORKAROUND: Wenn aus Stash entfernt wurde UND Cache hatte 2 Plates UND jetzt ist weniger
        if isRemovalFromStash and #cachedPlates >= 2 and #plates < #cachedPlates then
            -- print("[DEBUG] ✅ WORKAROUND AKTIV: Plate wurde aus Stash entfernt, Cache wird verwendet!")
            
            -- Wenn jetzt nur noch 1 Plate im Stash ist (in Slot 3), verschiebe sie auf Slot 2
            if #plates == 1 and plates[1].slot == 3 then
                plates[1].slot = 2
                -- print("[DEBUG] ✅✅✅ Plate von Slot 3 auf Slot 2 verschoben!")
            -- Wenn gar keine Plate mehr im Stash ist, rette die aus Slot 3 vom Cache
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
                        -- print("[DEBUG] ✅✅✅ Plate aus Cache (Slot 3) auf Slot 2 gerettet!")
                        break
                    end
                end
            end
        else
            -- print("[DEBUG] Workaround nicht aktiv - isRemoval: " .. tostring(isRemovalFromStash) .. ", Cache: " .. #cachedPlates .. ", Stash: " .. #plates)
        end

        PlatesCache[carrierId] = plates
        -- print("[DEBUG] Cache aktualisiert mit " .. #plates .. " Plates")

        carrierItem.metadata.plates = plates
        exports.ox_inventory:SetMetadata(playerId, carrierItem.slot, carrierItem.metadata)
        -- print("[DEBUG] ✅ Metadata im Carrier gespeichert!")
        -- print("[DEBUG] Finale Plates in Metadata: " .. json.encode(plates))
        -- print("========================================\n")

        TriggerClientEvent('next-kevlar:onMetadataUpdate', playerId, carrierItem.name, carrierItem.metadata)
    end)
end, { inventoryFilter = { '^temp%-%d+$' } })


local ValidCarriers = {}
for item, carrier in pairs(Config.PlateCarriers) do
    ValidCarriers[item] = true
end

exports.jaksam_inventory:registerHook('onItemTransferred', function(payload)
    local playerId = payload.source
    local fromInv = payload.inventoryIdFrom
    local toInv = payload.inventoryIdTo
    if fromInv == playerId and toInv ~= playerId then
        TriggerClientEvent('next-kevlar:droppedVest', playerId, payload.fromSlot.metadata)
    end
end, { itemFilter = ValidCarriers })

for item, armor in pairs(Config.Plates) do
    exports.jaksam_inventory:registerHook('onItemCreated', function(payload)
        if payload.item.name ~= item then return end
        if payload.metadata and payload.metadata.health then return end
        return {
            itemName = item,
            health = math.min(50, math.max(0, armor))
        }
    end, { itemFilter = { [item] = true } })
end


-- Hook: Verhindere das Entfernen des Vests (Slot 1) aus dem temp-Stash
exports.jaksam_inventory:registerHook('onItemTransferred', function(payload)
    -- Prüfe, ob Transfer AUS einem temp-Stash (Vest-Stash)
    local function isVestEditStash(name)
        return name and tostring(name):match('^temp%-%d+$')
    end
    
    if not isVestEditStash(payload.inventoryIdFrom) then
        return -- Nicht relevant
    end
    
    -- Prüfe, ob aus Slot 1 entfernt wird
    if payload.slotIdFrom ~= 1 then
        return -- Nicht Slot 1, erlauben
    end
    
    -- Prüfe, ob es ein PlateCarrier ist
    if payload.itemName and Config.PlateCarriers[payload.itemName] then
        -- Blockiere das Entfernen!
        return false, "The vest cannot be removed from this slot", "error"
    end
end, { 
    inventoryFilter = { '^temp%-%d+$' },
    priority = 100  -- Hohe Priorität, damit dieser Hook zuerst läuft
})
