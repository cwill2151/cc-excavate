---@diagnostic disable: undefined-global, undefined-field, lowercase-global

local config = require("excavation.common.config")

local inventory = {}

function inventory.getEmptySlots()
    local empty = 0
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            empty = empty + 1
        end
    end
    return empty
end

function inventory.getUsedSlots()
    return 16 - inventory.getEmptySlots()
end

function inventory.isFull()
    return inventory.getEmptySlots() == 0
end

function inventory.isNearlyFull()
    return inventory.getUsedSlots() >= config.inventory.deposit_threshold
end

function inventory.isCritical()
    return inventory.getUsedSlots() >= config.inventory.critical_threshold
end

function inventory.getTotalItems()
    local total = 0
    for slot = 1, 16 do
        total = total + turtle.getItemCount(slot)
    end
    return total
end

function inventory.consolidate()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            for targetSlot = 1, slot - 1 do
                if turtle.getItemCount(targetSlot) == 0 or turtle.compareTo(targetSlot) then
                    turtle.transferTo(targetSlot)
                    if turtle.getItemCount(slot) == 0 then
                        break
                    end
                end
            end
        end
    end
    turtle.select(1)
end

function inventory.findItemSlot(itemName)
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == itemName then
            return slot
        end
    end
    return nil
end

function inventory.countItem(itemName)
    local count = 0
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and item.name == itemName then
            count = count + item.count
        end
    end
    return count
end

function inventory.depositAll()
    local deposited = 0
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            if turtle.drop() then
                deposited = deposited + 1
            else
                turtle.select(1)
                return false, deposited
            end
        end
    end
    turtle.select(1)
    return true, deposited
end

function inventory.depositAllExcept(keepItems)
    local deposited = 0
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and not keepItems[item.name] then
            turtle.select(slot)
            if turtle.drop() then
                deposited = deposited + 1
            else
                turtle.select(1)
                return false, deposited
            end
        end
    end
    turtle.select(1)
    return true, deposited
end

function inventory.suckFuel()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            turtle.select(slot)
            if turtle.suck() then
                local item = turtle.getItemDetail(slot)
                if item and turtle.getFuelLevel() ~= "unlimited" then
                    if turtle.refuel() then
                        return true, turtle.getFuelLevel()
                    end
                end
            end
            break
        end
    end
    turtle.select(1)
    return false, turtle.getFuelLevel()
end

function inventory.refuelFromInventory()
    local startFuel = turtle.getFuelLevel()
    if startFuel == "unlimited" then
        return true, startFuel
    end
    
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.refuel(0) then
            turtle.refuel()
        end
    end
    
    turtle.select(1)
    local endFuel = turtle.getFuelLevel()
    return endFuel > startFuel, endFuel
end

function inventory.getInventorySnapshot()
    local snapshot = {}
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then
            snapshot[slot] = {
                name = item.name,
                count = item.count,
                damage = item.damage
            }
        end
    end
    return snapshot
end

function inventory.hasSpaceFor(itemCount)
    local emptySlots = inventory.getEmptySlots()
    return emptySlots * 64 >= itemCount
end

return inventory