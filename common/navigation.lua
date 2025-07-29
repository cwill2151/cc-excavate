---@diagnostic disable: undefined-global, undefined-field, lowercase-global

local config = require("common.config")

local navigation = {}

local pos = {x = 0, y = 0, z = 0}
local facing = 0

local directions = {
    [0] = {x = 0, z = 1},
    [1] = {x = 1, z = 0},
    [2] = {x = 0, z = -1},
    [3] = {x = -1, z = 0}
}

local turtlePositions = {}
local lastPositionBroadcast = 0

function navigation.getPosition()
    return {x = pos.x, y = pos.y, z = pos.z}
end

function navigation.getFacing()
    return facing
end

function navigation.setPosition(x, y, z, f)
    pos.x = x
    pos.y = y
    pos.z = z
    if f then facing = f end
end

function navigation.updateTurtlePosition(id, position)
    turtlePositions[id] = {
        x = position.x,
        y = position.y,
        z = position.z,
        timestamp = os.time()
    }
end

function navigation.clearOldPositions()
    local currentTime = os.time()
    for id, data in pairs(turtlePositions) do
        if currentTime - data.timestamp > config.timing.position_update * 3 then
            turtlePositions[id] = nil
        end
    end
end

function navigation.isPositionOccupied(x, y, z)
    navigation.clearOldPositions()
    
    for id, data in pairs(turtlePositions) do
        if id ~= os.getComputerID() and 
           data.x == x and data.y == y and data.z == z then
            return true, id
        end
    end
    return false
end

function navigation.isPathClear(targetX, targetY, targetZ)
    local dx = targetX - pos.x
    local dy = targetY - pos.y
    local dz = targetZ - pos.z
    
    local steps = math.max(math.abs(dx), math.abs(dy), math.abs(dz))
    if steps == 0 then return true end
    
    for i = 1, steps do
        local checkX = pos.x + math.floor(dx * i / steps + 0.5)
        local checkY = pos.y + math.floor(dy * i / steps + 0.5)
        local checkZ = pos.z + math.floor(dz * i / steps + 0.5)
        
        if navigation.isPositionOccupied(checkX, checkY, checkZ) then
            return false
        end
    end
    
    return true
end

function navigation.forward()
    local dir = directions[facing]
    local newX = pos.x + dir.x
    local newZ = pos.z + dir.z
    
    if navigation.isPositionOccupied(newX, pos.y, newZ) then
        return false, "position_occupied"
    end
    
    if turtle.forward() then
        pos.x = newX
        pos.z = newZ
        return true
    end
    return false, "blocked"
end

function navigation.back()
    local dir = directions[facing]
    local newX = pos.x - dir.x
    local newZ = pos.z - dir.z
    
    if navigation.isPositionOccupied(newX, pos.y, newZ) then
        return false, "position_occupied"
    end
    
    if turtle.back() then
        pos.x = newX
        pos.z = newZ
        return true
    end
    return false, "blocked"
end

function navigation.up()
    local newY = pos.y + 1
    
    if navigation.isPositionOccupied(pos.x, newY, pos.z) then
        return false, "position_occupied"
    end
    
    if turtle.up() then
        pos.y = newY
        return true
    end
    return false, "blocked"
end

function navigation.down()
    local newY = pos.y - 1
    
    if navigation.isPositionOccupied(pos.x, newY, pos.z) then
        return false, "position_occupied"
    end
    
    if turtle.down() then
        pos.y = newY
        return true
    end
    return false, "blocked"
end

function navigation.turnRight()
    turtle.turnRight()
    facing = (facing + 1) % 4
end

function navigation.turnLeft()
    turtle.turnLeft()
    facing = (facing + 3) % 4
end

function navigation.turnTo(targetFacing)
    local diff = (targetFacing - facing) % 4
    if diff == 0 then return end
    
    if diff <= 2 then
        for i = 1, diff do
            navigation.turnRight()
        end
    else
        navigation.turnLeft()
    end
end

function navigation.moveTo(targetX, targetY, targetZ, allowDig)
    local attempts = 0
    local maxAttempts = config.navigation.max_retries
    
    while (pos.x ~= targetX or pos.y ~= targetY or pos.z ~= targetZ) and attempts < maxAttempts do
        attempts = attempts + 1
        
        while pos.y < targetY do
            if not navigation.up() then
                if allowDig and turtle.digUp() then
                    navigation.up()
                else
                    sleep(config.timing.retry_delay)
                end
            end
        end
        
        while pos.y > targetY do
            if not navigation.down() then
                if allowDig and turtle.digDown() then
                    navigation.down()
                else
                    sleep(config.timing.retry_delay)
                end
            end
        end
        
        if pos.x < targetX then
            navigation.turnTo(1)
            while pos.x < targetX do
                if not navigation.forward() then
                    if allowDig and turtle.dig() then
                        navigation.forward()
                    else
                        break
                    end
                end
            end
        elseif pos.x > targetX then
            navigation.turnTo(3)
            while pos.x > targetX do
                if not navigation.forward() then
                    if allowDig and turtle.dig() then
                        navigation.forward()
                    else
                        break
                    end
                end
            end
        end
        
        if pos.z < targetZ then
            navigation.turnTo(0)
            while pos.z < targetZ do
                if not navigation.forward() then
                    if allowDig and turtle.dig() then
                        navigation.forward()
                    else
                        break
                    end
                end
            end
        elseif pos.z > targetZ then
            navigation.turnTo(2)
            while pos.z > targetZ do
                if not navigation.forward() then
                    if allowDig and turtle.dig() then
                        navigation.forward()
                    else
                        break
                    end
                end
            end
        end
        
        if pos.x == targetX and pos.y == targetY and pos.z == targetZ then
            return true
        end
        
        sleep(config.timing.retry_delay)
    end
    
    return pos.x == targetX and pos.y == targetY and pos.z == targetZ
end

function navigation.moveToAvoidingOthers(targetX, targetY, targetZ)
    if not navigation.isPathClear(targetX, targetY, targetZ) then
        local alternativePaths = {
            {x = targetX + 1, y = targetY, z = targetZ},
            {x = targetX - 1, y = targetY, z = targetZ},
            {x = targetX, y = targetY, z = targetZ + 1},
            {x = targetX, y = targetY, z = targetZ - 1},
            {x = targetX, y = targetY + 1, z = targetZ},
            {x = targetX, y = targetY - 1, z = targetZ}
        }
        
        for _, altPos in ipairs(alternativePaths) do
            if navigation.isPathClear(altPos.x, altPos.y, altPos.z) then
                navigation.moveTo(altPos.x, altPos.y, altPos.z, true)
                sleep(0.5)
                break
            end
        end
    end
    
    return navigation.moveTo(targetX, targetY, targetZ, true)
end

function navigation.shouldBroadcastPosition()
    local currentTime = os.time()
    if currentTime - lastPositionBroadcast >= config.timing.position_update then
        lastPositionBroadcast = currentTime
        return true
    end
    return false
end

function navigation.fuelNeededTo(targetX, targetY, targetZ)
    local distance = 0
    distance = distance + math.abs(pos.y - targetY)
    distance = distance + math.abs(pos.x - targetX)
    distance = distance + math.abs(pos.z - targetZ)
    return distance
end

return navigation