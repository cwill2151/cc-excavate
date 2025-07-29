# CC-Excavate: Multi-Turtle Collaborative Excavation System

A sophisticated distributed excavation system for ComputerCraft: Tweaked where multiple turtles work together to efficiently excavate large areas. One turtle acts as a supervisor, managing work distribution and resources, while unlimited worker turtles execute mining tasks in parallel.

## Features

- **Dynamic Task Distribution**: Supervisor assigns mining columns to workers on-demand
- **Unlimited Workers**: Support for any number of worker turtles
- **Smart Resource Management**: Shared chest pool system for fuel and deposits
- **Collision Avoidance**: Turtles coordinate positions to prevent collisions
- **Real-time Monitoring**: Live status updates and progress tracking
- **Fault Tolerance**: Automatic task reassignment if workers disconnect
- **Easy Installation**: One-command installation with ccmsi

## Quick Start

### 1. Download the installer on any turtle:
```bash
wget https://raw.githubusercontent.com/cwill2151/cc-excavate/main/ccmsi.lua ccmsi
```

### 2. Install on supervisor turtle:
```bash
ccmsi supervisor
```

### 3. Install on worker turtles:
```bash
ccmsi worker
```

### Other ccmsi features:
```bash
ccmsi list          # List all available systems
ccmsi update        # Update ccmsi itself
ccmsi clean         # Remove all installed files
ccmsi seturl <url>  # Use custom metadata URL
```

### 4. Set up the excavation area:
- Place supervisor turtle in center of area
- Surround area with barrier blocks (default: mangrove logs)
- Place fuel chest at Y+1 behind supervisor
- Place deposit chests at Y+2 and above
- Position worker turtles diagonally from supervisor

### 5. Run the system:
- On supervisor: `excavation/supervisor`
- On workers: `excavation/worker`

## System Architecture

```
┌─────────────┐
│  Supervisor │
│   Turtle    │
└──────┬──────┘
       │
   Wireless
   Modems
       │
┌──────┴──────┬──────────┬──────────┐
│             │          │          │
▼             ▼          ▼          ▼
Worker 1    Worker 2   Worker 3   Worker N
```

## How It Works

1. **Initialization**: Supervisor measures area and creates task queue
2. **Worker Registration**: Workers connect and receive assigned positions
3. **Task Distribution**: Workers request tasks, supervisor assigns columns
4. **Mining**: Workers excavate assigned columns layer by layer
5. **Resource Management**: Workers request chest locations when needed
6. **Completion**: All workers return home when excavation is complete

## Configuration

Edit `excavation/excavate-common/config.lua` to customize:
- Barrier block type
- Maximum mining depth
- Fuel thresholds
- Communication channels
- Performance settings

## Commands

### Supervisor Controls
- `P` - Pause all workers
- `R` - Resume operations
- `E` - Emergency stop
- `Q` - Quit

### ccmsi Commands
- `ccmsi <system>` - Install/update any system defined in metadata
- `ccmsi list` - Show all available systems
- `ccmsi update` - Update ccmsi itself
- `ccmsi clean` - Remove all installed files
- `ccmsi seturl <url>` - Use custom metadata URL for private repos

## Requirements

- ComputerCraft: Tweaked
- Mining Turtles with wireless modems
- Chests for fuel and item storage
- Barrier blocks to define excavation area

## File Structure

```
/excavation/
  supervisor.lua       # Supervisor program
  worker.lua          # Worker program
  excavate-common/
    config.lua        # Configuration settings
    protocol.lua      # Communication protocol
    navigation.lua    # Movement and collision avoidance
    inventory.lua     # Inventory management
  SETUP.md            # Detailed setup instructions
ccmsi.lua             # Installer/updater
```

## Performance Tips

- Use 1 worker per 100 blocks of area
- Place multiple chest clusters for large excavations
- Use ender modems for better range
- Ensure chunks stay loaded

## Troubleshooting

- **Workers won't connect**: Check modems are equipped and supervisor is running
- **"No fuel" errors**: Add fuel to fuel chests, check placement
- **Workers colliding**: Increase position_spacing in config
- **Poor performance**: Reduce number of workers or adjust update intervals

## Contributing

Feel free to submit issues and pull requests!

## License

MIT License - See LICENSE file for details