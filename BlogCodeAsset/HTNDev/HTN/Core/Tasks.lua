---------------------------------------------------------------------
-- Yimi_HTNs (C) CompanyName, All Rights Reserved
-- Created by: AuthorName
-- Date: 2019-11-28 05:29:02
---------------------------------------------------------------------

-- 任务定义

---@class Tasks
require "HTN.Utils.SubstituteUtility"

local Tasks = {}

function Tasks:GetTask(_taskdecl)		
	local name, p = splitFunc( _taskdecl)
	return self[name](table.unpack(p))
end

Tasks.Move = function ( ... )
	local input = {...}
	local env = setmetatable(
		{
			f = input[1],
			t = input[2]
		},
		{__index = _G}
	)
	local task = {}
	task.IsPrimitive = true
	task.preconds = {
		relations = {
			positive ={ Substitute("BoatAt([f])",env) }
		}
	}
	return task
end

Tasks.Load = function(...)
	local input = {...}
	local env = setmetatable(
		{
			l = input[1],
			m = input[2],
			c = input[3]
		},
		{__index = _G}
	)
	local task = {}	
	task.IsPrimitive = true
	task.preconds = {
		relations = {
			positive = {Substitute("BoatAt([l])",env)}
		},
		valuelimits = {
			Substitute('[l].missionaryNum > [m]',env)
		}
	}
	return task
end

Tasks.UnLoad = function( ... )
	local input = {...}
	local env = setmetatable(
		{
			l = input[1],
			m = input[2],
			c = input[3]
		},
		{__index = _G}
	)
	local task = {}
	task.IsPrimitive = true
	task.preconds = {
		relations = {
			Substitute("BoatAt([l])",env)
		},
		valuelimits = {
			Substitute('[l].missionaryNum + [m] >= [l].cannibalNum + [c]',env)
		}
	}
	return task
end

Tasks.Transport =function (...)
	local input = {...}
	local env = setmetatable(
		{
			f = input[1],
			t = input[2]
		},
		{__index = _G}
	)
	local task = {}
	task.IsPrimitive = false
	task.preconds = {
		valuelimits = {
			Substitute("LocA.missionaryNum + LocA.cannibalNum != 0",env)
		}
	}
	task.Methodes = {
		Substitute("Load_2m0c([f],[t],2,0)",env),
		Substitute("Load_1m1c([f],[t],1,1)",env),
		Substitute("Load_1m0c([f],[t],1,0)",env),
		Substitute("Load_0m1c([f],[t],0,1)",env),
		Substitute("Load_0m2c([f],[t],0,2)",env)
	}
	return task
end

return Tasks