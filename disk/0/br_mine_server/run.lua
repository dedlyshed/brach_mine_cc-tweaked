-- CONFIG
local c_turtle = {x = 10, y = 67, z = 0, f = 0}  -- turtle spawn coordinates
-- f is for facing: 0 - south, 90 - west, 180 - north, 270 - east
local branch_lenght = 8
local subbr_lenght = 10
local subbr_width = 4       -- even numbers more time-effective
local branch_height = 40        -- y coord of lowest point
local max_branch_height = 50    -- y coord of highest point 
-- END CONFIG
local subbranches_amount = branch_lenght / 4
local c_center = {x = c_turtle.x, y = branch_height, z = c_turtle.z + 5}

-- FUNCTIONS
-- writes to ./data.txt current level (y), branch/subbranch status
-- dL = {y, south_subbr_num, west_subbr_num, north_subbr_num, east_subbr_num}
-- subbr_num - from 1 to subbranches_amount
function write_data(dL)
    local pwd = shell.dir()
    data = fs.open(pwd.."/data.txt", "w")
    data.writeLine(tostring(dL[1]))
    data.writeLine(tostring(dL[2]))
    data.writeLine(tostring(dL[3]))
    data.writeLine(tostring(dL[4]))
    data.writeLine(tostring(dL[5]))
    data.close()
end

-- reads from ./data.txt current level (y), branch/subbranch status
-- return data lines table
function read_data()
    local pwd = shell.dir()
    if not fs.exists(pwd .. "/data.txt") then
        print("File ./data.txt doesn't exists. Creating new...")
        write_data({branch_height, 1, 1, 1, 1})
    end
    data = fs.open(pwd .. "/data.txt", "r")
    local dL = {}
    for i = 1, 5 do  
        dL[i] = tonumber(data.readLine())
        -- this will load current y to variable if program stopped and started again
        if i == 1 then branch_height = dL[1] end
    end
    data.close()
    return dL
end

-- searching in y level avaible subbranch number and facing
function find_subbranch_direction()
    local dataLines = read_data()
    local subbr_dir = nil
    for i = 2, 5 do
        if dataLines[i] <= subbranches_amount then
            print(("Found free subbranch %d facing %d"):format(dataLines[i], (i-2)*90))
            subbr_dir = {dataLines[i], (i-2)*90}
            dataLines[i] = dataLines[i] + 1
            write_data(dataLines)
            break
        end
    end
    return subbr_dir
end

-- translates subbranch_num, facing to x,y,z,f coordinates for turtle
function direction_to_coords(sbr_dir)
    c_subbranch = {x = c_center.x, y = branch_height, z = c_center.z}
    if sbr_dir[2] == 0 or sbr_dir[2] == 180 then
        if sbr_dir[2] == 0 then -- changing z coordinate
            c_subbranch.z = c_subbranch.z + (subbr_width * sbr_dir[1]) + 1
        else
            c_subbranch.z = c_subbranch.z - (subbr_width * sbr_dir[1]) - 1
        end
    else
        if sbr_dir[2] == 90 then -- changing x coordinate
            c_subbranch.x = c_subbranch.x - subbr_width * sbr_dir[1] - 1
        else
            c_subbranch.x = c_subbranch.x + subbr_width * sbr_dir[1] + 1
        end
    end
    c_subbranch.f = 270
    return c_subbranch
end

function new_subbranch_coords()
    -- searching in y level avaible subbranch number and facing
    subbr_dir = find_subbranch_direction()
    if subbr_dir == nil then -- if no free subbranch on y available
        print("Layer y:" .. branch_height .. " is fully mined.")
        branch_height = branch_height + 3 -- tries next branch_height
        if branch_height > max_branch_height then -- if br_height > max_br_height
            print("Branch_height riched max value " .. max_branch_height)
            error("This area is fully mined. Stopping server.") -- end
        end
        write_data({branch_height, 1, 1, 1, 1}) -- if not end, then new br_height
        subbr_dir = find_subbranch_direction()
    end
    return direction_to_coords(subbr_dir)
end

-- sends to turtle start x, y, z, facing, branch x, y, z, facing, lenght, width
function send_init_info(id, c_subbranch)
    rednet.send(id, ("%d,%d,%d,%d,%d,%d,%d,%d,%d,%d"):format(c_turtle.x, 
    c_turtle.y, c_turtle.z, c_turtle.f, c_subbranch.x, 
    c_subbranch.y, c_subbranch.z, c_subbranch.f, subbr_lenght, subbr_width))
end
-- END FUNCTIONS

-- MAIN BODY
print("Branch mine server v.1.2")
print("Select mode:")
print("1 - Continue mining area")
print("2 - New mining area")
local a = tonumber(read())
if a == 2 then
    print("Creating a new area data set")
    write_data({branch_height, 1, 1, 1, 1})
end
if a ~= 1 and a ~= 2 then
    error("Use only 1 or 2")
end
print("Starting rednet and waiting for requests")
local modem = peripheral.wrap("top")
modem.open(0)
while true do
    local _,_,_,_,message,_ = os.pullEvent("modem_message")
    print("Turtle, id:" .. message .. " requested init info")
    local c_subbranch = new_subbranch_coords()
    print(("Subbr coords: x:%d, y:%d, z:%d, f:%d"):format(c_subbranch.x, 
        c_subbranch.y, c_subbranch.z, c_subbranch.f))
    modem.transmit(0, 0, ("%d,%d,%d,%d,%d,%d,%d,%d,%d"):format(c_turtle.x, 
    c_turtle.y, c_turtle.z, c_turtle.f, c_subbranch.x, 
    c_subbranch.y, c_subbranch.z, subbr_lenght, subbr_width))
end
-- END MAIN BODY
