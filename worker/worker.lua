---@diagnostic disable: undefined-global, undefined-field, lowercase-global

local pretty = require("cc.pretty")
local config = require("excavate-common.config")
local protocol = require("excavate-common.protocol")
local navigation = require("excavate-common.navigation")
local inventory = require("excavate-common.inventory")

local modem = peripheral.find("modem") or error("No modem attached")
local workerId = os.getComputerID()

local supervisorChannel = nil
local assignedPosition = nil
local excavationBounds = nil
local currentTask = nil
local homePosition = {x = 0, y = 0, z = 0}

local statistics = {
    tasksCompleted = 0,
    blocksMinedTotal = 0,
    fuelUsedTotal = 0
}

local running = true

local function log(message, color)
    term.setTextColor(color or colors.white)
    print(string.format("[Worker %d] %s", workerId, message))
    term.setTextColor(colors.white)
end

local function displayStatus()
    term.clear()
    term.setCursorPos(1, 1)
    
    term.setTextColor(colors.cyan)
    print("+---------------------------------------+")
    print("|      EXCAVATION WORKER TURTLE         |")
    print("+---------------------------------------+")
    term.setTextColor(colors.white)
    
    print("")
    print(string.format("Worker ID: %d", workerId))
    print(string.format("Position: (%d, %d, %d)", 
        navigation.getPosition().x,
        navigation.getPosition().y,
        navigation.getPosition().z))
    print(string.format("Fuel: %s", tostring(turtle.getFuelLevel())))
    print(string.format("Inventory: %d/16 slots used", inventory.getUsedSlots()))
    print("")
    
    if currentTask then
        print(string.format("Current Task: %s", currentTask.id))
        print(string.format("Mining column: (%d, %d)", 
            currentTask.column.x, currentTask.column.z))
    else
        print("Status: Idle")
    end
    
    print("")
    print(string.format("Tasks completed: %d", statistics.tasksCompleted))
    print(string.format("Blocks mined: %d", statistics.blocksMinedTotal))
end

local function waitForSupervisor()
    log("Waiting for supervisor...", colors.yellow)
    
    while true do
        local success, message, replyChannel = protocol.waitForMessage(5)
        if success and message.type == "excavation_start" then
            supervisorChannel = replyChannel
            log(string.format("Found supervisor (ID: %d)", message.supervisor_id), colors.green)
            return true
        end
        
        displayStatus()
    end
end

local function registerWithSupervisor()
    log("Registering with supervisor...", colors.cyan)
    
    local registerMsg = protocol.createRegisterMessage(
        turtle.getFuelLevel(),
        inventory.getEmptySlots()
    )
    
    protocol.sendToSupervisor(modem, registerMsg)
    
    local success, message = protocol.waitForMessage(10, "welcome")
    if success then
        assignedPosition = message.assigned_position
        excavationBounds = message.excavation_bounds
        homePosition = {
            x = assignedPosition.x,
            y = assignedPosition.y,
            z = assignedPosition.z
        }
        log(string.format("Assigned position: (%d, %d, %d)", 
            assignedPosition.x, assignedPosition.y, assignedPosition.z), colors.green)
        return true
    end
    
    log("Failed to register with supervisor", colors.red)
    return false
end

local function moveToAssignedPosition()
    log("Moving to assigned position...", colors.cyan)
    
    if not navigation.moveTo(assignedPosition.x, assignedPosition.y, assignedPosition.z, true) then
        log("Failed to reach assigned position", colors.red)
        return false
    end
    
    navigation.turnTo(0)
    log("In position", colors.green)
    return true
end

local function requestTask()
    local requestMsg = protocol.createRequestTaskMessage(
        navigation.getPosition(),
        turtle.getFuelLevel()
    )
    
    protocol.sendToSupervisor(modem, requestMsg)
    
    local success, message = protocol.waitForMessage(10)
    if success then
        if message.type == "task_assignment" then
            currentTask = message
            log(string.format("Received task %s: mine column (%d, %d)", 
                message.task_id, message.column.x, message.column.z), colors.cyan)
            return true
        elseif message.type == "no_tasks_available" then
            log("No tasks available, waiting...", colors.yellow)
            sleep(message.retry_after)
            return false
        elseif message.type == "return_home" then
            log("Supervisor requested return home", colors.yellow)
            running = false
            return false
        end
    end
    
    log("Failed to get task response", colors.red)
    return false
end

local function checkFuelAndInventory()
    local fuelLevel = turtle.getFuelLevel()
    local emptySlots = inventory.getEmptySlots()
    
    if inventory.isCritical() then
        log("Inventory critical, requesting deposit location", colors.orange)
        
        local msg = protocol.createNeedDepositMessage(
            navigation.getPosition(),
            emptySlots
        )
        protocol.sendToSupervisor(modem, msg)
        
        local success, response = protocol.waitForMessage(10, "chest_location")
        if success and response.chest_type == "deposit" then
            local currentPos = navigation.getPosition()
            
            log(string.format("Moving to deposit chest at (%d,%d,%d)", 
                response.location.x, response.location.y, response.location.z), colors.yellow)
            
            if navigation.moveToAvoidingOthers(
                response.location.x, 
                response.location.y, 
                response.location.z
            ) then
                inventory.consolidate()
                local success, count = inventory.depositAll()
                if success then
                    log(string.format("Deposited %d stacks", count), colors.green)
                else
                    log("Deposit chest full or blocked", colors.red)
                end
                
                navigation.moveToAvoidingOthers(currentPos.x, currentPos.y, currentPos.z)
            end
        end
    end
    
    if fuelLevel ~= "unlimited" and fuelLevel < config.fuel.warning_level then
        log("Low fuel, requesting fuel location", colors.orange)
        
        local fuelNeeded = 1000
        local msg = protocol.createNeedFuelMessage(
            navigation.getPosition(),
            fuelLevel,
            fuelNeeded
        )
        protocol.sendToSupervisor(modem, msg)
        
        local success, response = protocol.waitForMessage(10, "chest_location")
        if success and response.chest_type == "fuel" then
            local currentPos = navigation.getPosition()
            
            log(string.format("Moving to fuel chest at (%d,%d,%d)", 
                response.location.x, response.location.y, response.location.z), colors.yellow)
            
            if navigation.moveToAvoidingOthers(
                response.location.x, 
                response.location.y, 
                response.location.z
            ) then
                local success, newFuel = inventory.suckFuel()
                if success then
                    log(string.format("Refueled to %d", newFuel), colors.green)
                else
                    log("No fuel available in chest", colors.red)
                end
                
                navigation.moveToAvoidingOthers(currentPos.x, currentPos.y, currentPos.z)
            end
        end
    end
end

local function mineColumn()
    local startTime = os.time()
    local blocksMined = 0
    local startY = currentTask.start_y
    local targetDepth = currentTask.target_depth
    
    log(string.format("Moving to column (%d, %d)", 
        currentTask.column.x, currentTask.column.z), colors.cyan)
    
    if not navigation.moveToAvoidingOthers(
        currentTask.column.x, 
        startY, 
        currentTask.column.z
    ) then
        log("Failed to reach mining column", colors.red)
        local errorMsg = protocol.createErrorReportMessage(
            "BLOCKED_PATH",
            "Cannot reach mining column",
            navigation.getPosition(),
            currentTask.task_id
        )
        protocol.sendToSupervisor(modem, errorMsg)
        return false
    end
    
    log("Starting excavation", colors.green)
    
    while navigation.getPosition().y > targetDepth do
        if turtle.digDown() then
            blocksMined = blocksMined + 1
        end
        
        if not navigation.down() then
            if not turtle.digDown() then
                log("Hit bedrock or unbreakable block", colors.yellow)
                break
            end
            navigation.down()
        end
        
        if blocksMined % 10 == 0 then
            checkFuelAndInventory()
            
            if navigation.shouldBroadcastPosition() then
                local statusMsg = protocol.createStatusUpdateMessage(
                    navigation.getPosition(),
                    turtle.getFuelLevel(),
                    currentTask.task_id,
                    (startY - navigation.getPosition().y) / (startY - targetDepth)
                )
                protocol.sendToSupervisor(modem, statusMsg)
            end
        end
        
        local event = os.pullEvent(0)
        if event == "modem_message" then
            local _, _, _, _, message = os.pullEvent("modem_message")
            if message.type == "emergency_stop" then
                log("Emergency stop received", colors.red)
                running = false
                break
            end
        end
    end
    
    local finalDepth = navigation.getPosition().y
    local timeTaken = os.time() - startTime
    
    log(string.format("Column complete. Mined %d blocks in %d seconds", 
        blocksMined, timeTaken), colors.green)
    
    statistics.blocksMinedTotal = statistics.blocksMinedTotal + blocksMined
    statistics.tasksCompleted = statistics.tasksCompleted + 1
    
    log("Returning to surface", colors.cyan)
    navigation.moveToAvoidingOthers(currentTask.column.x, 0, currentTask.column.z)
    
    checkFuelAndInventory()
    
    local completeMsg = protocol.createTaskCompleteMessage(
        currentTask.task_id,
        blocksMined,
        timeTaken,
        finalDepth
    )
    protocol.sendToSupervisor(modem, completeMsg)
    
    currentTask = nil
    return true
end

local function returnHome()
    log("Returning to home position...", colors.cyan)
    
    checkFuelAndInventory()
    
    if navigation.moveToAvoidingOthers(homePosition.x, homePosition.y, homePosition.z) then
        navigation.turnTo(0)
        log("Arrived at home position", colors.green)
        return true
    end
    
    log("Failed to return home", colors.red)
    return false
end

local function main()
    log("Excavation Worker Starting...", colors.lime)
    
    protocol.openChannels(modem)
    
    if not waitForSupervisor() then
        log("No supervisor found", colors.red)
        return
    end
    
    if not registerWithSupervisor() then
        return
    end
    
    if not moveToAssignedPosition() then
        return
    end
    
    log("Ready for tasks", colors.green)
    
    local lastStatusBroadcast = os.time()
    
    while running do
        displayStatus()
        
        if not currentTask then
            if not requestTask() then
                sleep(5)
            end
        else
            mineColumn()
        end
        
        local currentTime = os.time()
        if currentTime - lastStatusBroadcast >= config.timing.position_update then
            local statusMsg = protocol.createStatusUpdateMessage(
                navigation.getPosition(),
                turtle.getFuelLevel(),
                currentTask and currentTask.task_id or nil,
                0
            )
            protocol.sendToSupervisor(modem, statusMsg)
            lastStatusBroadcast = currentTime
        end
        
        local event = os.pullEvent(0.1)
        if event == "modem_message" then
            local _, _, _, _, message = os.pullEvent("modem_message")
            if message.type == "return_home" then
                log("Return home command received", colors.yellow)
                running = false
            elseif message.type == "emergency_stop" then
                log("Emergency stop received", colors.red)
                running = false
            end
        end
    end
    
    returnHome()
    
    term.clear()
    term.setCursorPos(1, 1)
    
    local report = pretty.text("+---------------------------------------+", colors.lime) .. pretty.line ..
                   pretty.text("|         WORKER COMPLETE!              |", colors.lime) .. pretty.line ..
                   pretty.text("+---------------------------------------+", colors.lime) .. pretty.line .. pretty.line ..
                   pretty.text(string.format("Tasks completed: %d", statistics.tasksCompleted)) .. pretty.line ..
                   pretty.text(string.format("Blocks mined: %d", statistics.blocksMinedTotal)) .. pretty.line ..
                   pretty.text(string.format("Final fuel: %s", tostring(turtle.getFuelLevel())))
    
    pretty.print(report)
end

main()