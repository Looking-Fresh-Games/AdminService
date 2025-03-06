--!strict
--[[
    AdminService.luau
    Author: Zubair A (streetrida)

    Description: A system that allows admin commands to be registered and triggered by specified admins.
	Run LoadConfig before binding a remote.
]]
--

-- Types
type Command = {
	-- [Internal]
	Command: string,
	BoundFunction: (callingPlayer: Player, args: any) -> (),
	OptionalArguments: boolean,
}

export type Configuration = {
	-- [External]
	RegisterDefaultCommands: boolean,
	SendUpdatesToAdmins: boolean,
	Admins: { number },
}

export type AdminService = {
	-- [External]
	-- Record of current admin commands indexed by commandid
	Commands: { [string]: Command },

	-- Record of current admin userids
	Admins: { number },

	-- This method sets up the module with a configuration
	LoadConfig: (self: AdminService, configuration: Configuration?) -> (),

	-- This method will bind a remote to execute admin commands on the server
	BindRemote: (self: AdminService, remote: RemoteEvent) -> (),

	-- This method will internally register an admin command
	RegisterCommand: (
		self: AdminService,
		command: string,
		func: (callingPlayer: Player, args: any) -> (),
		optionalArguments: boolean,
		altCommand: string?
	) -> (),

	-- This method checks whether a provided player has elevated permissions
	IsAdmin: (self: AdminService, player: Player) -> boolean,

	-- This method executes a command on a player's behalf
	Administrate: (self: AdminService, callingPlayer: Player, args: any) -> (),

	-- [Internal]
	-- Triggers bound remote to dispatch all command details to admins in-game
	_dispatchToAdmins: (self: AdminService) -> (),

	-- The registered remote event after BindRemote is called
	_remote: RemoteEvent?,

	-- Supplied configuration for feature toggles
	_config: Configuration?,
}

-- Services
local Players = game:GetService("Players")

--[=[
    @class AdminService

    A system that allows commands to be registered and triggered by specified admins.
]=]
local AdminService = { Commands = {}, Admins = {} } :: AdminService

--------------------------------------------------------------------
-- Methods

--[=[
    Initial config loading

    @within AdminService

    @prop config configuration -- The provided configuration
]=]
function AdminService:LoadConfig(config: Configuration?)
	if not config then
		return
	end

	AdminService._config = config

	if config.Admins then
		for _, userId: number in config.Admins do
			if table.find(self.Admins, userId) then
				continue
			end

			-- Append unique ids
			table.insert(AdminService.Admins, userId)
		end

		AdminService:_dispatchToAdmins()
	end

	if config.RegisterDefaultCommands then
		AdminService:RegisterCommand("admin", function(_callingPlayer: Player, playerName: string?)
			if playerName == nil or typeof(playerName) ~= "string" or Players:FindFirstChild(playerName) == nil then
				warn(`addPlayerToAdmins: failed to add invalid player: {playerName}`)
				return
			end

			local player = Players:FindFirstChild(playerName :: string) :: Player

			if table.find(AdminService.Admins, player.UserId) ~= nil then
				warn(`addPlayerToAdmins: player is already admin: {playerName}`)
				return
			end

			table.insert(AdminService.Admins, player.UserId)

			AdminService:_dispatchToAdmins()
		end, true)
	end
end

--[=[
    Binds a remote to allow for admins to run commands and recieve command data

    @within AdminService

    @param remote RemoteEvent -- Remote bound to Administrate method.
]=]
function AdminService:BindRemote(remote: RemoteEvent?)
	assert(typeof(remote) == "Instance" and remote:IsA("RemoteEvent"), `Supplied object is not a RemoteEvent`)

	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if not AdminService:IsAdmin(player) then
			return
		end

		AdminService:Administrate(player, ...)
	end)

	AdminService._remote = remote

	if AdminService._config and AdminService._config.SendUpdatesToAdmins then
		-- Prevents dropped events where the client may not be listening
		local function updateAdmin(player: Player)
			if not AdminService:IsAdmin(player) then
				return
			end

			task.delay(3, AdminService._dispatchToAdmins, AdminService)
		end

		Players.PlayerAdded:Connect(updateAdmin)

		for _, player: Player in Players:GetPlayers() do
			updateAdmin(player)
		end
	end
end

--[=[
    Registers a new command

    @within AdminService

    @param command string -- The command you want to register
    @param func (callingPlayer: Player, args: any) -- The function to trigger when the command is executed
    @param optionalArguments boolean -- Whether optional arguments can be supplied to the server
    @param altCommand string? -- An alternate trigger string or identifier
]=]
function AdminService:RegisterCommand(
	command: string?,
	func: ((callingPlayer: Player, args: any) -> nil)?,
	optionalArguments: boolean?,
	altCommand: string?
)
	if command == nil or func == nil or type(optionalArguments) ~= "boolean" then
		warn(`Command failed to register!`)
		return
	end

	AdminService.Commands[command] = {
		Command = command,
		AltCommand = altCommand,
		BoundFunction = func,
		OptionalArguments = optionalArguments,
	}

	-- Update admins with full commands index
	AdminService:_dispatchToAdmins()
end

--[=[
    Checks elevation for specified player

    @within AdminService

    @param player Player -- The player you want to check
	@return success boolean -- If the check was successful
]=]
function AdminService:IsAdmin(player: Player): boolean
	if not player then
		return false
	end

	local userId: number = player.UserId

	if table.find(AdminService.Admins, userId) then
		return true
	else
		return false
	end
end

--[=[
    Executes an admin command

    @within AdminService

    @param callingPlayer Player -- The player the request originated from
    @param command string -- The command to execute
    @param ... any -- Any additional arguments that the command might expect
]=]
function AdminService:Administrate(callingPlayer: Player, command: string, ...: any)
	local commandData: Command = AdminService.Commands[command]
	if not commandData then
		return
	end

	commandData.BoundFunction(callingPlayer, ...)
end

--[=[
    Dispatches all command details to admins only

    @within AdminService
]=]
function AdminService:_dispatchToAdmins()
	if not AdminService._remote or not AdminService._config or not AdminService._config.SendUpdatesToAdmins then
		return
	end

	for _, userId: number in AdminService.Admins do
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			continue
		end

		-- Bound function is automatically omitted to the clients
		AdminService._remote:FireClient(player, AdminService.Commands)
	end
end

return AdminService
