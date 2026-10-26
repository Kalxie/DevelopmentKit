AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        Core.log('server started')
    end
end)

-- Other resources can call this with exports.example_core:getVersion()
exports('getVersion', function()
    return GetResourceMetadata(GetCurrentResourceName(), 'version', 0)
end)
