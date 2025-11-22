------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- If some thing don´t make sense then its because i am an amature and because i originaly put some debug prints inside put removed them. (I only removed the print)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------


local equippedVest, pedArmor, plateMeta

CreateThread(function()
    exports.ox_inventory:displayMetadata('health', 'Plate Health')
end)

local function PlayVestAnimation(action)
    local ped = PlayerPedId()
    local dict, anim = 'clothingtie', 'try_tie_neutral_c'
    lib.requestAnimDict(dict)
    local label = action=='equip' and 'Putting on vest...' or 'Removing vest...'
    local duration = 2000
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration, 49, 0, false, false, false)
    lib.progressCircle({ duration=duration, position='bottom', label=label, useWhileDead=false, canCancel=false, disable={car=true,combat=true} })
    ClearPedTasks(ped)
end

exports('useVest', function(item, data)
    if not CanEquipVest() then return end
    local ped = PlayerPedId()
    local metadata = data.metadata
    if not metadata.carrierId then
        metadata = lib.callback.await('next-kevlar:registerCarrier', false, data.slot)
    end

    if equippedVest then
        PlayVestAnimation('remove')
        SetPedArmour(ped,0)
        SetPedComponentVariation(ped,equippedVest.original.category,equippedVest.original.drawable,equippedVest.original.texture,0)
        pedArmor=0
        if equippedVest.carrierId==metadata.carrierId then equippedVest=nil return end
    end

    equippedVest={}
    local model=GetEntityModel(ped)
    local isMale=model==`mp_m_freemode_01`
    local vest=Config.PlateCarriers[data.name]
    local category=vest.clothing[isMale and "male" or "female"].drawableCategory
    equippedVest.itemName=data.name
    equippedVest.carrierId=metadata.carrierId
    equippedVest.original={ category=category, drawable=GetPedDrawableVariation(ped,category), texture=GetPedTextureVariation(ped,category) }
    local vestAppearance=vest.clothing[isMale and "male" or "female"]
    if vestAppearance then
        PlayVestAnimation('equip')
        SetPedComponentVariation(ped,vestAppearance.drawableCategory,vestAppearance.drawable,vestAppearance.texture,0)
        plateMeta=metadata.plates or {}
        local totalArmor=0
        for _,plate in ipairs(plateMeta) do if plate.health and plate.health>0 then totalArmor+=plate.health end end
        pedArmor=math.min(totalArmor,100)
        SetPedArmour(ped,pedArmor)
    end
end)

exports('managePlates', function(slot)
    TriggerServerEvent('next-kevlar:openVest', slot)
end)

RegisterNetEvent('next-kevlar:onMetadataUpdate', function(itemName, metadata)
    if not equippedVest or equippedVest.carrierId~=metadata.carrierId then return end
    plateMeta=metadata.plates or {}
    local totalArmor=0
    for _,plate in ipairs(plateMeta) do if plate.health>0 then totalArmor+=plate.health end end
    pedArmor=math.min(totalArmor,100)
    SetPedArmour(PlayerPedId(),pedArmor)
end)

RegisterNetEvent('next-kevlar:droppedVest', function(metadata)
    if not equippedVest or equippedVest.carrierId~=metadata.carrierId then return end
    local ped=PlayerPedId()
    SetPedArmour(ped,0)
    SetPedComponentVariation(ped,equippedVest.original.category,equippedVest.original.drawable,equippedVest.original.texture,0)
    pedArmor=0
    equippedVest=nil
end)

CreateThread(function()
    while true do
        Wait(500)
        
        if equippedVest and pedArmor then
            local ped = PlayerPedId()
            local currentArmor = GetPedArmour(ped)
            
            if currentArmor < pedArmor then
                local armorLost = pedArmor - currentArmor
                if plateMeta and #plateMeta > 0 then
                    
                    local remainingDamage = armorLost
                    
                    for i, plate in ipairs(plateMeta) do
                        if remainingDamage <= 0 then
                            break 
                        end
                        
                        if plate.health and plate.health > 0 then
                            local oldHealth = plate.health
                            local damageToThisPlate = math.min(plate.health, remainingDamage)
                            plate.health = plate.health - damageToThisPlate
                            remainingDamage = remainingDamage - damageToThisPlate
                        
                        end
                    end
                
                    TriggerServerEvent('next-kevlar:syncArmor', equippedVest.itemName, equippedVest.carrierId, plateMeta)
                end
                
                pedArmor = currentArmor
            end
        end
    end
end)

