---------------------------------------------------------------------
-- Yimi_HTNs (C) CompanyName, All Rights Reserved
-- Created by: AuthorName
-- Date: 2019-11-28 05:29:32
---------------------------------------------------------------------

-- 世界状态

---@class WorldStates
local WorldStates = {}

WorldStates.Objects = {
	LocA = {
		type = 'Location',
		position = {x = 10,y = 0,z = 0},
		missionaryNum = 3,
		cannibalNum = 3
	},
	LocB = {
		type = 'Location',
		position = {x = -10,y = 0,z = 0},
		missionaryNum = 0,
		cannibalNum = 0
	}
}
WorldStates.Relations = {
	BoatAt = {
		"LocA"
	}
}



return WorldStates