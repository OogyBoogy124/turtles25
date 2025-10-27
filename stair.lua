--[[
    ComputerCraft Turtle Program: Staircase Miner
    
    This program creates a straight, descending staircase tunnel (2 blocks forward, 1 block down)
    to a specified depth. It handles refueling and inventory dumping into chests.
    It then returns to the surface, placing full blocks to form a ramp/staircase and torches.
]]

-- --- Configuration ---

local COAL_SLOT = 1      -- Inventory slot for coal/fuel
local CHEST_SLOT = 2     -- Inventory slot for chests
local TORCH_SLOT = 3     -- Inventory slot for torches
local FILL_SLOT = 4      -- Inventory slot to hold the block used for bridging/staircase (first mined block)

local MAX_STEPS = 200     -- How many steps (downward movements) to take.
local REFUEL_THRESHOLD = 500 -- Refuel if fuel is below this level (max fuel is typically 20000)
local KEEP_SLOTS = {COAL_SLOT, CHEST_SLOT, TORCH_SLOT, FILL_SLOT} -- Slots to keep when dumping loot

-- --- Utility Functions ---

local function safe_sleep()
    sleep(0.05) 
end

local function print_status(message)
    print(">> " .. message)
end

local function refuel()
    local fuel_level = turtle.getFuelLevel()
    
    if fuel_level == "unlimited" then return end
    
    if fuel_level < REFUEL_THRESHOLD then
        print_status("Fuel low (" .. fuel_level .. "). Attempting to refuel.")
        
        -- Check if coal is in the designated slot
        local item = turtle.getItemDetail(COAL_SLOT)
        if not item or (not item.name:find("coal") and not item.name:find("charcoal")) then
            print_status("CRITICAL: No fuel in Slot " .. COAL_SLOT .. ". Halting.")
            error("No fuel source.")
        end
        
        -- Select fuel slot and refuel (try a stack of 64)
        turtle.select(COAL_SLOT)
        local success = turtle.refuel(64)
        
        if success then
            print_status("Refueled successfully.")
        else
            -- Check if fuel block is used up
            if turtle.getItemCount(COAL_SLOT) == 0 then
                print_status("Fuel stack used up. Continuing.")
            else
                print_status("Refuel failed, continuing regardless.")
            end
        end
    end
end

local function safe_dig(direction)
    refuel()
    local success, message
    
    -- Ensure the turtle is facing forward for dig/place logic
    turtle.select(FILL_SLOT) 

    if direction == "up" then
        success, message = turtle.digUp()
    elseif direction == "down" then
        success, message = turtle.digDown()
    else -- forward
        success, message = turtle.dig()
    end
    
    if not success and message and message:find("liquid") then
        print_status("Encountered liquid. Placing a block.")
        -- If digging forward or down fails due to a liquid, place a filler block
        if direction ~= "up" then
            turtle.place()
            safe_sleep()
            -- Try digging again after placing the block
            if direction == "down" then turtle.digDown() else turtle.dig() end
        end
    end
    return success
end

local function check_inventory()
    for i=1, 16 do
        if turtle.getItemCount(i) == 0 then
            return false -- Found an empty slot
        end
    end
    return true -- Inventory is full
end

local function dump_inventory()
    if not check_inventory() then
        return
    end

    print_status("Inventory is full. Preparing to dump loot.")

    -- 1. Check for chest
    if turtle.getItemCount(CHEST_SLOT) == 0 then
        print_status("CRITICAL: Out of chests. Halting.")
        error("No chests for loot drop.")
    end

    -- 2. Turn right, place chest, and dump items
    turtle.turnRight()
    turtle.select(CHEST_SLOT)
    local success, message = turtle.place()
    
    if not success then
        print_status("Failed to place chest: " .. (message or "Unknown"))
        turtle.turnLeft()
        return -- Cannot dump, continuing is dangerous
    end
    
    print_status("Chest placed. Dumping items.")
    safe_sleep()

    -- Drop all non-essential items
    for slot = 1, 16 do
        local keep = false
        for _, keep_slot in ipairs(KEEP_SLOTS) do
            if slot == keep_slot then
                keep = true
                break
            end
        end
        
        -- If it's not a slot we need to keep, select it and drop it (into the chest)
        if not keep and turtle.getItemCount(slot) > 0 then
            turtle.select(slot)
            turtle.drop() -- Correct: turtle.drop() drops into the block/container in front
        end
    end

    -- 3. Break the chest and turn back
    turtle.dig() -- The chest is still in front of the turtle
    turtle.turnLeft()
    print_status("Loot dumped. Resuming tunnel.")
end

-- --- Digging Logic ---

local function dig_step()
    -- Implements the pattern: (2x Forward, 1x Down)

    -- 1. Forward 1/2
    safe_dig("up")
    safe_dig("forward")
    turtle.forward()
    dump_inventory()
    
    -- 2. Forward 2/2
    safe_dig("up")
    safe_dig("forward")
    turtle.forward()
    dump_inventory()

    -- 3. Step Down
    safe_dig("down")
    turtle.down()
    safe_sleep()
end

local function set_fill_slot()
    -- After the first block is dug, find the first collected material for bridging/staircase
    if turtle.getItemCount(FILL_SLOT) == 0 then
        for i = 1, 16 do
            local keep = false
            for _, keep_slot in ipairs(KEEP_SLOTS) do
                if i == keep_slot then
                    keep = true
                    break
                end
            end
            
            if not keep and turtle.getItemCount(i) > 0 then
                FILL_SLOT = i 
                -- Also add it to KEEP_SLOTS so it doesn't get dumped
                table.insert(KEEP_SLOTS, FILL_SLOT)
                print_status("Set filler/stair block to Slot " .. FILL_SLOT)
                break
            end
        end
    end
end

local function dig_down()
    print_status("Starting descent to " .. MAX_STEPS .. " steps.")
    
    for step = 1, MAX_STEPS do
        print_status("Step " .. step .. " / " .. MAX_STEPS)
        dig_step()
        
        -- After the first step, identify the filler block
        if step == 1 then
            set_fill_slot()
        end
    end

    print_status("Descent complete. Preparing for ascent and construction.")
end

-- --- Construction/Ascent Logic ---

local function ascend_and_build()
    print_status("Starting ascent and staircase construction.")
    
    local fill_count = turtle.getItemCount(FILL_SLOT)
    local torch_count = turtle.getItemCount(TORCH_SLOT)

    if fill_count == 0 then
        print_status("CRITICAL: No filler blocks found. Cannot build staircase. Ascending without construction.")
    end

    for step = 1, MAX_STEPS do
        
        -- 1. Move backward twice (undo the 2 forward moves from the dig_step)
        refuel()
        if not turtle.back() then break end -- Check if blocked
        refuel()
        if not turtle.back() then break end
        safe_sleep()
        
        -- 2. Place a staircase block (full block is easier than a stair item)
        if fill_count > 0 then
            turtle.select(FILL_SLOT)
            local success, message = turtle.placeDown() -- Place block down where the turtle just came from
            if not success then
                 print_status("Could not place block: " .. (message or "Unknown"))
            end
        end

        -- 3. Move up (undo the 1 down move from the dig_step)
        refuel()
        local success, message = turtle.up()
        if not success then
            print_status("Movement up failed. Likely at the top or blocked: " .. (message or "Unknown"))
            break
        end
        safe_sleep()
        
        -- 4. Place a torch every few steps (e.g., every 5 steps)
        torch_count = turtle.getItemCount(TORCH_SLOT)
        if torch_count > 0 and (step % 5 == 0) then 
            turtle.select(TORCH_SLOT)
            turtle.place() -- Place forward
        end
    end
    
    print_status("Ascent complete. The turtle is at the entrance.")
end

-- --- Main Program ---

function main()
    print_status("Initializing Staircase Miner...")
    
    -- In a real scenario, you'd add a startup check to ensure all required items are in slots 1, 2, and 3.

    dig_down()
    ascend_and_build()
    print_status("Program finished successfully.")
end

main()
