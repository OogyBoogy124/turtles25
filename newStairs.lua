-- newStairs.lua: Script for turtle to dig a staircase down, handling hazards and inventory management.

local function safe_sleep(seconds)
    os.sleep(seconds)
end

local function print_status(message)
    print(message)
end

local function refuel()
    local fuel_level = turtle.getFuelLevel()
    if fuel_level < 100 then
        for i = 1, 16 do
            turtle.select(i)
            if turtle.refuel(1) then
                break
            end
        end
    end
end

local function detect_block(direction)
    if direction == "forward" then
        return turtle.inspect()
    elseif direction == "down" then
        return turtle.inspectDown()
    elseif direction == "up" then
        return turtle.inspectUp()
    end
    return false, nil
end

local function is_hazardous_block(block_name)
    return block_name == "minecraft:water" or block_name == "minecraft:lava" or block_name == "minecraft:bedrock"
end

local function safe_dig(direction)
    local success, block = detect_block(direction)
    if success and not is_hazardous_block(block.name) then
        if direction == "forward" then
            turtle.dig()
        elseif direction == "down" then
            turtle.digDown()
        elseif direction == "up" then
            turtle.digUp()
        end
    elseif success and is_hazardous_block(block.name) then
        return false -- Indicate hazard detected
    end
    return true
end

local function check_inventory()
    local full = true
    for i = 1, 16 do
        if turtle.getItemCount(i) == 0 then
            full = false
            break
        end
    end
    return full
end

local function dig_chest_chamber()
    -- Dig a 3x3x3 chamber around the turtle for chest placement
    for x = -1, 1 do
        for y = -1, 1 do
            for z = -1, 1 do
                if not (x == 0 and y == 0 and z == 0) then
                    -- Move to position and dig
                    turtle.dig()
                    turtle.forward()
                    turtle.digDown()
                    turtle.digUp()
                    -- Return to center (simplified, assume turtle can navigate)
                end
            end
        end
    end
    -- Place chest in center
    turtle.select(1) -- Assume chest is in slot 1
    turtle.place()
end

local function dump_inventory()
    for i = 1, 16 do
        turtle.select(i)
        turtle.drop()
    end
end

local function return_to_surface()
    -- Assume we track depth or use a simple ascent
    while turtle.detectUp() do
        turtle.digUp()
        turtle.up()
    end
    print_status("Returned to surface due to hazard.")
end

local function dig_step()
    if not safe_dig("down") then
        return_to_surface()
        return false
    end
    turtle.down()
    return true
end

local function turn_and_continue()
    turtle.turnRight()
    turtle.turnRight() -- Turn around
end

function main()
    print_status("Starting staircase dig down.")
    while true do
        refuel()
        if check_inventory() then
            dig_chest_chamber()
            dump_inventory()
            turn_and_continue()
        end
        if not dig_step() then
            break
        end
    end
    print_status("Digging complete.")
end

main()
