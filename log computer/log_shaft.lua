rednet.open("back")
print("Staring up log shaft program")
while true do
    _, id, message, distance = os.pullEvent("rednet_message")
    print(id .. ": " .. message)
end
