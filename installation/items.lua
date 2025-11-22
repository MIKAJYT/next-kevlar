-- Do NOT replace your items.lua file with this one.
-- Instead, copy the contents of this file and paste it into your own items.lua file.
Items = {

-- Copy from HERE
['heavypc'] = {
        label = 'Heavy Plate Carrier',
        weight = 1.5,
        stackable = false,
        close = false,
        description = 'Modular vest with 2 plate slots.',
        maxStack = 100, -- does not actually stack because stackable is false
        type = 'item',
        contextActions = {
    {
        label = 'Manage Plates',
        icon = 'bi-search',
        callback = function(inventoryId, slotIndex)
            exports['next-kevlar']:managePlates(slotIndex)
        end
    }
    },
        oxClientExport = "next-kevlar.useVest"
        
    },

['lightpc'] = {
        label = 'Light Plate Carrier',
        weight = 1.0,
        stackable = false,
        close = false,
        description = 'Modular vest with a plate slot.',
        maxStack = 100, -- does not actually stack because stackable is false
        type = 'item',
    contextActions = {
    {
        label = 'Manage Plates',
        icon = 'bi-search',
        callback = function(inventoryId, slotIndex)
            exports['next-kevlar']:managePlates(slotIndex)
        end
    }
    },
    oxClientExport = "next-kevlar.useVest"
        
    },

['lightplate'] = {
        label = 'Light Plate',
        weight = 0.25,
        stackable = false,
        close = false,
        description = 'A light plate, made of Polyethylene',
        maxStack = 100,
        type = 'item',
        metadata = {
            health = 25,
            itemname = 'lightplate',
        },
        throwableOptions = false,
        displayFields = {
    { field = 'health', label = 'Plate Health: ${value}/25'}, -- Random example
    },
},

['heavyplate'] = {
        label = 'Heavy Plate',
        weight = 0.5,
        stackable = false,
        close = false,
        description = 'A heavy plate, made of Ceramics',
        maxStack = 100,
        type = 'item',
        metadata = {
            health = 50,
            itemname = 'heavyplate',
        },
        throwableOptions = false,
        displayFields = {
    { field = 'health', label = 'Plate Health: ${value}/50'}, -- Random example
    },
},

['brokenplate'] = {
        label = 'Broken Plate',
        weight = 0.5,
        stackable = false,
        close = false,
        description = 'This plate has shattered!',
        maxStack = 100, -- does not actually stack because stackable is false
        metadata = {
            health = 0,
            itemname = 'brokenplate',
        },
        throwableOptions = false,
    },
-- To HERE

}
