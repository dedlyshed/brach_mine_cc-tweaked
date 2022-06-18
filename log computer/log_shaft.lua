rednet.open("back")
print("Mineshaft bots log program")
while true do
    _, id, message, distance = os.pullEvent("rednet_message")
    print(id .. ": " .. message)
end
