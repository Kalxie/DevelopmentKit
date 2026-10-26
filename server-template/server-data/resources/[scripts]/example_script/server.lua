RegisterCommand('coreversion', function(source)
    local version = exports.example_core:getVersion()
    print(('example_core version: %s'):format(version))
end, true)
