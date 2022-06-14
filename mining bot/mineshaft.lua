local log_terminal_id = 3
-- turtle will log it's activity on log pc 
rednet.open("right")

-- configuration
local min_fuel_level = 1500
local branch_lenght = 100
local subbranch_lenght = 100
-- place where you place turtle (it will be his start coordinates)
-- all other coordinates calculation are depending on that
local hub_spawn =   {x = -248, y = 65, z = -217}
-- place where turtle should go after finishing the work
local hub_destroy = {x = -248, y = 67, z = -217}
-- place undeground from where branches will go in different sides
local mining_center = {x = -248, y = 11, z = -214}
-- place where turtle will collect his mined ores and etc.
local depot = {x = -248, y = 66, z = -211}
-- surface level y coordinate
local surface_y = 65

-- a means angle to south (rotation clockwise)
local turtle_coords =     {x = hub_spawn.x, y = hub_spawn.y, z = hub_spawn.z, a = 0}
-- turtles move verticaly in different paths (x,z coordinates) to prevent collisison
local mining_entry_down = {x = mining_center.x, y = surface_y, z = mining_center.z}
local mining_exit_down =  {x = mining_center.x, y = mining_center.y, z = mining_center.z}
local mining_entry_up =   {x = mining_center.x, y = mining_center.y + 1, z = mining_center.z + 1}
local mining_exit_up =    {x = mining_center.x, y = surface_y + 1, z = mining_center.z + 1}
-- can be turned off if turtle is higher that some coordinate (to prevent destroying buldings)
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
function check_marker()
    local success, data = turtle.inspectDown()
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
                    rednet.send(log_terminal_id, "Can't go forward! Another turtle in front of me!")
                    os.sleep(3)
                    --error("Can not go forward - turtle is on the way")
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
                    os.sleep(3)
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
                    os.sleep(3)
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
        local trash = {"cobblestone", "flint", "gravel"}
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

function work()
    -- variables for storaging coordinates of branc/subbranch
    local branch_exit = 0 
    local subbranch_exit = 0
    rednet.send(log_terminal_id, "Hello! I am on duty!")
    turtle.select(1)
    fuel = turtle.getFuelLevel()
    if fuel >= min_fuel_level then
        rednet.send(log_terminal_id, "Fuel level is OK (" .. fuel .. ')')
        forward(1)
        red_markers = false
        yellow_markers = false
        repeat
            if not turtle.suckUp(4) then
                rednet.send(log_terminal_id, "Not enough red markers!")
                os.sleep(10)
            else
                red_markers = true
            end
        until red_markers == true
        forward(1)
        repeat
            if not turtle.suckUp(4) then
                rednet.send(log_terminal_id, "Not enough yellow markers!")
                os.sleep(10)
            else
                yellow_markers = true
            end
        until yellow_markers == true
        rednet.send(log_terminal_id, "Got markers")
        go_to(mining_entry_down)
        go_to(mining_exit_down)
        rednet.send(log_terminal_id, "I entered a shaft.")
        local only_red_marks = true
        for i = 0, 3 do
            turn_to_angle(i*90)
            forward(1)
            local m = check_marker()
            if m == "red" then
                turn_right()
                turn_right()
                forward(1)
                turn_right()
                turn_right()
            elseif m == "none" then
                place_marker('yellow')
                rednet.send(log_terminal_id, "Creating new branch at " .. turtle_coords.x .. ", " .. turtle_coords.y .. ", " .. turtle_coords.z)
                only_red_marks = false
                branch_exit = {x = turtle_coords.x, y = turtle_coords.y, z = turtle_coords.z}
                break
            else 
                rednet.send(log_terminal_id, "Found working branch at " .. turtle_coords.x .. ", " .. turtle_coords.y .. ", " .. turtle_coords.z)
                only_red_marks = false
                branch_exit = {x = turtle_coords.x, y = turtle_coords.y, z = turtle_coords.z}
                break
            end
        end
        if not only_red_marks then
            local found_subbranch = false
            local can_expand = true
            for i = 1, branch_lenght, 4 do
                forward(4)
                local m = check_marker()
                if m == "none" then
                    rednet.send(log_terminal_id, "Starting subbranch at " .. turtle_coords.x .. ", " .. turtle_coords.y .. ", " .. turtle_coords.z)
                    found_subbranch = true
                    place_marker("red")
                    subbranch_exit = {x = turtle_coords.x, y = turtle_coords.y + 1, z = turtle_coords.z}
                    mine_subbranch()
                    if i + 4 > branch_lenght then
                        rednet.send(log_terminal_id, "Prognose: This branch can't expand more. Closing it.")
                        can_expand = false
                    end
                    break
                end
            end
            if found_subbranch then
                go_to(subbranch_exit)
                if not can_expand then 
                    -- going to branch exit but in one block highter, so that turtles don't collide
                    go_to({x = branch_exit.x, y = branch_exit.y+1, z = branch_exit.z})
                    go_to(branch_exit)
                    place_marker("red")
                end
            else
                rednet.send(log_terminal_id, "This branch can't expand more. Closing it.")
                go_to(branch_exit)
                place_marker("red")
            end
        else
            rednet.send(log_terminal_id, "Not any avaible branch at " .. turtle_coords.x, turtle_coords.y, turtle_coords.z)
        end
        go_to(mining_entry_up)
        go_to(mining_exit_up)
        rednet.send(log_terminal_id, "Going to depot.")
        refuel()
        go_to(depot)
        os.sleep(6)
        go_to(hub_destroy)
        print('Finished with coordinates: ' .. turtle_coords.x .. ' ' .. turtle_coords.y .. ' ' .. turtle_coords.z)
        print('Angle to south clockwise: ' .. turtle_coords.a)
    else
        rednet.send(log_terminal_id, "Fuel level is LOW (" .. fuel .. "). Please refuel me!")
        rednet.send(log_terminal_id, "Going to maintenance zone")
        turn_left()
        for j = 1, 4 do
            turtle.forward()
        end
    end
    rednet.send(log_terminal_id, "My work is done! Bye!")
end

while true do
    work()
    go_to(hub_spawn)
    turn_right()
    turn_right()
end

