---@diagnostic disable: undefined-global, undefined-field, lowercase-global
local pretty = require "cc.pretty"

local barrierBlock = "minecraft:mangrove_log"
local maxDepth = 250
local fuelMargin = 30

local pos = {x = 0, y = 0, z = 0}
local facing = 0
local lastDepositHeight = 2

local directions = {
    [0] = {x = 0, z = 1},
    [1] = {x = 1, z = 0},
    [2] = {x = 0, z = -1},
    [3] = {x = -1, z = 0}
}

local function drawMenu(selected)
    term.clear()
    term.setCursorPos(1, 1)

    term.setTextColor(colors.lime)
    print("+-------------------------------------+")
    print("|       EXCAVATOR TURTLE v1.0         |")
    print("+-------------------------------------+")
    term.setTextColor(colors.white)

    print("")

    local options = {"Start Excavation", "Configuration", "How to Use", "Exit"}

    for i, option in ipairs(options) do
        if i == selected then
            term.setTextColor(colors.black)
            term.setBackgroundColor(colors.white)
            write(" > " .. option)
            for j = 1, 35 - #option do
                write(" ")
            end
            print()
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
        else
            print("   " .. option)
        end
    end

    term.setTextColor(colors.gray)
    term.setCursorPos(1, 10)
    print("Use arrow keys to navigate, Enter to select")
    term.setTextColor(colors.white)
end


local function showHowTo()
    term.clear()
    term.setCursorPos(1, 1)

    local doc = pretty.text("Setup Instructions:", colors.yellow) .. pretty.line ..
                pretty.text("1. Place turtle at ground level") .. pretty.line ..
                pretty.text("2. Behind turtle, place:") .. pretty.line ..
                pretty.text("   - Fuel chest at Y+1") .. pretty.line ..
                pretty.text("   - Deposit chests at Y+2 and up") .. pretty.line ..
                pretty.text("3. Surround area with barrier blocks") .. pretty.line ..
                pretty.text("4. Add fuel to fuel chest") .. pretty.line ..
                pretty.text("5. Run program and select Start") .. pretty.line .. pretty.line ..
                pretty.text("Press any key to return...", colors.gray)

    pretty.print(doc)
    os.pullEvent("key")
end

local function showConfig()
    term.clear()
    term.setCursorPos(1, 1)

    local title = pretty.text("+---------------------------------------+", colors.lime) .. pretty.line ..
                  pretty.text("|            CONFIGURATION              |", colors.lime) .. pretty.line ..
                  pretty.text("+---------------------------------------+", colors.lime) .. pretty.line .. pretty.line

    local configDoc = title ..
                      pretty.text("Current Settings:", colors.yellow) .. pretty.line ..
                      pretty.pretty({
                          ["Barrier Block"] = barrierBlock,
                          ["Max Depth"] = maxDepth .. " blocks",
                          ["Fuel Margin"] = tostring(fuelMargin),
                          ["Current Fuel"] = tostring(turtle.getFuelLevel())
                      }) .. pretty.line .. pretty.line ..
                      pretty.text("Press any key to return...", colors.gray) .. pretty.line ..
                      pretty.text("(Edit config in source code)", colors.gray)

    pretty.print(configDoc)
    os.pullEvent("key")
end

local function mainMenu()
    local selected = 1

    while true do
        drawMenu(selected)

        local _, key = os.pullEvent("key")

        if key == keys.up then
            selected = selected > 1 and selected - 1 or 4
        elseif key == keys.down then
            selected = selected < 4 and selected + 1 or 1
        elseif key == keys.enter then
            if selected == 1 then
                return true
            elseif selected == 2 then
                showConfig()
            elseif selected == 3 then
                showHowTo()
            elseif selected == 4 then
                term.clear()
                term.setCursorPos(1, 1)
                return false
            end
        end
    end
end

local function forward()
    if turtle.forward() then
        local dir = directions[facing]
        pos.x = pos.x + dir.x
        pos.z = pos.z + dir.z
        return true
    end
    return false
end

local function back()
    if turtle.back() then
        local dir = directions[facing]
        pos.x = pos.x - dir.x
        pos.z = pos.z - dir.z
        return true
    end
    return false
end

local function up()
    if turtle.up() then
        pos.y = pos.y + 1
        return true
    end
    return false
end

local function down()
    if turtle.down() then
        pos.y = pos.y - 1
        return true
    end
    return false
end

local function turnRight()
    turtle.turnRight()
    facing = (facing + 1) % 4
end

local function turnLeft()
    turtle.turnLeft()
    facing = (facing + 3) % 4
end

local function turnTo(targetFacing)
    local diff = (targetFacing - facing) % 4
    if diff == 0 then return end

    if diff <= 2 then
        for i = 1, diff do
            turnRight()
        end
    else
        turnLeft()
    end
end

local function fuelNeededTo(targetX, targetY, targetZ)
    local distance = 0
    distance = distance + math.abs(pos.y - targetY)
    distance = distance + math.abs(pos.x - targetX)
    distance = distance + math.abs(pos.z - targetZ)
    return distance
end

local function isInventoryFull()
    local fullSlots = 0
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            fullSlots = fullSlots + 1
        end
    end
    return fullSlots >= 15
end

function findChest()
    local startFacing = facing

    for i = 0, 3 do
        turnRight()
        local success, block = turtle.inspect()
        if success and block.name == "minecraft:chest" then
            pretty.print(pretty.text("Found chest at facing " .. i, colors.green))
            return true, startFacing
        end
    end
end

local function depositItems()
    pretty.print(pretty.text(">> Depositing items...", colors.yellow))

    local startPos = {x = pos.x, y = pos.y, z = pos.z}
    local startFacing = facing

    moveTo(0, 0, 0)

    while pos.y < lastDepositHeight do
        up()
    end

    local success, _ = findChest()
    if not success then
        error("ERROR No deposit chest found")
    end

    local deposited = false
    while not deposited do
        deposited = true

        for slot = 1, 16 do
            turtle.select(slot)
            if turtle.getItemCount(slot) > 0 then
                if not turtle.drop() then
                    deposited = false
                    break
                end
            end
        end

        if not deposited then
            up()
            lastDepositHeight = pos.y
        end
    end

    pretty.print(pretty.text("OK Deposited at height " .. pos.y, colors.green))

    moveTo(startPos.x, startPos.y, startPos.z)
    turnTo(startFacing)

    turtle.select(1)
end

function moveTo(targetX, targetY, targetZ)
    if isInventoryFull() and not (targetY == 0 and targetX == 0 and targetZ == 0) then
        depositItems()
    end

    local fuelNeeded = fuelNeededTo(targetX, targetY, targetZ)
    local fuelToOrigin = fuelNeededTo(0, 0, 0) + 1
    local currentFuel = turtle.getFuelLevel()

    if currentFuel ~= "unlimited" and currentFuel < (fuelNeeded + fuelToOrigin + fuelMargin) then
        pretty.print(pretty.text("Low fuel, refueling...", colors.orange))
        refuelFromChest()
    end

    while pos.y < targetY do
        up()
    end
    while pos.y > targetY do
        down()
    end

    if pos.x < targetX then
        turnTo(1)
        while pos.x < targetX do
            turtle.dig()
            forward()
        end
    elseif pos.x > targetX then
        turnTo(3)
        while pos.x > targetX do
            turtle.dig()
            forward()
        end
    end

    if pos.z < targetZ then
        turnTo(0)
        while pos.z < targetZ do
            turtle.dig()
            forward()
        end
    elseif pos.z > targetZ then
        turnTo(2)
        while pos.z > targetZ do
            turtle.dig()
            forward()
        end
    end
end

function refuelFromChest()
    local startPos = {x = pos.x, y = pos.y, z = pos.z}
    local startFacing = facing

    moveTo(0, 0, 0)

    up()

    local success, _ = findChest()
    if not success then
        pretty.print(pretty.text("ERROR No refuel chest found", colors.red))
        return
    end

    turtle.select(1)
    for slot = 2, 16 do
        if turtle.getItemCount(1) == 0 then break end
        turtle.transferTo(slot)
    end

    if turtle.suck() then
        turtle.refuel()
        pretty.print(pretty.text("OK Fuel level: " .. tostring(turtle.getFuelLevel()), colors.green))
    else
        pretty.print(pretty.text("ERROR No fuel available", colors.red))
    end

    moveTo(startPos.x, startPos.y, startPos.z)
    turnTo(startFacing)
end


local function isBarrierAhead()
    local success, block = turtle.inspect()
    return success and block.name == barrierBlock
end

local function measureArea()
    pretty.print(pretty.line .. pretty.text(">> Measuring excavation area...", colors.cyan))

    local measurements = {}

    for direction = 0, 3 do
        turnTo(direction)
        local distance = 0

        while not isBarrierAhead() do
            if forward() then
                distance = distance + 1
            else
                pretty.print(pretty.text("ERROR Blocked by non-barrier block", colors.red))
                return nil
            end

            if distance > 100 then
                pretty.print(pretty.text("ERROR No barrier found within 100 blocks", colors.red))
                return nil
            end
        end

        measurements[direction] = distance
        local dirs = {"North", "East", "South", "West"}
        pretty.print(pretty.text("  " .. dirs[direction + 1] .. ": " .. distance .. " blocks", colors.gray))

        moveTo(0, 0, 0)
    end

    return {
        north = measurements[0],
        east = measurements[1],
        south = measurements[2],
        west = measurements[3]
    }
end

local function mineLayer(bounds)
    local minX = -bounds.west
    local maxX = bounds.east
    local minZ = -bounds.south
    local maxZ = bounds.north

    for x = minX, maxX do
        if x % 2 == 0 then
            for z = minZ, maxZ do
                moveTo(x, pos.y, z)
                turtle.digDown()
            end
        else
            for z = maxZ, minZ, -1 do
                moveTo(x, pos.y, z)
                turtle.digDown()
            end
        end
    end

    moveTo(0, pos.y, 0)
end

if not mainMenu() then
    return
end

term.clear()
term.setCursorPos(1, 1)

if turtle.getFuelLevel() < fuelMargin then
    pretty.print(pretty.line .. pretty.text("ERROR Insufficient fuel", colors.red))
    return
end

local bounds = measureArea()
if not bounds then
    pretty.print(pretty.line .. pretty.text("ERROR Failed to measure area", colors.red))
    return
end

pretty.print(pretty.line .. pretty.text(string.format(">> Area: %dx%d blocks",
    bounds.north + bounds.south,
    bounds.east + bounds.west), colors.lime))

local layersMined = 0

while layersMined < maxDepth do
    pretty.print(pretty.line .. pretty.text(string.format(">> Layer %d/%d (Y=%d)",
        layersMined + 1, maxDepth, -pos.y), colors.cyan))

    mineLayer(bounds)

    if isInventoryFull() then
        depositItems()
    end

    if down() then
        layersMined = layersMined + 1
    else
        pretty.print(pretty.line .. pretty.text(">> Reached bedrock or obstruction", colors.yellow))
        break
    end
end

pretty.print(pretty.line .. pretty.text(">> Returning to surface...", colors.cyan))
moveTo(0, 0, 0)
turnTo(0)

if isInventoryFull() or turtle.getItemCount(2) > 0 then
    depositItems()
end

local completion = pretty.line ..
    pretty.text("+---------------------------------------+", colors.lime) .. pretty.line ..
    pretty.text("|         EXCAVATION COMPLETE!          |", colors.lime) .. pretty.line ..
    pretty.text("+---------------------------------------+", colors.lime) .. pretty.line .. pretty.line ..
    pretty.text("Mined " .. layersMined .. " layers") .. pretty.line ..
    pretty.text(string.format("Final position: (%d, %d, %d)", pos.x, pos.y, pos.z))

pretty.print(completion)
