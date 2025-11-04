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
    -- Dig down 1 to start chamber
    if not safe_dig("down") then
        return false
    end
    turtle.down()
    -- Dig forward 1
    if not safe_dig("forward") then
        turtle.up() -- return if can't dig
        return false
    end
    turtle.forward()
    -- Dig up 1
    if not safe_dig("up") then
        turtle.back()
        turtle.up()
        return false
    end
    turtle.up()
    -- Dig down 1 again to position for chest
    if not safe_dig("down") then
        turtle.down()
        turtle.back()
        turtle.up()
        return false
    end
    turtle.down()
    -- Place chest (assume chest in slot 1)
    turtle.select(1)
    if not turtle.place() then
        -- If can't place, return
        turtle.up()
        turtle.back()
        turtle.up()
        return false
    end
    -- Dump inventory into chest
    dump_inventory()
    -- Return to original position: up 1, back 1, up 1
    turtle.up()
    turtle.back()
    turtle.up()
    return true
end

local function dump_inventory()
    for i = 1, 16 do
        turtle.select(i)
        turtle.drop()
    end
end

local function return_to_surface()
    -- Ascend by digging up until no block above
    while turtle.detectUp() do
        turtle.digUp()
        turtle.up()
    end
    print_status("Returned to surface due to hazard.")
end

local function dig_step()
    -- Dig forward for the step
    if not safe_dig("forward") then
        return_to_surface()
        return false
    end
    turtle.forward()
    -- Dig down for the descent
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
            if not dig_chest_chamber() then
                print_status("Failed to dig chest chamber, stopping.")
                break
            end
            turn_and_continue()
        end
        if not dig_step() then
            break
        end
    end
    print_status("Digging complete.")
end

main()
