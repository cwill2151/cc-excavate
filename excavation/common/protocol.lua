---@diagnostic disable: undefined-global, undefined-field, lowercase-global

local config = require("excavation.common.config")

local protocol = {}

function protocol.openChannels(modem)
    modem.open(config.channels.supervisor)
    modem.open(config.channels.worker)
    modem.open(config.channels.emergency)
    modem.open(os.getComputerID())
end

function protocol.sendMessage(modem, channel, message)
    message.sender_id = os.getComputerID()
    message.timestamp = os.time()
    modem.transmit(channel, os.getComputerID(), message)
end

function protocol.broadcast(modem, message)
    protocol.sendMessage(modem, config.channels.supervisor, message)
end

function protocol.sendToSupervisor(modem, message)
    protocol.sendMessage(modem, config.channels.worker, message)
end

function protocol.sendEmergency(modem, message)
    protocol.sendMessage(modem, config.channels.emergency, message)
end

function protocol.sendDirect(modem, targetId, message)
    protocol.sendMessage(modem, targetId, message)
end

function protocol.waitForMessage(timeout, messageType)
    local timer = os.startTimer(timeout or config.timing.message_timeout)
    
    while true do
        local event, p1, p2, p3, p4, p5 = os.pullEvent()
        
        if event == "modem_message" then
            local side, channel, replyChannel, message, distance = p1, p2, p3, p4, p5
            
            if type(message) == "table" and message.type then
                if not messageType or message.type == messageType then
                    return true, message, replyChannel, distance
                end
            end
        elseif event == "timer" and p1 == timer then
            return false, "timeout"
        end
    end
end

function protocol.createRegisterMessage(fuel, emptySlots)
    return {
        type = "register",
        id = os.getComputerID(),
        fuel = fuel,
        inventory = {empty_slots = emptySlots}
    }
end

function protocol.createRequestTaskMessage(position, fuel)
    return {
        type = "request_task",
        id = os.getComputerID(),
        position = position,
        fuel = fuel
    }
end

function protocol.createTaskCompleteMessage(taskId, blocksMined, timeTaken, finalDepth)
    return {
        type = "task_complete",
        id = os.getComputerID(),
        task_id = taskId,
        blocks_mined = blocksMined,
        time_taken = timeTaken,
        final_depth = finalDepth
    }
end

function protocol.createNeedDepositMessage(position, emptySlots)
    return {
        type = "need_deposit",
        id = os.getComputerID(),
        position = position,
        empty_slots = emptySlots
    }
end

function protocol.createNeedFuelMessage(position, fuelLevel, fuelNeeded)
    return {
        type = "need_fuel",
        id = os.getComputerID(),
        position = position,
        fuel_level = fuelLevel,
        fuel_needed = fuelNeeded
    }
end

function protocol.createStatusUpdateMessage(position, fuel, taskId, taskProgress)
    return {
        type = "status_update",
        id = os.getComputerID(),
        position = position,
        fuel = fuel,
        task_id = taskId,
        task_progress = taskProgress
    }
end

function protocol.createErrorReportMessage(errorCode, message, position, taskId)
    return {
        type = "error_report",
        id = os.getComputerID(),
        error_code = errorCode,
        message = message,
        position = position,
        task_id = taskId
    }
end

function protocol.createWelcomeMessage(workerId, assignedPosition, excavationBounds)
    return {
        type = "welcome",
        worker_id = workerId,
        assigned_position = assignedPosition,
        excavation_bounds = excavationBounds
    }
end

function protocol.createTaskAssignmentMessage(taskId, column, startY, targetDepth, priority)
    return {
        type = "task_assignment",
        task_id = taskId,
        column = column,
        start_y = startY,
        target_depth = targetDepth,
        priority = priority or 1
    }
end

function protocol.createChestLocationMessage(requestId, chestType, location, reservedUntil)
    return {
        type = "chest_location",
        request_id = requestId,
        chest_type = chestType,
        location = location,
        reserved_until = reservedUntil
    }
end

function protocol.createNoTasksMessage(retryAfter)
    return {
        type = "no_tasks_available",
        retry_after = retryAfter or 10
    }
end

function protocol.createReturnHomeMessage(reason, immediate)
    return {
        type = "return_home",
        reason = reason,
        immediate = immediate or false
    }
end

function protocol.createExcavationStartMessage(totalTasks, estimatedTime, supervisorId)
    return {
        type = "excavation_start",
        total_tasks = totalTasks,
        estimated_time = estimatedTime,
        supervisor_id = supervisorId
    }
end

function protocol.createExcavationCompleteMessage(totalBlocksMined, timeTaken, workersUsed)
    return {
        type = "excavation_complete",
        total_blocks_mined = totalBlocksMined,
        time_taken = timeTaken,
        workers_used = workersUsed
    }
end

function protocol.createEmergencyStopMessage(reason)
    return {
        type = "emergency_stop",
        reason = reason
    }
end

return protocol