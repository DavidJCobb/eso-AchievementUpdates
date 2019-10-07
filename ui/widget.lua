assert(AchievementUpdates, "bad file load order")

local Widget = {
   control = nil,
   pool    = nil,
   items   = {},
   timerRunning = false,
   config = {
      maxItemsToDisplay = 3,
   },
}
AchievementUpdates.Widget = Widget

local POOL_CRITERIA_CHECKBOX
local POOL_CRITERIA_METER

local Item = {}
Item.__index = Item
local sequence = 0
function Item:new(achievement, criterion)
   local result = {
      achievement = achievement, -- Achievement object
      criterion   = criterion,   -- entry from the Achievement's criteria table
      firstShown  = GetGameTimeMilliseconds(), -- used to sort within the UI
      visible     = false,
      control     = nil,
      pool        = nil, -- pool used to generate the control
      poolKey     = nil, -- key for the control, in that pool
      dismissed   = false,
      dismissAnim = nil, -- nil == animation has finished or hasn't started
   }
   setmetatable(result, self)
   do -- used to sort when two items are added on the same frame
      sequence = sequence + 1
      result.sequence = sequence
      zo_callLater(function() sequence = 0 end, 1)
   end
   if type(criterion) == "number" then
      result.criterion = achievement.criteria[criterion]
   end
   result.isCheckbox  = (criterion.required == 1)
   result.lastUpdated = result.firstShown
   return result
end
function Item:dismiss()
   local control = self.control
   if self.dismissed or not control then
      return
   end
   self.dismissed = true
   local anim = control.anim
   if not anim then
      anim = ANIMATION_MANAGER:CreateTimelineFromVirtual("AchievementUpdates_CriterionDismiss", control)
      control.anim = anim
   end
   self.dismissAnim = anim
   local item = self
   self.dismissAnim:SetHandler("OnStop", function() item:dismissDone() end)
   self.dismissAnim:SetEnabled(true)
   self.dismissAnim:PlayFromStart()
   --
   if self.criterion then
      self.criterion.countChange = 0
   end
end
function Item:dismissDone()
   self.dismissAnim:SetHandler("OnStop", nil)
   self.dismissAnim:SetEnabled(false)
   self.dismissAnim = nil
end
function Item:redraw()
   if self.dismissed or not self.visible then
      return
   end
   local control = self.control
   if not control then
      local pool = POOL_CRITERIA_METER
      if self.isCheckbox then
         pool = POOL_CRITERIA_CHECKBOX
      end
      local key
      control, key = pool:AcquireObject()
      self.control = control
      self.pool    = pool
      self.poolKey = key
      control:SetHidden(false)
      if control.animSlideUp then
         control.animSlideUp:Stop()
      end
   end
   if control.anim then
      --
      -- if the control has been recycled, then the fade-out animation 
      -- will have left it invisible
      --
      -- zenimax's APIs don't seem to handle this well at all; there's 
      -- no *readily-apparent* way to tell an animation, "hey, pal, why 
      -- don'cha go on and undo all that stuff y'just did?"
      --
      control:SetAlpha(1)
   end
   local achievement = self.achievement
   local criterion   = self.criterion
   control:GetNamedChild("AchName"):SetText(achievement.name)
   control:GetNamedChild("CritName"):SetText(criterion.description)
   if self.isCheckbox then
      -- nothing to do, yet
   else
      control:GetNamedChild("CritName"):SetText(zo_strformat(GetString(SI_ACHIEVEMENT_UPDATE_FORMAT_OBJECTIVE), criterion.description, criterion.completed, criterion.required, criterion.countChange))
      local bar = control:GetNamedChild("Bar")
      bar:SetMinMax(0, criterion.required)
      bar:SetValue(criterion.completed)
   end
end
function Item:show()
   if self.dismissed or self.visible then
      return
   end
   self.visible     = true
   self.lastUpdated = GetGameTimeMilliseconds()
end
function Item:slideUpBy(distance)
   local control = self.control
   if not control then
      return
   end
   local anim = control.animSlideUp
   if not anim then
      anim = ANIMATION_MANAGER:CreateTimelineFromVirtual("AchievementUpdates_SlideUp", control)
      control.animSlideUp = anim
   end
   anim:GetAnimation(1):SetTranslateDeltas(0, -distance)
   if distance > 0 then
      anim:PlayFromStart()
   else
      anim:Stop()
   end
end
function Item:update()
   if self.dismissed then
      return
   end
   self.lastUpdated = GetGameTimeMilliseconds()
   self:redraw()
end
function Item:__tostring()
   return "[[" .. self.achievement.name .. "][" .. self.criterion.description .. "]]"
end
function Item.__lt(a, b)
   if a.firstShown < b.firstShown then
      return true
   end
   if a.firstShown == b.firstShown then
      return a.sequence < b.sequence
   end
   return false
end

function Widget:initialize(ctrl)
   self.control = ctrl
   self.dragBar = GetControl(ctrl, "Drag")
   do
      local factoryFunction =
         function(objectPool)
            return ZO_ObjectPool_CreateNamedControl(string.format("%sCriteriaCheckboxRow", self.control:GetName()), "AchievementUpdates_CriterionCheckbox", objectPool, self.control)
         end
      local pool = ZO_ObjectPool:New(factoryFunction, ZO_ObjectPool_DefaultResetControl)
      POOL_CRITERIA_CHECKBOX = pool
   end
   do
      local factoryFunction =
         function(objectPool)
            return ZO_ObjectPool_CreateNamedControl(string.format("%sCriteriaMeterRow", self.control:GetName()), "AchievementUpdates_Criterion", objectPool, self.control)
         end
      local pool = ZO_ObjectPool:New(factoryFunction, ZO_ObjectPool_DefaultResetControl)
      POOL_CRITERIA_METER = pool
   end
   do
      local function _listener()
         Widget:onUICursorToggle()
      end
      EVENT_MANAGER:RegisterForEvent("AchievementUpdates", EVENT_GAME_CAMERA_UI_MODE_CHANGED, _listener)
      EVENT_MANAGER:RegisterForEvent("AchievementUpdates", EVENT_GAME_FOCUS_CHANGED, _listener)
   end
end
function Widget:onAddonLoaded()
   self.fragment = ZO_HUDFadeSceneFragment:New(self.control)
   HUD_SCENE:AddFragment(self.fragment)
   HUD_UI_SCENE:AddFragment(self.fragment)
   --
   if AchievementUpdatesSavedata then
      local count = AchievementUpdatesSavedata.maxItemsToDisplay or 3
      self.config.maxItemsToDisplay = count
   end
   --
   self:reflow()
end

function Widget:onUICursorToggle()
   local isUIMode = IsGameCameraUIModeActive() and DoesGameHaveFocus()
   self.dragBar:SetHidden(not isUIMode)
end
function Widget:repositionFromSavedata()
   local sd      = AchievementUpdatesSavedata
   local control = self.control
   control:ClearAnchors()
   control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sd.widgetX, sd.widgetY)
end
function Widget:onMoveStop()
   AchievementUpdatesSavedata.widgetX = self.control:GetLeft()
   AchievementUpdatesSavedata.widgetY = self.control:GetTop()
end

local UPDATE_REGISTRATION_NAME = "AchievementUpdateWidgetTimer"
local MAX_SHOW_DURATION_MS     = 7500
local POLL_FREQUENCY_MS        = 200
local function _update()
   local now   = GetGameTimeMilliseconds()
   local count = #Widget.items
   if count == 0 then
      Widget.timerRunning = false
      EVENT_MANAGER:UnregisterForUpdate(UPDATE_REGISTRATION_NAME)
      return
   end
   local deletedCheckboxes = 0
   local deletedMeters     = 0
   for i = 1, count do
      local item = Widget.items[i]
      if item.dismissed then
         if not item.dismissAnim then -- animation has completed
            item.pool:ReleaseObject(item.poolKey)
            Widget.items[i] = nil
            if item.isCheckbox then
               deletedCheckboxes = deletedCheckboxes + 1
            else
               deletedMeters = deletedMeters + 1
            end
         end
      elseif item.visible then
         if now - item.lastUpdated > MAX_SHOW_DURATION_MS then
            item:dismiss()
         end
      end
   end
   if deletedCheckboxes > 0 or deletedMeters > 0 then
      local list = {}
      local j    = 0
      for i = 1, count do
         local item = Widget.items[i]
         if item then
            j = j + 1
            list[j] = item
         end
      end
      Widget.items = list
      if j == 0 then
         Widget.timerRunning = false
         EVENT_MANAGER:UnregisterForUpdate(UPDATE_REGISTRATION_NAME)
      end
      Widget:reflow(deletedCheckboxes, deletedMeters)
   end
end

do
   local heightCheckbox
   local heightMeter
   function Widget:reflow(countDeletedCheckboxes, countDeletedMeters)
      table.sort(self.items, function(a, b) return a < b end)
      local count   = #self.items
      local yOffset = self.dragBar:GetHeight() + 8
      if count == 0 then
         self.control:SetHeight(yOffset - 8)
         return
      end
      local slideUpDistance
      do
         local dc = ((countDeletedCheckboxes or 0) * (heightCheckbox or 0))
         local dm = ((countDeletedMeters or 0) * (heightMeter or 0))
         slideUpDistance = dc + dm
         --
         -- The slide-up distance is only relevant when one or more displayed 
         -- items has been deleted (i.e. it was dismissed and completed its 
         -- "dismiss" animation). The height values should be computed the 
         -- first time an item of each type is displayed, so by the time the 
         -- slide-up distance is actually *used*, they'll be non-nil.
         --
      end
      for i = 1, math.min(self.config.maxItemsToDisplay, count) do
         local item = self.items[i]
         item:show()
         item:redraw()
         --
         local control = item.control
         if item.isCheckbox then
            if not heightCheckbox then
               local critName = control:GetNamedChild("CritName")
               heightCheckbox = critName:GetBottom() - control:GetTop()
            end
         else
            if not heightMeter then
               local bar = control:GetNamedChild("Bar")
               heightMeter = bar:GetBottom() - control:GetTop()
            end
         end
         local height = heightMeter
         if item.isCheckbox then
            height = heightCheckbox
         end
         if i == 1 and slideUpDistance then
            --
            -- When an entry is deleted from the list, we apply a 
            -- "slide up" animation to the other rendered entries. 
            -- We need to leave some blank space for them to slide 
            -- up into. The animation moves them upward, so their 
            -- base position must be beneath the space they're 
            -- sliding into.
            --
            yOffset = yOffset + slideUpDistance
         end
         control:ClearAnchors()
         control:SetAnchor(TOPLEFT, self.control, TOPLEFT, 0, yOffset)
         item:slideUpBy(slideUpDistance)
         --
         yOffset = yOffset + height + 16
      end
      self.control:SetHeight(yOffset - 16)
   end
end

function Widget:showCriterion(achievement, criteriaIndex)
   if not self.timerRunning then
      self.timerRunning = true
      EVENT_MANAGER:RegisterForUpdate(UPDATE_REGISTRATION_NAME, POLL_FREQUENCY_MS, _update)
   end
   local criterion = achievement.criteria[criteriaIndex]
   if not criterion then
      return
   end
   for i = 1, #self.items do
      local item = self.items[i]
      if item.achievement == achievement then
         if item.criterion == criterion then
            if not item.dismissed then
               item:update()
               return
            end
         end
      end
   end
   local item = Item:new(achievement, criterion)
   self.items[#self.items + 1] = item
   self:reflow()
end