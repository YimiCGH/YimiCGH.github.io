---------------------------------------------------------------------
-- Yimi_HTNs (C) CompanyName, All Rights Reserved
-- Created by: AuthorName
-- Date: 2019-11-28 07:46:53
---------------------------------------------------------------------

-- To edit this template in: Data/Config/Template.lua
-- To disable this template, check off menuitem: Options-Enable Template File

---@class Test
package.path = package.path .. ";../?.lua"

require "HTN.Core.LocalParser"
local Test = {}

local methods = require 'HTN.Core.Methods'
local worldstates = require 'HTN.Core.WorldStates'
local tasks = require "HTN.Core.Tasks"
local actions = require "HTN.Core.Actions"
local planner = require "HTN.Core.Planner"

--local task = tasks.Transport
--local res = planner:TryGetSolution(worldstates,task)

--

--[[
-- 单个测试
local t = tasks:GetTask("Transport(LocA,LocB)")
--table.print(t)
local m = methods:GetMethods(t.Methodes[1])
--table.print(m)

print(IsHaveRelations(worldstates,m.preconds.relations.positive))

local env = setmetatable(
		{},
		{__index = _G}
	)
for k, v in pairs(worldstates.Objects) do
	print(k,v)
	env[k] = v
end

print(IsValueLimitFit(m.preconds.valuelimits,env))

--]]

-- 一起测试
local t = tasks:GetTask("Transport(LocA,LocB)")
local m = methods:GetMethods(t.Methodes[1])
--table.print(m,"Method")
print(IsFitPreconds(worldstates,m.preconds))

local t1 = tasks:GetTask(m.subtasks[1])
--table.print(t1,"Load Task")
local a1 = actions:GetAction(m.subtasks[1])
local a2 = actions:GetAction(m.subtasks[2])
local a3 = actions:GetAction(m.subtasks[3])

table.print(a3,"Load Action")

table.print(worldstates,"before")
ApplyActionEffects(worldstates,a1)
ApplyActionEffects(worldstates,a2)
ApplyActionEffects(worldstates,a3)

table.print(worldstates,"after")
