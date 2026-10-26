local open = false

RegisterCommand('exampleui', function()
    open = not open
    SetNuiFocus(open, open)
    SendNUIMessage({ action = 'setVisible', visible = open })
end, false)

RegisterNUICallback('close', function(_, cb)
    open = false
    SetNuiFocus(false, false)
    cb({})
end)
