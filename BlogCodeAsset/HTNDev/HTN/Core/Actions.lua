---------------------------------------------------------------------
-- Yimi_HTNs (C) CompanyName, All Rights Reserved
-- Created by: AuthorName
-- Date: 2019-11-29 13:14:40
---------------------------------------------------------------------

-- 注意行动名称需要和任务名称一致，方法中的子任务也需要注意检测是否一致
---@class Actions
require "HTN.Utils.SubstituteUtility"
require "HTN.Utils.LogUtil"
local Actions = {}
function Actions:GetAction(_actiondecl)
	local name, p = splitFunc( _actiondecl)
	return self[name](table.unpack(p))
end

Actions.Move = function(...)
	local input = {...}
	local env = setmetatable(
		{
			f = input[1],
			t = input[2]
		},
		{__index = _G}
	)
	local action = {}
	action.Effects = {
		positive = {
			Substitute("BoatAt([t])",env)
		},
		negative = {
			Substitute("BoatAt([f])",env)
		}
	}	
	action.Execute = function(self,_ws)
		--local parser = NewParser(self.substitutions)
		--parser.dostring("printf('move %s to %s',f,t)")
		-- TODO 实现
	end
	return action
end 

Actions.Load = function(...)
	local input = {...}
	local env = setmetatable(
		{
			l = input[1],
			m = input[2],
			c = input[3]
		},
		{__index = _G}
	)
	local action = {}
	action.Effects = {
		preoperties = {
			Substitute("[l].missionaryNum = [l].missionaryNum - [m]",env),
			Substitute("[l].cannibalNum = [l].cannibalNum - [c]",env)
		}
	}
	action.Execute = function(self,_ws)
		
		-- TODO 实现
	end
	return action
end
Actions.UnLoad = function(...)
	local input = {...}
	local env = setmetatable(
		{
			l = input[1],
			m = input[2],
			c = input[3]
		},
		{__index = _G}
	)
	local action = {}
	action.Effects = {
		preoperties = {
			Substitute("[l].missionaryNum = [l].missionaryNum + [m]",env),
			Substitute("[l].cannibalNum = [l].cannibalNum + [c]",env)
		}
	}
	action.Execute = function(self,_ws)

		-- TODO 实现
	end
	return action
end

return Actions