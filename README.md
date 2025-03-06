# AdminService
A system that allows admin commands to be registered and triggered by specified admins.

# Usage
```luau
local AdminService = require(ServerStorage.ServerPackages.AdminService)

local config: AdminService.Configuration =
	{ Admins = {1301107}, RegisterDefaultCommands = true, SendUpdatesToAdmins = true }

AdminService:LoadConfig(config)

AdminService:BindRemote(ReplicatedStorage.Remotes:WaitForChild("Administrate"))
```