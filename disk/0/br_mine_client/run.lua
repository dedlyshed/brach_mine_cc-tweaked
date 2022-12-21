-- CONFIG
local server_id = 8
local min_fuel_level = 1500
-- END CONFIG

-- FUNCTIONS
-- when recieving a message via rednet, 10 number values came as 1 string
-- separated with commas. this function returns table with num values form str 
function split_and_int(str, sep)
    if sep == nil then sep = "%s" end
    local t={}
    for s in string.gmatch(str, "([^"..sep.."]+)") do
        table.insert(t, tonumber(s))
    end
    return t
end

-- asks server via modem for start x,y,z,f, branch x,y,z,f, branch width, length 
function get_init_info()
    modem = peripheral.wrap("left")
    modem.open(0)
    modem.transmit(0, 0, os.getComputerID())
    local timeout = os.startTimer(2)
    while true do
        event,timer,_,_,message,_ = os.pullEvent()
        if event == "modem_message" then
            local t = split_and_int(message, ",")
            return t
        elseif event == "timer" and timer == timeout then
            return nil
        end
    end
end

-- while mining, turtle will look at blocks above it and below
-- if in block name is substing 'ore' - turtle will mine it
function check_mine_ore()
    local success_up, data_up = turtle.inspectUp() -- if any block found up
    local success_down, data_down = turtle.inspectDown() -- if any block down
    if success_up then
        res = string.find(data_up.name, "ore")
        if res ~= nil then
            turtle.digUp()
        end
    end
    if success_down then
        res = string.find(data_down.name, "ore")
        if res ~= nil then
            turtle.digDown()
        end
    end
end

function refuel()
    for slot = 1, 16 do
        turtle.select(slot)
        turtle.refuel(64)
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
                if res ~= nil then turtle.drop() end
            end
        end
    end
end
-- if something is on the way, this function is being called to check, 
-- if there is turtle on the way to prevent turtle 'friendlymining'
function inspect_turtle(side)
    local success, data = 0, 0
    if side == 0 then -- inspect block in front of turtle
        success, data = turtle.inspect()
    elseif side == 1 then
        success, data = turtle.inspectUp()
    elseif side == -1 then
        success, data = turtle.inspectDown()
    end
    if success then -- success means that there is block/turtle on the side
        res = string.find(data.name, "turtle") -- gets block name from side
        if res == nil then -- if block_name contain "turtle"
            return false
        else                -- if block_name doesn't contain "turtle"
            return true
        end
    end
    return false -- there is no block on the side, free to mine/go
end

-- responsible for coordinates x or z update when moving forward
-- depending on facing, x or z can be incremented or decremented
function update_xz_coordinates(c_turtle)
    if c_turtle.f <= 90 then -- if current facing 0 or 90
        if c_turtle.f == 0 then
            c_turtle.z = c_turtle.z + 1
        else --then it's 90
            c_turtle.x = c_turtle.x - 1
        end
    else -- then current facing 180 or 270
        if c_turtle.f == 180 then
            c_turtle.z = c_turtle.z - 1
        else -- then it's 270
            c_turtle.x = c_turtle.x + 1
        end
    end
end

-- advanced functions to move turtle forward/up/down: mines block on the way,
-- updates coordinates, does not allow to mine turtles, repeats until success
function forward(c_turtle, blocks)
    for i = 1, blocks do
        local is_success = false
        repeat
            if turtle.forward() then -- trying to go forward
                update_xz_coordinates(c_turtle)
                is_success = true
            else -- turtle doesn't go forward, trying to solve
                -- detecting if it's not an other turtle
                if inspect_turtle(0) then -- there is turtle on a way
                    os.sleep(1)
                else -- then it's a block, mine it
                    turtle.dig()
                end
            end
        until is_success == true -- retries go forward until success
    end
end

function up(c_turtle, blocks)
    for i = 1, blocks do
        local is_success = false
        repeat
            if turtle.up() then -- trying to go up
                c_turtle.y = c_turtle.y + 1
                is_success = true
            else -- turtle doesn't go up, trying to solve
                if inspect_turtle(1) then -- there is turtle on a way
                    os.sleep(1)
                else -- then it's a block, mine it
                    turtle.digUp()
                end
            end
        until is_success == true -- retries go up until success
    end
end

function down(c_turtle, blocks)
    for i = 1, blocks do
        local is_success = false
        repeat
            if turtle.down() then -- trying to go down
                c_turtle.y = c_turtle.y - 1
                is_success = true
            else -- turtle doesn't go down, trying to solve
                if inspect_turtle(-1) then -- there is turtle on a way
                    os.sleep(1)
                else -- then it's a block, mine it
                    turtle.digDown()
                end
            end
        until is_success == true -- retries go down until success
    end
end

-- anvanced functions for turning, also calculates facing
function turn_right(c_turtle)
    turtle.turnRight()
    c_turtle.f = c_turtle.f + 90
    if c_turtle.f >= 360 then
        c_turtle.f = 0
    end
end

function turn_left(c_turtle)
    turtle.turnLeft()
    c_turtle.f = c_turtle.f - 90
    if c_turtle.f < 0 then
        c_turtle.f = 270
    end
end

function turn_to_facing(c_turtle, facing)
    if facing == nil then return end
    if c_turtle.f == facing then
        return
    end
    repeat 
        turn_right(c_turtle)
    until c_turtle.f == facing
end

-- turtle will move to new coordinates
function go_to(c_turtle, new_coords)
    -- firstly turtle will allign x, then z, then y
    if new_coords.x > c_turtle.x then
        turn_to_facing(c_turtle, 270)
        forward(c_turtle, new_coords.x - c_turtle.x)
    elseif new_coords.x < c_turtle.x then
        turn_to_facing(c_turtle, 90)
        forward(c_turtle, c_turtle.x - new_coords.x)
    end
    if new_coords.z > c_turtle.z then
        turn_to_facing(c_turtle, 0)
        forward(c_turtle, new_coords.z - c_turtle.z)
    elseif new_coords.z < c_turtle.z then
        turn_to_facing(c_turtle, 180)
        forward(c_turtle, c_turtle.z - new_coords.z)
    end
    if new_coords.y > c_turtle.y then
        up(c_turtle, new_coords.y - c_turtle.y)
    elseif new_coords.y < c_turtle.y then
        down(c_turtle, c_turtle.y - new_coords.y)
    end
    turn_to_facing(c_turtle, new_coords.f)
end

function mine_subbranch(c_turtle, subbr_lenght, subbr_width)
    turn_left(c_turtle)
    forward(c_turtle, 1)
    check_mine_ore()
    for i = 1, subbr_width do
        for j = 1, subbr_lenght - 1 do
            forward(c_turtle, 1)      
            check_mine_ore()  
        end
        if i % 2 == 0 then
            turn_right(c_turtle)
            forward(c_turtle, 1)
            check_mine_ore()
            turn_right(c_turtle)
        else
            turn_left(c_turtle)
            forward(c_turtle, 1)
            check_mine_ore()
            turn_left(c_turtle)
        end
        clear_inventory()
    end
    up(c_turtle, 1)
    refuel()
end

function take_place_and_shutdown(c_turtle)
    down(c_turtle, 2)
    for j = 1, 5 do
        for i = 1, 8 do
            if turtle.down() then
                return
            end
            forward(c_turtle, 1)
        end
        if turtle.down() then
            error("Shutting down in depot")
        end
        if j % 2 ~= 0 then
            turn_right(c_turtle)
            forward(c_turtle, 1)
            turn_right(c_turtle)
        else
            turn_left(c_turtle)
            forward(c_turtle, 1)
            turn_left(c_turtle)
        end
    end
end
-- END FUNCTIONS

-- MAIN BODY
print("Branch mine client v.1.2")
print("Checking fuel level...")
local fuel = turtle.getFuelLevel()
while turtle.getFuelLevel() < min_fuel_level do
    print("Low fuel level!")
    print("Min:"..min_fuel_level.." Now:"..turtle.getFuelLevel())
    print("Trying to refuel...")
    refuel()
end
print("Fuel level OK")
print("Now I'll work until area is fully mined or my fuel gets low")
while true do
    print("Waiting for redsote signal to start...")
    while redstone.getInput("right") == false do
        sleep(1)
    end
    print("I've got redstone signal, let's go!")
    print("Getting init info form server via modem")
    print("...")
    -- getting start x, y, z, facing, branch x, y, z, lenght, width
    local t = get_init_info(server_id)
    if t == nil then -- no answer from the server
        local c_start = {x = 0, y = 0, z = 0, f = 0}
        local c_turtle = {x = 0, y = 0, z = 0, f = 0}
        local c_depot = {x = c_start.x - 2, y = c_start.y + 3, z = c_start.z + 1, f = c_start.f}
        turn_right(c_turtle)
        turn_right(c_turtle)
        forward(c_turtle, 1)
        up(c_turtle, 3)
        go_to(c_turtle, c_depot)
        take_place_and_shutdown(c_turtle)
        error("No answer from server")
    end
    local c_start = {x = t[1], y = t[2], z = t[3], f = t[4]}
    local c_turtle = {x = t[1], y = t[2], z = t[3], f = t[4]}
    local c_subbranch = {x = t[5], y = t[6], z = t[7]}
    local subbr_lenght = t[8]
    local subbr_width = t[9]
    local c_center = {x = c_start.x, y = c_subbranch.y, z = c_start.z + 5}
    local c_storage = {x = c_start.x, y = c_turtle.y + 1, z = c_start.z + 8}
    -- turtles move verticaly in different paths (x,z coordinates) to prevent collisison
    local c_entry_down = {x = c_center.x, y = c_start.y, z = c_center.z}
    local c_exit_down =  {x = c_center.x, y = c_center.y, z = c_center.z}
    local c_entry_up =   {x = c_center.x, y = c_center.y + 1, z = c_center.z + 1}
    local c_exit_up =    {x = c_center.x, y = c_start.y + 1, z = c_center.z + 1}
    local c_depot = {x = c_start.x - 2, y = c_start.y + 3, z = c_start.z + 1, f = c_start.f}
    print("Success! Params are:")
    print(("Current coords: x:%d, y:%d, z:%d, f:%d"):format(c_turtle.x, 
        c_turtle.y, c_turtle.z, c_turtle.f))
    print(("Subbr coords: x:%d, y:%d, z:%d"):format(c_subbranch.x, 
        c_subbranch.y, c_subbranch.z))
    print(("Subbr: length:%d, width:%d"):format(subbr_lenght, subbr_width))
    print(c_turtle.x, c_turtle.y, c_turtle.z, c_turtle.f)
    go_to(c_turtle, c_entry_down)
    go_to(c_turtle, c_exit_down)
    go_to(c_turtle, c_subbranch)
    mine_subbranch(c_turtle, subbr_lenght, subbr_width)
    go_to(c_turtle, c_entry_up)
    go_to(c_turtle, c_exit_up)
    clear_inventory()
    go_to(c_turtle, c_storage)
    sleep(5) -- time to drop items to storage
    up(c_turtle, 1)
    go_to(c_turtle, {x = c_start.x, y = c_start.y + 1, z = c_start.z, f = c_start.f})
    if turtle.getFuelLevel() < min_fuel_level then
        go_to(c_turtle, c_depot)
        take_place_and_shutdown(c_turtle)
        error("No enough fuel")
    end
    down(c_turtle, 1) 
end
-- END MAIN BODY
