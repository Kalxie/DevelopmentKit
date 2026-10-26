RegisterCommand('hello', function()
    TriggerEvent('chat:addMessage', { args = { 'example_script', 'Hello from the client!' } })
end, false)
