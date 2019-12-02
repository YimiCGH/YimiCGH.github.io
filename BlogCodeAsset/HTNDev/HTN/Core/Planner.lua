---------------------------------------------------------------------
-- Yimi_HTNs (C) CompanyName, All Rights Reserved
-- Created by: AuthorName
-- Date: 2019-11-28 05:34:15
---------------------------------------------------------------------

-- To edit this template in: Data/Config/Template.lua
-- To disable this template, check off menuitem: Options-Enable Template File

---@class Planner

require "HTN.Utils.TableUtil"
require "HTN.Utils.LogUtil"
require "HTN.Core.LocalParser"

local Planner = {}

--==========================
-- 传入当前世界状态_initstates,任务_task,操作集_operates
-- 操作集_operates 提供行为的原型
--==========================

function Planner:TryGetSolution(_initstates,_task)
	Planner.WS = table.deepcopy(_initstates)
	Planner.Tasks = require "Tasks"
	Planner.Actions = require "Actions"
	local t = Planner.Tasks:GetTask(_task)
	
	local env = setmetatable(
		{},
		{__index = _G}
	)
	for k, v in pairs(Planner.WS) do
		env[k] = v
	end
	Planner.ENV = env
	
	--self:TFD(Planner.WS,{t})
end

--==========================
--Total-Order Forward Decomposition
--==========================
function Planner:TFD(_ws,_opentasks)
	if #_opentasks == 0 then return {} end
	local ws = table.deepcopy(_ws)
	local t1 = _opentasks[1]
	if t1.IsPrimitive then	
		if IsFitPreconds(ws,t1.preconds) then	
			local a = self.Actions:GetAction(t1)			
			local plan = self:TFD(ws,table.sublist(_opentasks,2,#_opentasks))
			if plan == nil then
				return nil
			else
				table.insert(plan,1,a)
				return plan
			end			
		end
	else
		local methods = t1.Methods
		if methods == nil then return nil end
		
		for _, m in ipairs(methods) do
			if self:IsHaveRelations(m.preconds,m.substitutions) then
				--获取实例化子任务
				local subtasks = {}
				for _, v in ipairs(m.subtasks) do
					table.insert(subtasks,#subtasks+1, self.Tasks:GetTask(v))
				end
				
				return self:TFD(ws,table.combine(subtasks, table.sublist(_opentasks,2,#_opentasks)))
			end
		end
	end
end

--==========================
-- 判断条件是否符合
--==========================
function IsFitPreconds(_ws,_preconds)
	return 
	IsHaveRelations(_ws,_preconds.relations.positive) and
		IsNotHaveRelation(_ws,_preconds.relations.negative) and
		IsValueLimitFit(_ws,_preconds.valuelimits)
end

function IsHaveRelations(_ws,_statements)
	if(_statements ~= nil) then
		for _, v in pairs(_statements) do
			if not(IsHaveRelation(_ws,v)) then
				return false
			end
		end
	end
	return true
end

function IsNotHaveRelation(_ws,_statements)
	if(_statements ~= nil) then
		for _, v in pairs(_statements) do
			if IsHaveRelation(_ws,v) then
				return false
			end
		end
	end
	return true
end

function IsHaveRelation(_ws,_statement)	
	print(_statement)
	local predicate, params = string.match( _statement,"(.*)%((.*)%)")
	
	local relations = _ws.Relations[predicate]

	if relations ~= nil then
		for _,v in pairs(relations) do			
			if v == params then
				return true
			end
		end
	end
	return false
end

function IsValueLimitFit(_ws,_statements)	
	local env = setmetatable(
		{},
		{__index = _G}
	)
	for k, v in pairs(_ws.Objects) do
		env[k] = v
	end
	
	if _statements ~= nil then
		local parser = NewParser("数值条件判断",env)
		for i, v in ipairs(_statements) do
			print(v)
			if not parser("return ".. v) then
				return false
			end
		end
	end
	return true
end

--==========================
-- Apply Action Effect To Planing WorldStates
--==========================

function ApplyActionEffects(_ws,_action)
	local env = setmetatable(
		{},
		{__index = _G}
	)
	for k, v in pairs(_ws.Objects) do
		env[k] = v
	end
	local parser = NewParser("应用行动效果",env)
	-- positive
	if _action.Effects.positive ~= nil then
		for _, v in ipairs(_action.Effects.positive) do
			AddRelation(_ws,v)
		end
	end
	
	-- negative
	if _action.Effects.negative ~= nil then
		for _, v in ipairs(_action.Effects.negative) do
			RemoveRelation(_ws,v)
		end
	end
	-- preoperties
	if _action.Effects.preoperties ~= nil then
		for _, v in ipairs(_action.Effects.preoperties) do
			parser(v)
		end
	end
end

function AddRelation(_ws,_statement)
	printf("AddRelation :%s",_statement)
	local predicate, params = string.match( _statement,"(.*)%((.*)%)")
	
	local relations = _ws.Relations[predicate]
	if relations ~= nil then
		for _, v in ipairs(relations) do
			if v == params then
				return 
			end
		end
		table.insert(relations,params)
	else
		-- 新增关系
		_ws.Relations[predicate] = {params}
	end
end
function RemoveRelation(_ws,_statement)
	--注意考虑移除元素后产生的空洞会不会对其他系统造成影响
	printf("RemoveRelation :%s",_statement)
	local predicate, params = string.match( _statement,"(.*)%((.*)%)")

	local relations = _ws.Relations[predicate]
	if relations ~= nil then
		local index = 0
		for i, v in ipairs(relations) do
			if v == params then
				index = i
			end
		end
		if index ~= 0 then
			table.remove(relations,index)
			if #relations == 0 then
				_ws.Relations[predicate] = nil
			end
		end
	end
end

return Planner