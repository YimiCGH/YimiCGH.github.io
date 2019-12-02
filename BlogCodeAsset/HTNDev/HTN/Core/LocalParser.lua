---------------------------------------------------------------------
-- Yimi_HTNs (C) CompanyName, All Rights Reserved
-- Created by: AuthorName
-- Date: 2019-11-29 13:59:20
---------------------------------------------------------------------

-- 字符串解析器
-- 创建一个黑盒，复制全局的变量，并通过_substitutions给一些变量设置别名，如 l1 = LocA
-- 从而可以使用l1来访问LocA中的数据
-- 得到解析器后，通过传入("return l1.p1 > 10") 类似的使用来执行语句
---@class LocalParser
local LocalParser = {}

function NewParser(_chunkname,_env)

	return  function (_script)
		--print(_script)
		--assert(load("print(f,t,m,c)","chunk","bt",env))()
		return assert(load(_script,_chunkname or "Chunk","bt",_env))()
	end
end

return LocalParser