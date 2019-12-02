---------------------------------------------------------------------
-- Yimi_HTNs (C) CompanyName, All Rights Reserved
-- Created by: AuthorName
-- Date: 2019-12-01 11:30:58
---------------------------------------------------------------------

-- To edit this template in: Data/Config/Template.lua
-- To disable this template, check off menuitem: Options-Enable Template File

---@class ConditionUtility
local SubstituteUtility = {}

function splitFunc(_functionDecl)
	local name, params = string.match( _functionDecl,"(.*)%((.*)%)")
	params = string.gsub(params,"%a+","'%1'")
	params = string.format("return {%s}",params)
	local p = assert(load(params))()
	return name,p
end
function Substitute(_orign ,_env)
	local params = {}
	string.gsub(_orign,"%[(.-)%]",function ( p ) table.insert(params,#params + 1,p) end)
	if #params ~= 0 then
		_orign = string.gsub(_orign,"%[(.-)%]","%%s")
		_orign = string.format("return string.format('%s',%s)",_orign,table.concat(params,","))
		return assert(load(_orign,"Substitute","bt",_env))()
	end
	return _orign
end

return SubstituteUtility