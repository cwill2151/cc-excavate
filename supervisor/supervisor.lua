---@diagnostic disable: undefined-global, undefined-field, lowercase-global

require("/initenv").init_env()

local pretty = require("cc.pretty")
local config = require("excavate-common.config")
local protocol = require("excavate-common.protocol")
local navigation = require("excavate-common.navigation")
local inventory = require("excavate-common.inventory")

local modem = peripheral.find("modem") or error("No modem attached")
local supervisorId = os.getComputerID()

local workers = {}
local taskQueue = {}
local completedTasks = {}
local chestPool = {
    deposit = {},
    fuel = {}
}
local excavationBounds = nil
local statistics = {
    startTime = os.time(),
    blocksMinedTotal = 0,
    tasksCompleted = 0,
    totalTasks = 0
}

local running = true
local paused = false

local function log(message, color)
    local timestamp = os.date("%H:%M:%S")
    term.setTextColor(color or colors.white)
    print(string.format("[%s] %s", timestamp, message))
    term.setTextColor(colors.white)
end

local function generateTaskId()
    return string.format("task_%d_%d", supervisorId, os.time() * 1000 + math.random(999))
end

local function measureArea()
    log("Measuring excavation area...", colors.cyan)
    
    local measurements = {}
    
    for direction = 0, 3 do
        navigation.turnTo(direction)
        local distance = 0
        
        while true do
            local success, block = turtle.inspect()
            if success and block.name == config.barrier_block then
                break
            end
            
            if navigation.forward() then
                distance = distance + 1
            else
                log("ERROR: Blocked by non-barrier block", colors.red)
                return nil
            end
            
            if distance > 100 then
                log("ERROR: No barrier found within 100 blocks", colors.red)
                return nil
            end
        end
        
        measurements[direction] = distance
        local dirs = {"North", "East", "South", "West"}
        log(string.format("  %s: %d blocks", dirs[direction + 1], distance), colors.gray)
        
        navigation.moveTo(0, 0, 0, false)
    end
    
    return {
        north = measurements[0],
        east = measurements[1],
        south = measurements[2],
        west = measurements[3]
    }
end

local function scanForChests()
    log("Scanning for chests...", colors.cyan)
    
    local radius = config.chest_pool.scan_radius
    local startPos = navigation.getPosition()
    
    for y = 1, radius do
        for x = -radius, radius do
            for z = -radius, radius do
                if x ~= 0 or z ~= 0 then
                    navigation.moveTo(x, y, z, false)
                    
                    for dir = 0, 3 do
                        navigation.turnTo(dir)
                        local success, block = turtle.inspect()
                        
                        if success and block.name == "minecraft:chest" then
                            local chestPos = navigation.getPosition()
                            local facing = navigation.getFacing()
                            local offset = {
                                [0] = {x = 0, z = 1},
                                [1] = {x = 1, z = 0},
                                [2] = {x = 0, z = -1},
                                [3] = {x = -1, z = 0}
                            }
                            
                            local chestLocation = {
                                x = chestPos.x + offset[facing].x,
                                y = chestPos.y,
                                z = chestPos.z + offset[facing].z,
                                in_use = false,
                                reserved_by = nil,
                                reserved_until = 0
                            }
                            
                            if y == config.chest_pool.default_fuel_height then
                                table.insert(chestPool.fuel, chestLocation)
                                log(string.format("  Found fuel chest at (%d,%d,%d)", 
                                    chestLocation.x, chestLocation.y, chestLocation.z), colors.green)
                            else
                                table.insert(chestPool.deposit, chestLocation)
                                log(string.format("  Found deposit chest at (%d,%d,%d)", 
                                    chestLocation.x, chestLocation.y, chestLocation.z), colors.green)
                            end
                        end
                    end
                end
            end
        end
    end
    
    navigation.moveTo(startPos.x, startPos.y, startPos.z, false)
    navigation.turnTo(0)
    
    log(string.format("Found %d deposit chests, %d fuel chests", 
        #chestPool.deposit, #chestPool.fuel), colors.lime)
end

local function createTaskQueue()
    log("Creating task queue...", colors.cyan)
    
    local minX = -excavationBounds.west
    local maxX = excavationBounds.east
    local minZ = -excavationBounds.south
    local maxZ = excavationBounds.north
    
    for x = minX, maxX do
        for z = minZ, maxZ do
            table.insert(taskQueue, {
                id = generateTaskId(),
                column = {x = x, z = z},
                start_y = 0,
                target_depth = -config.max_depth,
                priority = 1,
                assigned_to = nil,
                status = "pending"
            })
        end
    end
    
    statistics.totalTasks = #taskQueue
    log(string.format("Created %d tasks", #taskQueue), colors.lime)
end

local function getNextTask()
    for _, task in ipairs(taskQueue) do
        if task.status == "pending" then
            return task
        end
    end
    return nil
end

local function assignTask(workerId)
    local task = getNextTask()
    if not task then
        return nil
    end
    
    task.status = "assigned"
    task.assigned_to = workerId
    task.assigned_time = os.time()
    
    return task
end

local function findAvailableChest(chestType)
    local chests = chestType == "fuel" and chestPool.fuel or chestPool.deposit
    local currentTime = os.time()
    
    for _, chest in ipairs(chests) do
        if not chest.in_use or currentTime > chest.reserved_until then
            chest.in_use = true
            chest.reserved_until = currentTime + config.timing.chest_reservation
            return chest
        end
    end
    
    return nil
end

local function releaseChest(location)
    for _, pool in pairs(chestPool) do
        for _, chest in ipairs(pool) do
            if chest.x == location.x and chest.y == location.y and chest.z == location.z then
                chest.in_use = false
                chest.reserved_by = nil
                return true
            end
        end
    end
    return false
end

local function handleWorkerMessage(message, replyChannel)
    if message.type == "register" then
        local workerId = message.id
        local workerNumber = #workers + 1
        
        workers[workerId] = {
            id = workerId,
            number = workerNumber,
            position = {x = 0, y = 0, z = 0},
            fuel = message.fuel,
            inventory = message.inventory,
            status = "idle",
            current_task = nil,
            last_heartbeat = os.time()
        }
        
        local assignedPos = {
            x = workerNumber * config.worker.position_spacing,
            y = 0,
            z = workerNumber * config.worker.position_spacing
        }
        
        local response = protocol.createWelcomeMessage(workerId, assignedPos, excavationBounds)
        protocol.sendDirect(modem, replyChannel, response)
        
        log(string.format("Worker %d registered (ID: %d)", workerNumber, workerId), colors.green)
        
    elseif message.type == "request_task" then
        if paused then
            local response = protocol.createNoTasksMessage(5)
            protocol.sendDirect(modem, replyChannel, response)
            return
        end
        
        local worker = workers[message.id]
        if worker then
            worker.position = message.position
            worker.fuel = message.fuel
            worker.status = "idle"
            worker.last_heartbeat = os.time()
            
            local task = assignTask(message.id)
            if task then
                worker.current_task = task.id
                worker.status = "working"
                
                local response = protocol.createTaskAssignmentMessage(
                    task.id,
                    task.column,
                    task.start_y,
                    task.target_depth,
                    task.priority
                )
                protocol.sendDirect(modem, replyChannel, response)
                
                log(string.format("Assigned task %s to worker %d", task.id, worker.number), colors.cyan)
            else
                local response = protocol.createNoTasksMessage(10)
                protocol.sendDirect(modem, replyChannel, response)
            end
        end
        
    elseif message.type == "task_complete" then
        local worker = workers[message.id]
        if worker then
            worker.status = "idle"
            worker.current_task = nil
            worker.last_heartbeat = os.time()
            
            for _, task in ipairs(taskQueue) do
                if task.id == message.task_id then
                    task.status = "completed"
                    table.insert(completedTasks, task)
                    break
                end
            end
            
            statistics.tasksCompleted = statistics.tasksCompleted + 1
            statistics.blocksMinedTotal = statistics.blocksMinedTotal + message.blocks_mined
            
            log(string.format("Worker %d completed task %s (%d blocks)", 
                worker.number, message.task_id, message.blocks_mined), colors.green)
        end
        
    elseif message.type == "need_deposit" then
        local chest = findAvailableChest("deposit")
        if chest then
            chest.reserved_by = message.id
            local response = protocol.createChestLocationMessage(
                generateTaskId(),
                "deposit",
                {x = chest.x, y = chest.y, z = chest.z},
                chest.reserved_until
            )
            protocol.sendDirect(modem, replyChannel, response)
            
            log(string.format("Assigned deposit chest to worker at (%d,%d,%d)", 
                chest.x, chest.y, chest.z), colors.yellow)
        end
        
    elseif message.type == "need_fuel" then
        local chest = findAvailableChest("fuel")
        if chest then
            chest.reserved_by = message.id
            local response = protocol.createChestLocationMessage(
                generateTaskId(),
                "fuel",
                {x = chest.x, y = chest.y, z = chest.z},
                chest.reserved_until
            )
            protocol.sendDirect(modem, replyChannel, response)
            
            log(string.format("Assigned fuel chest to worker at (%d,%d,%d)", 
                chest.x, chest.y, chest.z), colors.yellow)
        end
        
    elseif message.type == "status_update" then
        local worker = workers[message.id]
        if worker then
            worker.position = message.position
            worker.fuel = message.fuel
            worker.last_heartbeat = os.time()
            
            navigation.updateTurtlePosition(message.id, message.position)
        end
        
    elseif message.type == "error_report" then
        log(string.format("Worker error: %s - %s", message.error_code, message.message), colors.red)
    end
end

local function checkWorkerTimeouts()
    local currentTime = os.time()
    for id, worker in pairs(workers) do
        if currentTime - worker.last_heartbeat > config.timing.heartbeat_interval * 2 then
            log(string.format("Worker %d timed out", worker.number), colors.orange)
            
            if worker.current_task then
                for _, task in ipairs(taskQueue) do
                    if task.id == worker.current_task then
                        task.status = "pending"
                        task.assigned_to = nil
                        break
                    end
                end
            end
            
            workers[id] = nil
        end
    end
end

local function displayStatus()
    term.clear()
    term.setCursorPos(1, 1)
    
    term.setTextColor(colors.lime)
    print("+---------------------------------------+")
    print("|    MULTI-TURTLE EXCAVATION SYSTEM     |")
    print("|            SUPERVISOR MODE            |")
    print("+---------------------------------------+")
    term.setTextColor(colors.white)
    
    print("")
    print(string.format("Status: %s", paused and "PAUSED" or "RUNNING"))
    print(string.format("Workers: %d active", table.getn(workers)))
    print(string.format("Tasks: %d / %d completed", statistics.tasksCompleted, statistics.totalTasks))
    print(string.format("Blocks mined: %d", statistics.blocksMinedTotal))
    print("")
    
    local progress = statistics.totalTasks > 0 and 
        (statistics.tasksCompleted / statistics.totalTasks * 100) or 0
    print(string.format("Progress: %.1f%%", progress))
    
    print("")
    print("Workers:")
    for id, worker in pairs(workers) do
        local status = worker.status
        if worker.current_task then
            status = string.format("working on %s", worker.current_task)
        end
        print(string.format("  #%d: %s (fuel: %d)", worker.number, status, worker.fuel))
    end
    
    term.setCursorPos(1, 19)
    term.setTextColor(colors.gray)
    print("P=Pause R=Resume E=Emergency Stop Q=Quit")
    term.setTextColor(colors.white)
end

local function handleKeyPress()
    local event, key = os.pullEvent("key")
    
    if key == keys.p then
        paused = true
        log("Excavation paused", colors.yellow)
    elseif key == keys.r then
        paused = false
        log("Excavation resumed", colors.green)
    elseif key == keys.e then
        protocol.broadcast(modem, protocol.createEmergencyStopMessage("user_requested"))
        running = false
        log("Emergency stop initiated", colors.red)
    elseif key == keys.q then
        running = false
    end
end

local function main()
    log("Multi-Turtle Excavation Supervisor Starting...", colors.lime)
    
    protocol.openChannels(modem)
    
    excavationBounds = measureArea()
    if not excavationBounds then
        log("Failed to measure area", colors.red)
        return
    end
    
    log(string.format("Area: %dx%d blocks", 
        excavationBounds.north + excavationBounds.south,
        excavationBounds.east + excavationBounds.west), colors.lime)
    
    scanForChests()
    
    if #chestPool.deposit == 0 then
        log("ERROR: No deposit chests found", colors.red)
        return
    end
    
    if #chestPool.fuel == 0 then
        log("WARNING: No fuel chests found", colors.orange)
    end
    
    createTaskQueue()
    
    protocol.broadcast(modem, protocol.createExcavationStartMessage(
        statistics.totalTasks,
        statistics.totalTasks * 30,
        supervisorId
    ))
    
    log("Waiting for workers...", colors.cyan)
    
    local lastStatusUpdate = os.time()
    local lastWorkerCheck = os.time()
    
    while running do
        parallel.waitForAny(
            function()
                while running do
                    local success, message, replyChannel = protocol.waitForMessage(0.1)
                    if success then
                        handleWorkerMessage(message, replyChannel)
                    end
                end
            end,
            function()
                while running do
                    handleKeyPress()
                end
            end,
            function()
                while running do
                    local currentTime = os.time()
                    
                    if currentTime - lastStatusUpdate >= config.display.update_interval then
                        displayStatus()
                        lastStatusUpdate = currentTime
                    end
                    
                    if currentTime - lastWorkerCheck >= config.timing.heartbeat_interval then
                        checkWorkerTimeouts()
                        lastWorkerCheck = currentTime
                    end
                    
                    if statistics.tasksCompleted >= statistics.totalTasks and statistics.totalTasks > 0 then
                        protocol.broadcast(modem, protocol.createExcavationCompleteMessage(
                            statistics.blocksMinedTotal,
                            os.time() - statistics.startTime,
                            table.getn(workers)
                        ))
                        
                        protocol.broadcast(modem, protocol.createReturnHomeMessage("excavation_complete", false))
                        
                        running = false
                        log("Excavation complete!", colors.lime)
                    end
                    
                    sleep(0.1)
                end
            end
        )
    end
    
    local report = string.format([[
+---------------------------------------+
|         EXCAVATION COMPLETE!          |
+---------------------------------------+
Total blocks mined: %d
Total time: %d seconds
Workers used: %d
Tasks completed: %d / %d
]], statistics.blocksMinedTotal, os.time() - statistics.startTime, 
    table.getn(workers), statistics.tasksCompleted, statistics.totalTasks)
    
    print(report)
    
    local file = fs.open(string.format("excavation_stats_%d.txt", os.time()), "w")
    file.write(report)
    file.close()
end

main()