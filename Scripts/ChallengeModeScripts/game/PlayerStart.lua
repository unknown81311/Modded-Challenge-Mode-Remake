-- PlayerStart.lua --

PlayerStart = class()

--[[ Client ]]

local buttons =
{
	"enable_client_toilet",
	"enable_lift",
	"enable_sledgehammer",
	"enable_connecttool",
	"enable_painttool",
	"enable_weldtool",
	"enable_handbook",
	"enable_spudgun",
	"enable_ammo_consumption",
	"enable_fuel_consumption",
	"enable_health",
}

local opened = nil

-- (Event) Called upon creation on client
function PlayerStart.client_onCreate( self )
	self.cl = {}
	self:client_init()
end

-- (Event) Called when script is refreshed (in [-dev])
function PlayerStart.client_onRefresh( self )
	self:client_init()
end

function PlayerStart.client_onInteract( self, player, state )
	if state then
		opened = self
		self.cl.guiInterface = sm.gui.createGuiFromLayout( "$CONTENT_DATA/Gui/Layouts/Interactable_PlayerStart.layout" )
		
		for _, button in ipairs( buttons ) do
			self.cl.guiInterface:setButtonCallback( button .. "On", "cl_onButtonClick" )
			self.cl.guiInterface:setButtonCallback( button .. "Off", "cl_onButtonClick" )
		end

		self.cl.guiInterface:setOnCloseCallback( "cl_onClose" )

		self:cl_refreshGui()
		self.cl.guiInterface:open()
	end
end

function PlayerStart.cl_refreshGui( self )
	if self.cl.guiInterface then
		local settings = sm.storage.load( "levelSettings" )
		for _, button in ipairs( buttons ) do
			local setting = getSettingValue( settings, button )
			self.cl.guiInterface:setButtonState( button .. "On",  setting )
			self.cl.guiInterface:setButtonState( button .. "Off",  not setting )
		end
	end
end

function PlayerStart.cl_onButtonClick( self, name )
	local settings = {}
	for _, button in ipairs( buttons ) do
		if name == button.."On" then
			settings[button] = true
		end
		if name == button.."Off" then
			settings[button] = false
		end
	end

	self.network:sendToServer( "sv_n_updateSettings", settings )
	self:cl_refreshGui()
end

function PlayerStart.cl_onClose( self, name )
	opened = nil
	if self.cl.guiInterface then
		self.cl.guiInterface:destroy()
		self.cl.guiInterface = nil
	end
end

function PlayerStart.sv_n_updateSettings( self, params )
	local levelSettings = sm.storage.load("levelSettings")
	
	for k,v in pairs( params ) do
		levelSettings[k] = v
	end

	sm.storage.saveAndSync( "levelSettings", levelSettings )
	self.network:sendToClients( "cl_n_updateSettings" )
end

function PlayerStart.cl_n_updateSettings( self )
	if opened then
		opened:cl_refreshGui()
	end
end

-- Initialize PlayerStart
function PlayerStart.client_init( self )
	self.client_glowEffect = sm.effect.createEffect( "PlayerStart - Glow", self.interactable )
	self.client_glowEffect:start()
end