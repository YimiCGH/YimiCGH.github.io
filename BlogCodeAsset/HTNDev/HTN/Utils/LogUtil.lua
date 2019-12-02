---------------------------------------------------------------------
-- Yimi_HTNs (C) CompanyName, All Rights Reserved
-- Created by: AuthorName
-- Date: 2019-11-29 10:24:23
---------------------------------------------------------------------

-- To edit this template in: Data/Config/Template.lua
-- To disable this template, check off menuitem: Options-Enable Template File

---@class LogUtil
local LogUtil = {}

--========================================
-- 格式化print
--========================================
printf = function(_format,...)
	print(string.format(_format,...))
end


--========================================
-- 打印并格式化输出表
--========================================
 table.print = function(t,tableName)
	print((tableName or "unknown").." = "..LogUtil.FormatTable(t))
end

function LogUtil.FormatTable(t, prefix, tableList)
	prefix = prefix or "";
	tableList = tableList or {};

	if tableList[t] then
		return "[ReFormat:"..tostring(t).."]";
	end

	tableList[t] = true;

	local str = "{\n"

	for k, v in pairs(t) do
		str = str..LogUtil.FormatField(k, v, prefix.."\t", tableList).."\n";
	end

	str = str..prefix.."}";

	return str;
end

function LogUtil.FormatField(key, value, prefix, tableList)
	return prefix..LogUtil.FormatKey(key, prefix, tableList) .." = "..LogUtil.FormatValue(value, prefix, tableList)..";";
end

function LogUtil.FormatKey(key, prefix, tableList)
	local keyType = type(key);
	if keyType == "string" then
		return key;
	elseif keyType == "number" then
		return "["..key.."]";
	end

	return "["..tostring(key).."]";
end

function LogUtil.FormatValue(value, prefix, tableList)
	local valueType = type(value);
	if valueType == "string" then
		return "\""..value.."\"";
	elseif valueType == "number" or valueType == "boolean" then
		return tostring(value)
	elseif valueType == "table" then
		return LogUtil.FormatTable(value, prefix, tableList);
	end

	return "["..tostring(value).."]";
end

return LogUtil