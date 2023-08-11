 -- Trigger.lua --

Trigger = class()

Trigger.poseWeightCount = 1
Trigger.maxParentCount = 1
Trigger.maxChildCount = 255
Trigger.connectionInput = sm.interactable.connectionType.logic
Trigger.connectionOutput = sm.interactable.connectionType.logic
Trigger.colorNormal = sm.color.new( 0x9d0e44ff )
Trigger.colorHighlight = sm.color.new( 0xc21659ff )

--[[ Server ]]

-- (Event) Called upon creation on server
function Trigger.server_onCreate( self )

	local padding = 0.025
	local size = sm.vec3.new( 0.5-padding, 32.0 * 0.25, 0.5-padding )
	local filter = sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.character
	self.areaTrigger = sm.areaTrigger.createAttachedBox( self.interactable, size, sm.vec3.new(0.0, size.y + ( 0.25 * 0.5 ), 0.0), sm.quat.identity(), filter )

	self.areaTrigger:bindOnEnter( "trigger_onEnter" )
	self.areaTrigger:bindOnExit( "trigger_onExit" )

	self.server_triggerActive = false
end

function Trigger.trigger_onEnter( self, trigger, results )
	if not sm.exists( self.interactable ) then
		return
	end

	local active = false
	if #results > 0 or #trigger:getContents() > 0 then
		active = true
	end

	self.server_triggerActive = active
end

function Trigger.trigger_onExit( self, trigger, results )
	if not sm.exists( self.interactable ) then
		return
	end

	local active = false
	if #trigger:getContents() > 0 then
		active = true
	end

	self.server_triggerActive = active
end

function Trigger.server_onFixedUpdate( self )
	local parent = self.interactable:getSingleParent()
	local parentActive = true
	if parent then
		parentActive = parent.active
	end

	local active = false
	if parentActive and self.server_triggerActive then
		active = true
	end

	self.interactable.active = active
end

--[[ Client ]]

function Trigger.client_onUpdate( self, dt )
	self.interactable:setPoseWeight( 0, self.interactable.active and 1 or 0 )
end