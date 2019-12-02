---------------------------------------------------------------------
-- Yimi_HTNs (C) CompanyName, All Rights Reserved
-- Created by: AuthorName
-- Date: 2019-11-28 08:40:32
---------------------------------------------------------------------

-- To edit this template in: Data/Config/Template.lua
-- To disable this template, check off menuitem: Options-Enable Template File

---@class TableUtil
local TableUtil = {}


--======
-- 当table是列表时，可以用来拼接多个列表
--======
table.combine = function(...)
	local res = {}
	for i, t in ipairs({...}) do
		for i = 1, #t do
			table.insert(res,t[i])
		end
	end
	return res
end

--=====================
-- 深拷贝
--=====================
table.deepcopy = function(_target)
	local lookup_table = {}

	local function _copy(_target)
		if type(_target) ~= "table" then
			return _target
		elseif lookup_table[_target] then
			return lookup_table[_target]
		else
			local new_table = {}
			lookup_table[_target] = new_table
			for k, v in pairs(_target) do
				new_table[_copy(k)] = _copy(v)
			end
			return setmetatable(new_table,getmetatable(_target))
		end

	end
	return _copy(_target)
end
--=====================
-- sub sequence
--=====================
table.sublist = function(_list,_start,_end)
	return {unpack(_list, _start, _end)}
end



return TableUtil