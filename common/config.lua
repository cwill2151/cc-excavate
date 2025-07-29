---@diagnostic disable: undefined-global, undefined-field, lowercase-global

return {
    barrier_block = "minecraft:mangrove_log",
    max_depth = 250,
    
    channels = {
        supervisor = 65500,
        worker = 65501,
        emergency = 65502
    },
    
    timing = {
        heartbeat_interval = 30,
        message_timeout = 5,
        task_timeout = 600,
        chest_reservation = 300,
        position_update = 5,
        retry_delay = 2
    },
    
    fuel = {
        margin = 50,
        warning_level = 200,
        critical_level = 100
    },
    
    inventory = {
        deposit_threshold = 14,
        critical_threshold = 15
    },
    
    task = {
        batch_size = 10,
        priority_levels = 3
    },
    
    worker = {
        max_workers = 50,
        position_spacing = 1,
        idle_timeout = 60
    },
    
    chest_pool = {
        scan_radius = 10,
        default_deposit_height = 2,
        default_fuel_height = 1
    },
    
    navigation = {
        collision_check_radius = 2,
        max_retries = 5,
        movement_timeout = 30
    },
    
    display = {
        update_interval = 1,
        status_lines = 10,
        color_scheme = {
            header = colors.lime,
            info = colors.white,
            warning = colors.orange,
            error = colors.red,
            success = colors.green,
            debug = colors.gray
        }
    },
    
    debug = {
        enabled = false,
        log_messages = false,
        log_movements = false,
        log_file = "excavation_debug.log"
    }
}