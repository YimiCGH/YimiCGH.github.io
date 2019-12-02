---------------------------------------------------------------------
-- Yimi_HTNs (C) CompanyName, All Rights Reserved
-- Created by: AuthorName
-- Date: 2019-11-29 14:27:48
---------------------------------------------------------------------

-- To edit this template in: Data/Config/Template.lua
-- To disable this template, check off menuitem: Options-Enable Template File

---@class LocalParserTest
-- 引用上级目录
package.path = package.path .. ";..\\?.lua;"
local LocalParserTest = {}

require "LocalParser"
local Test = {}

local methods = require 'Methods'
local worldstates = require 'WorldStates'


local m = methods.Load_2m0c_ab

local parser = NewParser(m.substitues,worldstates.Objects,"解析器测试")
local res = parser.dostring("return ".. m.precond.valueLimit[1])

print(tostring(res))