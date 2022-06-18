local log_terminal_id = 0
-- turtle will log it's activity on log pc 
rednet.open("right")

-- configuration
local min_fuel_level = 1500
local branch_lenght = 100
local subbranch_lenght = 100
local structure_angle = 0
-- place where you place turtle (it will be his start coordinates)
-- all other coordinates calculation are depending on that
local hub_start =   {x = 74, y = 57, z = 108}
-- place where turtle should go after finishing the work
local hub_finish = {x = 74, y = 59, z = 108}
-- place undeground from where branches will go in different sides
local mining_center = {x = 74, y = 40, z = 113}
-- place where turtle will collect his mined ores and etc.
local storage = {x = 74, y = 58, z = 116}
-- depot
local depot = {x = 76, y = 58, z = 107}
-- surface level y coordinate
local surface_y = 57

-- a means angle to south (rotation clockwise)
local turtle_coords =     {x = hub_start.x, y = hub_start.y, z = hub_start.z, a = structure_angle}
-- turtles move verticaly in different paths (x,z coordinates) to prevent collisison
local mining_entry_down = {x = mining_center.x, y = surface_y, z = mining_center.z}
local mining_exit_down =  {x = mining_center.x, y = mining_center.y + 1, z = mining_center.z}
local mining_entry_up =   {x = mining_center.x, y = mining_center.y + 1, z = mining_center.z + 1}
local mining_exit_up =    {x = mining_center.x, y = surface_y + 1, z = mining_center.z + 1}
-- can be turned off if turtle is higher that some coordinate (to prevent destroying buldings)
-- not work
local allow_mining = true

-- responsible for coordinates update when moving forward or back (back don't used btw)
function update_coordinates(is_forward)
    --is_forward = true if turtle just went forward, false if back
    local direction = 0
    if is_forward then
        direction = 1
    else
        direction = -1
    end
    -- exists only 4 rotation position: 0 - south, 90 - west, 180 - north, 270 - east
    -- depending on current rotation, forward() can change x or z coordinate
    -- if it's true, then it's only 0 or 90
    if turtle_coords.a <= 90 then
        if turtle_coords.a == 0 then
            turtle_coords.z = turtle_coords.z + direction
        --then it's 90
        else
            turtle_coords.x = turtle_coords.x - direction
        end
    -- if thing on top is false, then it's 180 or 270
    else
        if turtle_coords.a == 180 then
            turtle_coords.z = turtle_coords.z - direction
        else
            turtle_coords.x = turtle_coords.x + direction
        end
    end
end

-- if something is on the way, this function is being called to check, if there is turtle on the way
-- to prevent turtle 'friendlymining'
function inspect_turtle(side)
    local success, data = 0, 0
    if side == 0 then
        success, data = turtle.inspect()
    elseif side == 1 then
        success, data = turtle.inspectUp()
    elseif side == -1 then
        success, data = turtle.inspectDown()
    end
    -- success if there is block/turtle on the way
    if success then
        -- finds substring in data.name (format like computercraft:turtle_advanced)
        res = string.find(data.name, "turtle")
        if res == nill then
            return false
        else
            return true
        end
    end
    return false
end

-- while mining in subbranch, turtle will look at blocks above it and below it
-- if in block name is substing 'ore' - turtle will mine it
function mine_ore()
    local success_up, data_up = turtle.inspectUp()
    local success_down, data_down = turtle.inspectDown()
    if success_up then
        res = string.find(data_up.name, "ore")
        if res == nill then
            res = 0
        else
            turtle.digUp()
        end
    end
    if success_down then
        res = string.find(data_down.name, "ore")
        if res == nill then
            res = 0
        else
            turtle.digDown()
        end
    end
end

-- markers are used to understand, is that branch/subbranch 
-- is being developed, already mined or not opened
-- markers are red and yellow terracota blocks
-- red on branch entance means its already fully mined, so turtle wiil
-- check it and go in the other place
-- yellow means branch is opened, but not fully mined
function check_marker(side)
    local success, data = 0, 0
    if side == -1 then
        success, data = turtle.inspectDown()
    elseif side == 0 then
        success, data = turtle.inspect()
    else
        success, data = turtle.inspectUp()
    end
    if success then
        res = string.find(data.name, "red")
        if res == nill then
            res = string.find(data.name, "yellow")
            if res == nill then
                return "none"
            else
                return "yellow"
            end
        else
            return "red"
        end
    end
    return "none"
end

-- placing markers below turtle
function place_marker(color)
    if color == "red" then
        turtle.select(1)
        turtle.digDown()
        turtle.placeDown()
    elseif color == "yellow" then
        turtle.select(2)
        turtle.digDown()
        turtle.placeDown()
    else
        print("No marker selected!")
    end
end

-- advanced function for going forward
-- checks blocks on the way, preventing to mine other turtles.
function forward(blocks)
    for i = 1, blocks do
        local is_success = false
        repeat
            -- trying to go forward
            if turtle.forward() then
                update_coordinates(true)
                is_success = true
            -- turtle didn't go forward, trying to solve
            else
                -- detecting if it's not an other turtle
                if inspect_turtle(0) then
                    --rednet.send(log_terminal_id, "Can't go forward! Another turtle in front of me!")
                    os.sleep(1)
                -- block is on the way, can turtle mine it?
                elseif allow_mining then
                    turtle.dig()
                else
                    error("Can not go forward - block on a way (mining not allowed)")
                end
            end
        -- won't let to continue next iterations before going forward 
        until is_success == true
        -- turtle went forward
    end
end

-- anvanced function for turning, also calculates angle of rotation
function turn_right()
    turtle.turnRight()
    turtle_coords.a = turtle_coords.a + 90
    if turtle_coords.a >= 360 then
        turtle_coords.a = 0
    end
end

-- anvanced function for turning, also calculates angle of rotation
function turn_left()
    turtle.turnLeft()
    turtle_coords.a = turtle_coords.a - 90
    if turtle_coords.a < 0 then
        turtle_coords.a = 270
    end
end

-- well, name of the function tells about it
function turn_to_angle(angle_new)
    if turtle_coords.a == angle_new then
        return
    end
    repeat 
        turn_right()
    until turtle_coords.a == angle_new
end

function get_side_of_the_world(angle)
    sides = {"south", "west", "north", "east"}
    return sides[angle / 90 + 1]
end

-- advanced function for going up
-- checks blocks on the way, preventing to mine other turtles.
function up(blocks)
    for i = 1, blocks do
        local is_success = false
        repeat
            -- trying to go up
            if turtle.up() then
                turtle_coords.y = turtle_coords.y + 1
                is_success = true
            -- turtle didn't go up, trying to solve
            else
                -- detecting if it's not an other turtle
                if inspect_turtle(1) then
                    rednet.send(log_terminal_id, "Can't get up! Another turtle on top of me!")
                    os.sleep(1)
                    --error("Can not get up - turtle is on the way")
                -- block is on the way, can turtle mine it?
                elseif allow_mining then
                    turtle.digUp()
                else
                    error("Can not get up - block on a way (mining not allowed)")
                end
            end
        -- won't let to continue next iterations before going up
        until is_success == true
        -- turtle went up
    end
end

-- same as up(), but down... 
function down(blocks)
    for i = 1, blocks do
        local is_success = false
        repeat
            -- trying to go down
            if turtle.down() then
                turtle_coords.y = turtle_coords.y - 1
                is_success = true
            -- turtle didn't go down, trying to solve
            else
                -- detecting if it's not an other turtle
                if inspect_turtle(-1) then
                    rednet.send(log_terminal_id, "Can't get down! Another turtle under me!")
                    os.sleep(1)
                    --error("Can not get down - turtle is on the way")
                -- block is on the way, can turtle mine it?
                elseif allow_mining then
                    turtle.digDown()
                else
                    error("Can not get down - block on a way (mining not allowed)")
                end
            end
        -- won't let to continue next iterations before going down
        until is_success == true
        -- turtle went down
    end
end

-- turtle will move to new coordinates
function go_to(new_coords)
    -- firstly turtle will allign y, then x, then z
    if new_coords.y > turtle_coords.y then
        up(new_coords.y - turtle_coords.y)
    elseif new_coords.y < turtle_coords.y then
        down(turtle_coords.y - new_coords.y)
    end
    if new_coords.x > turtle_coords.x then
        turn_to_angle(270)
        forward(new_coords.x - turtle_coords.x)
    elseif new_coords.x < turtle_coords.x then
        turn_to_angle(90)
        forward(turtle_coords.x - new_coords.x)
    end
    if new_coords.z > turtle_coords.z then
        turn_to_angle(0)
        forward(new_coords.z - turtle_coords.z)
    elseif new_coords.z < turtle_coords.z then
        turn_to_angle(180)
        forward(turtle_coords.z - new_coords.z)
    end
end

function clear_inventory()
    for slot = 1, 16 do
        turtle.select(slot)
        local data = turtle.getItemDetail()
        local trash = {"cobblestone", "flint", "gravel", "dirt"}
        for j = 1, table.getn(trash) do
            if data then
                res = string.find(data.name, trash[j])
                if res == nill then
                    res = 0
                else
                    turtle.drop()
                end
            end
        end
    end
end

-- responsible for mining subbranch - 4(width) * subbranch_lenght * 1(height)
-- also mines blocks on ceiling and floor with mine_ore()
function mine_subbranch()
    turn_left()
    forward(1)
    mine_ore()
    turn_left()
    forward(1)
    mine_ore()
    turn_right()
    for h = 1, 2 do
        for i = 1, subbranch_lenght-1 do
            forward(1)
            mine_ore()
        end
        clear_inventory()
        turn_right()
        forward(1)
        turn_right()
        for i = 1, subbranch_lenght-1 do
            forward(1)
            mine_ore()
        end
        clear_inventory()
        if h == 1 then
            turn_left()
            forward(1)
            turn_left()
        else
            forward(1)
        end
    end
end

function refuel()
    for slot = 1, 16 do
        turtle.select(slot)
        turtle.refuel(64)
    end 
end

function find_working_branch()
    down(1)
    for i = 1, 4 do
        marker = check_marker(0)
        if marker == "red" then
            turn_right()
        elseif marker == "none" then
            up(1)
            forward(1)
            place_marker("yellow")
            rednet.send(log_terminal_id, "Creating " .. get_side_of_the_world(turtle_coords.a) .. " branch at y = " .. turtle_coords.y)
            -- returning branch exit coords
            return {x = turtle_coords.x, y = turtle_coords.y + 1, z = turtle_coords.z}
        else 
            up(1)
            forward(1)
            rednet.send(log_terminal_id, "Find working " .. get_side_of_the_world(turtle_coords.a) .. " branch at y = " .. turtle_coords.y)
            -- returning branch exit coords
            local branch_exit = {x = turtle_coords.x, y = turtle_coords.y + 1, z = turtle_coords.z}
            if turtle_coords.a <= 90 then
                if turtle_coords.a == 0 then
                    branch_exit.z = turtle_coords.z + 1
                --then it's 90
                else
                    branch_exit.x = turtle_coords.x - 1
                end
            -- if thing on top is false, then it's 180 or 270
            else
                if turtle_coords.a == 180 then
                    branch_exit.z = turtle_coords.z - 1
                else
                    branch_exit.x = turtle_coords.x + 1
                end
            end
            return branch_exit
        end    
    end
    -- if there is no working branches
    up(1)
    forward(1)
    return false
end

function find_working_subbranch()
    local is_branch_fully_used = false
    local subbranch_exit = false
    for i = 1, subbranch_lenght, 4 do
        forward(4)
        local m = check_marker(-1)
        -- if there is no marked - then it's empty and ready to be mined
        if i + 4 > branch_lenght then
            is_branch_fully_used = true
        end
        if m == "none" then
            rednet.send(log_terminal_id, "Creating " .. i .. " subbranch at " .. get_side_of_the_world(turtle_coords.a) .. " branch, y = " .. turtle_coords.y)
            place_marker("red")
            subbranch_exit = {x = turtle_coords.x, y = turtle_coords.y + 1, z = turtle_coords.z}
            break
        end
    end
    return subbranch_exit, is_branch_fully_used
end

function take_place_and_shutdown(shutdown_reason)
    turn_to_angle(structure_angle)
    turn_left()
    for j = 1, 10 do
        for i = 1, 3 do
            if turtle.down() then
                rednet.send(log_terminal_id, "Shutting down in depot, reason: " .. shutdown_reason)
                error("Shutting down in depot, reason: " .. shutdown_reason)
            end
            forward(1)
        end
        if turtle.down() then
            rednet.send(log_terminal_id, "Shutting down in depot, reason: " .. shutdown_reason)
            error("Shutting down in depot, reason: " .. shutdown_reason)
        end
        if j % 2 ~= 0 then
            turn_right()
            forward(1)
            turn_right()
        else
            turn_left()
            forward(1)
            turn_left()
        end
    end
end

function get_red_markers()
    red_markers = false
    repeat
        -- turtle tries to suck 8 blocks (items) from inventory below
        if not turtle.suckDown(8) then
            -- inventory is empty or doesn't exist
            rednet.send(log_terminal_id, "Not enough red markers!")
            os.sleep(10)
        elseif turtle.getItemCount(1) < 8 then
             -- turtle got markers, but less than 8
            rednet.send(log_terminal_id, "Not enough red markers!")
            os.sleep(10)
        else
            red_markers = true
        end
    until red_markers == true
end

function get_yellow_markers()
    yellow_markers = false
    repeat
        -- turtle tries to suck 8 blocks (items) from inventory below
        if not turtle.suckDown(4) then
            -- inventory is empty or doesn't exist
            rednet.send(log_terminal_id, "Not enough yellow markers!")
            os.sleep(10)
        elseif turtle.getItemCount(1) < 4 then
            -- turtle got markers, but less than 8
            rednet.send(log_terminal_id, "Not enough yellow markers!")
            os.sleep(10)
        else
            yellow_markers = true
        end
    until yellow_markers == true
end

function work()
    -- variables for storaging coordinates of branc/subbranch
    local branch_exit = 0 
    local subbranch_exit = 0
    rednet.send(log_terminal_id, "Starting work cycle...")
    turtle.select(1)
    -- before going to mineshaft, turtle have to check it's fuel level,
    -- if mining lever is on and if it get markers.
    local fuel = turtle.getFuelLevel()
    if fuel < min_fuel_level then
        go_to(depot)
        take_place_and_shutdown('Low fuel level')
    else
        rednet.send(log_terminal_id, "Fuel level is OK (" .. fuel .. ")")
    end
    if redstone.getInput("right") == false then
        go_to(depot)
        take_place_and_shutdown("Mining access lever is off")
    end
    forward(2)
    local red_markers = false
    local yellow_markers = false
    get_red_markers()
    forward(1)
    get_yellow_markers()
    rednet.send(log_terminal_id, "Got markers")
    go_to(mining_entry_down)
    go_to(mining_exit_down)
    -- this delay needed to prevent turtle blocking below, 
    -- that searching for working branch
    os.sleep(4)
    down(1)
    rednet.send(log_terminal_id, "I entered a shaft.")
    branch_exit = find_working_branch()
    if branch_exit == false then
        go_to(mining_entry_up)
        go_to(mining_exit_up)
        go_to(hub_finish)
        go_to(depot)
        take_place_and_shutdown("Shaft is fully mined")
    end
    
    subbranch_exit, is_branch_fully_used = find_working_subbranch()
    if subbranch_exit ~= false then
        mine_subbranch()
    end
    if is_branch_fully_used then
        go_to(branch_exit)
        os.sleep(3)
        forward(1)
        down(1)
        if check_marker(-1) ~= "red" then
            place_marker("red")
        end
        up(1)
    end
    go_to(mining_entry_up)
    go_to(mining_exit_up)
    clear_inventory()
    refuel()
    rednet.send(log_terminal_id, "Going to storage")
    go_to(storage)
    os.sleep(4)
    go_to(hub_finish)
    turn_to_angle(structure_angle)
end

while true do
    work()
    go_to(hub_start)
end


