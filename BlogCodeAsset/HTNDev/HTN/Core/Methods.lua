---------------------------------------------------------------------
-- Yimi_HTNs (C) CompanyName, All Rights Reserved
-- Created by: AuthorName
-- Date: 2019-11-28 05:27:32
---------------------------------------------------------------------

-- 方法定义

---@class Methods
require "HTN.Utils.SubstituteUtility"

local Methods = {}

function Methods:GetMethods ( _methoddecl )
	local name, p = splitFunc( _methoddecl)
	return self[name](table.unpack(p))
end


Methods.Load_2m0c =function(...)
	local input = {...}
	local env = setmetatable(
		{
			f = input[1],
			t = input[2],
			m = input[3],
			c = input[4]
		},
		{__index = _G}
	)
	local method = {}
	method.preconds = {
		relations = {
			positive = {Substitute("BoatAt([f])",env)}
		},
		valuelimits = {
			Substitute("[f].missionaryNum >= [m]",env),
			Substitute("[f].missionaryNum - [m] >= [f].cannibalNum",env)
		}
	}
	method.subtasks = {
		Substitute("Load([f],[m],[c])",env),
		Substitute("Move([f],[t])",env),
		Substitute("UnLoad([t],[m],[c])",env),
		Substitute("Transport([t],[f])",env)
	}
	return method	
end

return Methods