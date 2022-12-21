print("!!!FOUND startup.lua FILE ON DISK!!!")
if turtle then
    print("I'm turtle!")
    print("Loading turtle script...")
    shell.run("disk/br_mine_client/run")
else
    print("I'm server!")
    os.setComputerLabel("br_mine server")
    print("Loading server script...")
    --print("My ID is " .. os.getComputerID())
    shell.run("disk/br_mine_server/run")
end
