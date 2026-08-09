
local function place(tb)
    -- Translate map data into a 2d boolean array
    local oldMapData = tb.MapData
    local newMapData = {}
	for x = 1, 16 do
		newMapData[x] = {}
	end
    for y = 1, 12 do
        local oldRow = oldMapData[y]
        for step = 0, 3 do
            for offset = 1, 4 do
                local char = oldRow:sub(step*5 + offset, step*5 + offset)
                newMapData[step*4 + offset][y] = (char == '#')
            end
        end
    end
    tb.MapData = newMapData

	-- Convert upload zones to coord structs
	local newUploads = {}
	for _, uploadZone in pairs(tb.UploadZones) do
		table.insert(newUploads, {x = uploadZone[1], y = uploadZone[2]})
	end
	tb.UploadZones = newUploads
	
	-- Convert credit locations into coord structs
	local newCredits = {}
	for _, credit in pairs(tb.ExtraCreditList) do
		table.insert(newCredits, {x = credit[1], y = credit[2]})
	end
	tb.ExtraCreditList = newCredits
	
	-- Convert the codes location to coord structs	
	local newCodes = {}
	for _, codes in pairs(tb.CodeList) do
		table.insert(newCodes, {x = codes[1], y = codes[2]})
	end
	tb.CodeList = newCodes
	
	-- Convert tail to coord structs
	for _, unitEntry in pairs(tb.ProgramList) do
		-- By default units are enemies
		if not unitEntry.Type then 
			unitEntry.Type = 'enemy'
		end
		local newTail = {}
		for _, p in pairs(unitEntry.Tail) do
			table.insert(newTail, {x = p[1], y = p[2]})
		end
		unitEntry.Tail = newTail
	end
	
	-- Convert backgrounds
	if tb.Background == 'automa' then
		tb.Background = 'rbxassetid://1324011891'
	elseif tb.Background == 'monkey' then
		tb.Background = 'rbxassetid://1324011897'
	elseif tb.Background == 'pharmhaus' then
		tb.Background = 'rbxassetid://1324011896'
	elseif tb.Background == 'ped' then
		tb.Background = 'rbxassetid://1324011899'
	elseif tb.Background == 'donut' then
		tb.Background = 'rbxassetid://1324011898'
	elseif tb.Background == 'disarray' then
		tb.Background = 'rbxassetid://1346640173'
	else
		error("Bad background: "..tb.Background, 2)
	end

    return tb
end

local function places(tb)
    local lookup = {}
    for k, v in pairs(tb) do
        lookup[v.Id] = v
    end
	lookup.PlaceWidth = 16
	lookup.PlaceHeight = 12
    return lookup
end

return places{
    place{
        Id = 'tutorial';
		Background = 'disarray';
        CreditReward = 1000;
        MapData = {        
            '#### #### ##-- ----';
            '#### #### ##-- ----';
            '#### #### ##-- ----';
            '#### #### ##-- ----';
            '#### #### ##-- ----';
            '#### #### ##-- ----';
            '#### #### ##-- ----';
            '#### #### ##-- ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
        };
        UploadZones = {{3, 3}, {4, 5}};
        ExtraCreditList = {};
		CodeList = {};
        ProgramList = {
            {Id = 'sentinel'; Tail = {{7, 3}, {7, 4}, {7, 5}}};
        };
    };

    place{
        Id = 'L11';
		Background = 'pharmhaus';
        CreditReward = 1000;
        MapData = {        
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---- ---- -### #---';
            '-### #-## #### #---';
            '-### #-## -### #---';
            '-### #-## ---- ----';
            '--## -### #-## #---';
            '--## #### #### #---';
            '--## #### #### #---';
            '---- -### #-## #---';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
        };
        UploadZones = {{7, 9}, {8, 8}};
        ExtraCreditList = {{4, 5}, {11, 4}, {12, 8}};
		CodeList = {};
        ProgramList = {
            {Id = 'sentinel'; Tail = {{12, 9}}};
            {Id = 'pup'; Tail = {{12, 4}}};
            {Id = 'watchman'; Tail = {{3, 5}}};
        };
    };

    place{
        Id = 'L12';
		Background = 'monkey';
        CreditReward = 1000;
        MapData = {        
            '---- ---- ---- ----';
            '---# ###- -### #---';
            '--## #### #### ##--';
            '---# #### #### #---';
            '---- #### #### ----';
            '---- -##- -##- ----';
            '---- #### #### ----';
            '---# #### #### #---';
            '--## #### #### ##--';
            '---# ###- -### #---';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
        };
        UploadZones = {{7, 10}, {10, 10}};
        ExtraCreditList = {};
		CodeList = {};
        ProgramList = {
            {Id = 'sentinel'; Tail = {{6, 3}}};
            {Id = 'sentinel'; Tail = {{11, 3}}};
        };
    };

    place{
        Id = 'L13';
		Background = 'automa';
        CreditReward = 1000;
        MapData = {        
            '---- ---- ---# #---';
            '---- #--- -### ##--';
            '---# #### #### ##--';
            '--## #### #### #---';
            '--## #### #### #---';
            '--## #### #### #---';
            '--## #### #### #---';
            '---# #### #### #---';
            '---# #### #### #---';
            '---- --## #--- ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
        };
        UploadZones = {{5, 7}, {5, 8}, {6, 7}, {6, 8}};
        ExtraCreditList = {};
		CodeList = {};
        ProgramList = {
            {Id = 'watchman'; Tail = {{12, 2}}};
            {Id = 'watchman'; Tail = {{13, 3}}};
            {Id = 'sentinel'; Tail = {{12, 4}}};
            {Id = 'pup'; Tail = {{10, 3}}};
            {Id = 'pup'; Tail = {{13, 5}}};
        };
    };

    place{
        Id = 'L14';
		Background = 'automa';
        CreditReward = 1000;
        MapData = {        
            '---- ---- ---- ----';
            '--## #### #--- ----';
            '--## #### #--- #---';
            '--## #### #--# ##--';
            '--## #### #--# ##--';
            '--## #### #--# ##--';
            '--## #### #--# ##--';
            '--## #### #--# ##--';
            '--## #### #--- #---';
            '--## #### #--- ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
        };
        UploadZones = {{5, 5}, {5, 7}};
        ExtraCreditList = {{13, 3}, {13, 9}};
		CodeList = {{13, 6}};
        ProgramList = {
            {Id = 'bitman'; Type = 'friendly'; Tail = {{3, 6}}};
            {Id = 'sentinel'; Tail = {{9, 5}}};
            {Id = 'sentinel'; Tail = {{9, 7}}};
            {Id = 'sentinel'; Tail = {{12, 6}}};
        };
    };

    place{
        Id = 'L15';
		Background = 'pharmhaus';
        CreditReward = 1000;
        MapData = {        
            '--## #--- ---# ##--';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '--## #--- ---# ##--';
            '---- ---- ---- ----';
        };
        UploadZones = {{8, 5}, {9, 5}, {8, 7}, {9, 7}};
        ExtraCreditList = {{4, 6}};
		CodeList = {};
        ProgramList = {
            {Id = 'pup'; Tail = {{2, 3}}};
            {Id = 'pup'; Tail = {{4, 1}}};
            {Id = 'pup'; Tail = {{2, 9}}};
            {Id = 'pup'; Tail = {{4, 11}}};
            {Id = 'pup'; Tail = {{15, 3}}};
            {Id = 'pup'; Tail = {{15, 9}}};
            {Id = 'pup'; Tail = {{13, 1}}};
            {Id = 'pup'; Tail = {{13, 11}}};
        };
    };

    place{
        Id = 'L16';
		Background = 'pharmhaus';
        CreditReward = 1000;
        MapData = {        
            '---- ---# #### ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---- #### #--- ----';
            '---- ---- ---- ----';
        };
        UploadZones = {{2, 5}, {2, 7}, {4, 6}};
        ExtraCreditList = {{8, 1}, {9, 1}, {11, 1}, {12, 1}, {5, 11}, {6, 11}, {8, 11}, {9, 11}};
		CodeList = {};
        ProgramList = {
            {Id = 'pup'; Tail = {{15, 5}}};
            {Id = 'pup'; Tail = {{15, 7}}};
            {Id = 'watchman'; Tail = {{14, 6}}};
        };
    };

    place{
        Id = 'L21';
		Background = 'monkey';
        CreditReward = 1000;
        MapData = {        
            '--## #--- ---# ##--';
            '-### ##-- --## ###-';
            '-### ##-- --## ###-';
            '-### ##-- ---# ###-';
            '-### ##-- #### ###-';
            '-### #### #### ###-';
            '-### #### --## ###-';
            '-### #--- --## ###-';
            '-### ##-- --## ###-';
            '-### ##-- --## ###-';
            '--## #--- ---# ##--';
            '---- ---- ---- ----';
        };
        UploadZones = {{13, 2}, {14, 2}, {13, 10}, {14, 10}};
        ExtraCreditList = {{3, 6}, {3, 9}};
		CodeList = {{3, 3}};
        ProgramList = {
            {Id = 'guarddog'; Tail = {{5, 2}}};
            {Id = 'guarddog'; Tail = {{4, 3}}};
            {Id = 'guarddog'; Tail = {{2, 4}}};
            {Id = 'guarddog'; Tail = {{3, 5}}};
            {Id = 'guarddog'; Tail = {{4, 6}}};
            {Id = 'guarddog'; Tail = {{3, 8}}};
            {Id = 'guarddog'; Tail = {{5, 10}}};
        };
    };

    place{
        Id = 'L22';
		Background = 'monkey';
        CreditReward = 1000;
        MapData = {        
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---- ##-- ###- ----';
            '---- #### #### ----';
            '---- #### #### ----';
            '---- #### #### ----';
            '---- -### --## ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
        };
        UploadZones = {{9, 5}, {11, 5}, {11, 7}, {12, 9}};
        ExtraCreditList = {};
		CodeList = {};
        ProgramList = {
            {Id = 'sentinel2'; Tail = {{6, 7}, {6, 6}, {5, 6}, {5, 5}}};
            {Id = 'sentinel2'; Tail = {{8, 7}, {8, 6}, {7, 6}}};
            {Id = 'sentinel2'; Tail = {{7, 8}, {6, 8}, {5, 8}, {5, 7}}};
            {Id = 'sentinel2'; Tail = {{8, 9}, {7, 9}, {6, 9}}};
        };
    };

    place{
        Id = 'L23';
		Background = 'automa';
        CreditReward = 1000;
        MapData = {        
            '---# #### #### #---';
            '--## #### #### ##--';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '--## #### #### ##--';
            '---# #### #### #---';
            '---- ---- ---- ----';
        };
        UploadZones = {{8, 6}, {9, 6}};
        ExtraCreditList = {{4, 6}, {13, 6}};
		CodeList = {};
        ProgramList = {
            {Id = 'watchmanx'; Tail = {{5, 3}, {4, 3}}};
            {Id = 'watchmanx'; Tail = {{5, 9}, {4, 9}}};
            {Id = 'watchmanx'; Tail = {{12, 3}, {13, 3}}};
            {Id = 'watchmanx'; Tail = {{12, 9}, {13, 9}}};
        };
    };

    place{
        Id = 'L24';
		Background = 'automa';
        CreditReward = 1000;
        MapData = {        
            '--## ##-- ---- ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ##--';
            '-### #### #### #---';
            '---# #### #### ###-';
            '---# #### #### ###-';
            '--## #### #### ###-';
            '--## #### #### ###-';
            '---- -### #### -##-';
            '---- ---- ---- ----';
        };
        UploadZones = {{7, 10}, {12, 10}, {15, 10}, {14, 8}, {14, 3}};
        ExtraCreditList = {{3, 10}, {3, 9}};
		CodeList = {};
        ProgramList = {
            {Id = 'watchman'; Tail = {{3, 4}}};
            {Id = 'watchman'; Tail = {{5, 2}}};
            {Id = 'watchmanx'; Tail = {{3, 2}}};
            {Id = 'warden'; Tail = {{5, 4}}};
            {Id = 'guarddog'; Tail = {{4, 6}}};
            {Id = 'guarddog'; Tail = {{7, 3}}};
        };
    };

    place{
        Id = 'L25';
		Background = 'donut';
        CreditReward = 1000;
        MapData = {        
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {{3, 1}, {2, 2}, {15, 1}, {15, 10}, {14, 11}, {2, 11}};
        ExtraCreditList = {};
		CodeList = {};
        ProgramList = {
            {Id = 'sentinel'; Tail = {{6, 3}, {6, 4}}};
            {Id = 'sentinel'; Tail = {{4, 6}, {5, 6}}};
            {Id = 'sentinel'; Tail = {{10, 2}, {9, 2}}};
            {Id = 'sentinel'; Tail = {{12, 4}, {12, 5}}};
            {Id = 'sentinel'; Tail = {{13, 7}, {12, 7}}};
            {Id = 'sentinel'; Tail = {{11, 9}, {11, 8}}};
            {Id = 'sentinel'; Tail = {{7, 10}, {8, 10}}};
            {Id = 'sentinel'; Tail = {{5, 8}, {5, 7}}};
            {Id = 'sentinel2'; Tail = {{10, 7}, {9, 7}, {9, 6}}};
            {Id = 'sentinel2'; Tail = {{7, 5}, {7, 6}, {8, 6}}};
        };
    };

    place{
        Id = 'L26';
		Background = 'monkey';
        CreditReward = 1000;
        MapData = {        
            '---- ---- ---- ----';
            '--## #### #### ##--';
            '--#- #### #-## ##--';
            '--## -### -### #---';
            '--## #-## #### ##--';
            '--## ##-# #-## ##--';
            '--#- #### -### #---';
            '---# ###- ##-# ##--';
            '--## #-## ###- ##--';
            '--## ##-# #### -#--';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
        };
        UploadZones = {{4, 9}, {5, 9}};
        ExtraCreditList = {{4, 2}, {6, 10}, {12, 10}, {14, 5}};
		CodeList = {};
        ProgramList = {
            {Id = 'warden'; Tail = {{4, 4}, {3, 4}, {3, 3}, {3, 2}}};
			{Id = 'warden'; Tail = {{6, 2}, {7, 2}, {8, 2}}};
			{Id = 'warden'; Tail = {{10, 9}, {10, 10}, {11, 10}}};
			{Id = 'warden'; Tail = {{12, 5}, {12, 4}, {12, 3}, {13, 3}}};
        };
    };

    place{
        Id = 'L27';
		Background = 'monkey';
        CreditReward = 1000;
        MapData = {        
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '--## #### #### ###-';
            '---# #### #### ###-';
            '---# #### #### ###-';
            '--## #### #### ###-';
            '-### #### #### ###-';
            '-### #--- #### ###-';
            '-### ---- -### ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {{15, 1}, {15, 5}, {14, 4}, {14, 6}, {13, 2}, {12, 4}, {11, 2}, {10, 3}, {9, 1}, {8, 2}};
        ExtraCreditList = {};
		CodeList = {{3, 10}};
        ProgramList = {
            {Id = 'pup'; Tail = {{2,2}}};
            {Id = 'pup'; Tail = {{4,2}}};
            {Id = 'sentinel'; Tail = {{3,3}}};
            {Id = 'sentinel'; Tail = {{5,4}}};
            {Id = 'watchman'; Tail = {{4,5}}};
            {Id = 'pup'; Tail = {{5,6}}};
            {Id = 'sentinel'; Tail = {{5,7}}};
            {Id = 'sentinel'; Tail = {{7,7}}};
            {Id = 'watchman'; Tail = {{4,8}}};
            {Id = 'sentinel'; Tail = {{6,8}}};
            {Id = 'pup'; Tail = {{8,8}}};
            {Id = 'sentinel'; Tail = {{11,8}}};
            {Id = 'pup'; Tail = {{2,9}}};
            {Id = 'watchman'; Tail = {{10,9}}};
            {Id = 'sentinel'; Tail = {{12,9}}};
            {Id = 'pup'; Tail = {{4,10}}};
            {Id = 'watchman'; Tail = {{5,10}}};
            {Id = 'pup'; Tail = {{13,10}}};
            {Id = 'pup'; Tail = {{15,10}}};
            {Id = 'pup'; Tail = {{2,11}}};
            {Id = 'pup'; Tail = {{11,11}}};
        };
    };

    place{
        Id = 'L28';
		Background = 'donut';
        CreditReward = 1000;
        MapData = {        
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {{14,2}, {14, 4}, {13,6}, {14,8}, {14,10}};
        ExtraCreditList = {};
		CodeList = {};
        ProgramList = {
            {Id = 'sentinel'; Tail = {{6, 3}, {6, 2}}};
            {Id = 'sentinel'; Tail = {{7, 6}, {7, 5}, {6, 5}}};
            {Id = 'sentinel'; Tail = {{6, 9}, {5, 9}, {4, 9}}};
            {Id = 'sentinel'; Tail = {{4, 6}, {3, 6}, {3, 7}}};
            {Id = 'warden'; Tail = {{5, 3}, {4, 3}, {4, 2}, {3, 2}}};
            {Id = 'warden'; Tail = {{5, 5}, {4, 5}, {3, 5}, {3, 4}}};
            {Id = 'warden'; Tail = {{5, 7}, {4, 7}, {4, 8}, {3, 8}}};
        };
    };

    place{
        Id = 'L29';
		Background = 'pharmhaus';
        CreditReward = 1000;
        MapData = {        
            '---- ---- ---- ###-';
            '--## ##-- -### ###-';
            '--#- -#-- -#-- ###-';
            '--#- -#-- -#-- ----';
            '--#- -#-- -#-- ----';
            '--#- -##- -##- ----';
            '--#- --#- --#- ###-';
            '--#- --#- --#- ###-';
            '-### --#- --#- ###-';
            '-### --## ###- ###-';
            '-### ---- ---- ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {{2, 9}, {4, 11}};
        ExtraCreditList = {
			{3, 5}, {8, 10}, {10, 3},
			{14, 7}, {14, 8}, {14, 9}, {14, 10}, {14, 11},
			{15, 7}, {15, 8}, {15, 9}, {15, 10}, {15, 11},
		};
		CodeList = {{15, 1}};
        ProgramList = {
            {Id = 'wardenpp'; Tail = {{13, 7}}};
            {Id = 'sensor'; Tail = {{3, 2}}};
            {Id = 'sensor'; Tail = {{6, 2}}};
            {Id = 'sensor'; Tail = {{7, 6}}};
            {Id = 'sensor'; Tail = {{10, 6}}};
            {Id = 'sensor'; Tail = {{14, 2}}};
        };
    };

    place{
        Id = 'L31';
		Background = 'donut';
        CreditReward = 1000;
        MapData = {        
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '---- ---- ---- ----';
        };
        UploadZones = {{3,3}, {4,4}, {5,1}, {6,2}};
        ExtraCreditList = {};
		CodeList = {};
        ProgramList = {
            {Id = 'watchmansp'; Tail = {{4,10}, {4,11}, {4,11}}};
            {Id = 'watchmansp'; Tail = {{5,10}, {5,11}}};
            {Id = 'watchmansp'; Tail = {{6,11}}};
            {Id = 'watchmansp'; Tail = {{13,2}, {14,2}, {14,1}}};
            {Id = 'watchmansp'; Tail = {{13,3}, {14,3}}};
            {Id = 'watchmansp'; Tail = {{14,4}}};
            {Id = 'watchmansp'; Tail = {{14,8}, {14,9}}};
            {Id = 'watchmansp'; Tail = {{13,10}, {14,10}, {14,11}}};
            {Id = 'watchmansp'; Tail = {{12,11}, {13,11}}};
        };
    };

    place{
        Id = 'L32';
		Background = 'ped';
        CreditReward = 1000;
        MapData = {        
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---# #### #### ----';
            '---# #### #### ----';
            '---# #### #### ----';
            '---# #### #### ----';
            '---# #### #### ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
        };
        UploadZones = {{8,7}};
        ExtraCreditList = {};
		CodeList = {};
        ProgramList = {
            {Id = 'sentinel2'; Tail = {{5,5}, {5,6}, {4,6}, {4,5}}};
            {Id = 'sentinel2'; Tail = {{5,9}, {5,8}, {4,8}, {4,9}}};
            {Id = 'sentinel2'; Tail = {{11,5}, {11,6}, {12,6}, {12,5}}};
            {Id = 'sentinel2'; Tail = {{11,9}, {11,8}, {12,8}, {12,9}}};
        };
    };

    place{
        Id = 'L33';
		Background = 'monkey';
        CreditReward = 1000;
        MapData = {        
            '---- ---- ---- ----';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '--## #### #### ##--';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
        };
        UploadZones = {{4,3}, {13,9}};
        ExtraCreditList = {};
		CodeList = {};
        ProgramList = {
            {Id = 'firewall'; Tail = {
				{10,5}, {9,5}, {8,5}, {7,5},
				{7,6}, {8,6}, {9,6}, {10,6},
				{10,7}, {9,7}, {8,7}, {7,7},
			}};
            {Id = 'attackdog'; Tail = {{4,9}}};
            {Id = 'attackdog'; Tail = {{13,3}}};
        };
    };

    place{
        Id = 'L34';
		Background = 'ped';
        CreditReward = 1000;
        MapData = {        
            '-### ##-- ##-- ----';
            '-### ###- #### -#--';
            '-### ###- #### ###-';
            '-### ###- #### ###-';
            '--## #### #### ###-';
            '-### #### #### ###-';
            '---- ##-- #### ##--';
            '--## #### #### ###-';
            '--## #### #### ###-';
            '-### #### #### ###-';
            '--## -### #### #---';
            '---- ---- ---- ----';
        };
        UploadZones = {{2,4}, {3,2}, {6,1}};
        ExtraCreditList = {{13,9}, {13,10}, {12,10}};
		CodeList = {};
        ProgramList = {
            {Id = 'watchman'; Tail = {{11,3}}};
            {Id = 'watchman'; Tail = {{11,6}}};
            {Id = 'watchman'; Tail = {{8,9}}};
            {Id = 'watchman'; Tail = {{6,10}}};
            {Id = 'sensor'; Tail = {{5,8}}};
            {Id = 'sensor'; Tail = {{9,5}}};
            {Id = 'sensor'; Tail = {{9,10}}};
            {Id = 'sensor'; Tail = {{12,9}}};
        };
    };

    place{
        Id = 'L35';
		Background = 'pharmhaus';
        CreditReward = 1000;
        MapData = {        
            '-### ##-- --## ###-';
            '-### ##-- --## ###-';
            '-### ##-- --## ###-';
            '-### ##-- --## ###-';
            '-### ##-- --## ###-';
            '-### ##-- --## ###-';
            '-### ##-- --## ###-';
            '-### ##-- --## ###-';
            '-### ##-- --## ###-';
            '-### ##-- --## ###-';
            '-### ##-- --## ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {{3,10}, {5,10}, {12,2}, {14,2}};
        ExtraCreditList = {{3,2}, {5,2}, {13,10}};
		CodeList = {};
        ProgramList = {
            {Id = 'sentinel3'; Tail = {{2,3}, {2,2}, {2,1}}};
            {Id = 'sentinel3'; Tail = {{4,3}, {4,2}, {4,1}}};
            {Id = 'sentinel3'; Tail = {{6,3}, {6,2}, {6,1}}};
            {Id = 'wardenp'; Tail = {{12,9}, {12,10}, {12,11}, {11,11}, {11,10}}};
            {Id = 'wardenp'; Tail = {{14,9}, {14,10}, {14,11}, {15,11}, {15,10}}};
        };
    };

    place{
        Id = 'L36';
		Background = 'pharmhaus';
        CreditReward = 1000;
        MapData = {        
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '---- ---- ---- -##-';
            '---- ---- ---- -##-';
            '---- ---- ---- -##-';
            '--## #--- ---- -##-';
            '--## #### #### ###-';
            '--## #### #### ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {{3,11}, {3,10}, {3,9}};
        ExtraCreditList = {{7,3}, {8,3}, {9,3}, {10,3}, {11,3}};
		CodeList = {{3,3}};
        ProgramList = {
            {Id = 'sonar'; Tail = {{2,3}}};
            {Id = 'sensor'; Tail = {{7,2}}};
            {Id = 'sensor'; Tail = {{8,2}}};
            {Id = 'sensor'; Tail = {{9,2}}};
            {Id = 'sensor'; Tail = {{10,2}}};
            {Id = 'sensor'; Tail = {{11,2}}};
            {Id = 'sensor'; Tail = {{7,4}}};
            {Id = 'sensor'; Tail = {{8,4}}};
            {Id = 'sensor'; Tail = {{9,4}}};
            {Id = 'sensor'; Tail = {{10,4}}};
            {Id = 'sensor'; Tail = {{11,4}}};
        };
    };

    place{
        Id = 'L37';
		Background = 'donut';
        CreditReward = 1000;
        MapData = {        
            '---# -#-# ##-# -#--';
            '--## #### #### ###-';
            '---# #### #### ##--';
            '--## #### #### ###-';
            '---# #### #### ##--';
            '--## #### #### ###-';
            '---# #### #### ##--';
            '--## #### #### ###-';
            '---# #### #### ##--';
            '--## #### #### ###-';
            '---# -#-# ##-# -#--';
            '---- ---- ---- ----';
        };
        UploadZones = {{9,10}};
        ExtraCreditList = {{3,2},{3,6},{3,10},{15,2},{15,6},{15,10}};
		CodeList = {{9,2}};
        ProgramList = {
            {Id = 'sentinel2'; Tail = {{5,3}}};
            {Id = 'sentinel2'; Tail = {{5,6}}};
            {Id = 'sentinel2'; Tail = {{5,9}}};
            {Id = 'sentinel2'; Tail = {{13,3}}};
            {Id = 'sentinel2'; Tail = {{13,6}}};
            {Id = 'sentinel2'; Tail = {{13,9}}};
        };
    };

	-- OMG this level. Plz, buy some level skips here
    place{
        Id = 'L38';
		Background = 'donut';
        CreditReward = 1000;
        MapData = {        
            '---# #### #### #---';
            '--## #### #### ##--';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '--## #### #### ##--';
            '---# #### #### #---';
            '---- ---- ---- ----';
        };
        UploadZones = {{5,1},{6,1},{7,1},{10,1},{11,1},{12,1}};
        ExtraCreditList = {};
		CodeList = {};
        ProgramList = {
            {Id = 'attackdog'; Tail = {{4,11}}};
            {Id = 'attackdog'; Tail = {{5,11}}};
            {Id = 'attackdog'; Tail = {{12,11}}};
            {Id = 'attackdog'; Tail = {{13,11}}};
            {Id = 'sentinel3'; Tail = {{3,10}}};
            {Id = 'sentinel3'; Tail = {{6,10}}};
            {Id = 'sentinel3'; Tail = {{11,10}}};
            {Id = 'sentinel3'; Tail = {{14,10}}};
            {Id = 'watchmansp'; Tail = {{4,10}}};
            {Id = 'watchmansp'; Tail = {{5,10}}};
            {Id = 'watchmansp'; Tail = {{12,10}}};
            {Id = 'watchmansp'; Tail = {{13,10}}};
        };
    };

    place{
        Id = 'L39';
		Background = 'monkey';
        CreditReward = 1000;
        MapData = {        
            '---- ---- ---- ----';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {{5,2}, {12,2}};
        ExtraCreditList = {{3,11}, {14,11}};
		CodeList = {{8,10}};
        ProgramList = {
            {Id = 'firewall'; Tail = {
				{7,5},{8,5},{9,5},{10,5},{11,5},{12,5},{13,5},
				{13,6},{12,6},{11,6},{10,6},{9,6},{8,6},{7,6},{6,6},{5,6},{4,6},
				{4,5},{5,5},{6,5}
			}};
            {Id = 'firewall'; Tail = {
				{2,7},{2,8},{2,9},{2,10},{3,10},{3,9},{3,8},{4,8},{4,9},{4,10}
			}};
            {Id = 'firewall'; Tail = {
				{15,7},{15,8},{15,9},{15,10},
				{14,10},{14,9},{14,8},
				{13,8},{13,9},{13,10},
				{12,10},{12,9},{12,8}
			}};
            {Id = 'firewall'; Tail = {
				{9,9},{9,10},{9,11},{8,11},{7,11},{7,10},{7,9},{8,9}
			}};
			{Id = 'sonar'; Tail = {{4,11}}};
			{Id = 'sonar'; Tail = {{13,11}}};
        };
    };

    place{
        Id = 'L41';
		Background = 'monkey';
        CreditReward = 1000;
        MapData = {        
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---# #### #### #---';
            '---# #### #### #---';
            '---# #### #### #---';
            '---# #### #### #---';
            '---# #### #### #---';
            '---# #### #### #---';
            '---# #### #### #---';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
        };
        UploadZones = {{4,3}, {13,9}};
        ExtraCreditList = {{4,9}, {13,3}};
		CodeList = {};
        ProgramList = {
            {Id = 'sumo'; Tail = {{7,5}}};
            {Id = 'sumo'; Tail = {{8,5}}};
            {Id = 'sumo'; Tail = {{9,5}}};
            {Id = 'sumo'; Tail = {{10,5}}};
            {Id = 'sumo'; Tail = {{7,6}}};
            {Id = 'sumo'; Tail = {{8,6}}};
            {Id = 'sumo'; Tail = {{9,6}}};
            {Id = 'sumo'; Tail = {{10,6}}};
            {Id = 'sumo'; Tail = {{7,7}}};
            {Id = 'sumo'; Tail = {{8,7}}};
            {Id = 'sumo'; Tail = {{9,7}}};
            {Id = 'sumo'; Tail = {{10,7}}};
        };
    };

    place{
        Id = 'L42';
		Background = 'donut';
        CreditReward = 1000;
        MapData = {        
            '-### #### #### ##--';
            '-#-# -#-# -#-# -#--';
            '-### #### #### ##--';
            '-#-# -#-# -#-# -#--';
            '-### #### #### ##--';
            '-#-# -#-# -#-# -#--';
            '-### #### #### ##--';
            '-#-# -#-# -#-# -#--';
            '-### #### #### ##--';
            '-#-# -#-# -#-# -#--';
            '-### #### #### ##--';
            '---- ---- ---- ----';
        };
        UploadZones = {{6,6}, {10,6}, {8,5}, {8,7}};
        ExtraCreditList = {{4,3}, {12,3}, {12,9}, {4,9}};
		CodeList = {};
        ProgramList = {
            {Id = 'wardenpp'; Tail = {{2,2}}};
            {Id = 'sentinel3'; Tail = {{5,1}}};
            {Id = 'sentinel3'; Tail = {{10,1}}};
            {Id = 'wardenpp'; Tail = {{14,2}}};
            {Id = 'sentinel3'; Tail = {{2,6}}};
            {Id = 'sentinel3'; Tail = {{14,6}}};
            {Id = 'wardenpp'; Tail = {{5,11}}};
            {Id = 'sentinel3'; Tail = {{13,11}}};
        };
    };

    place{
        Id = 'L43';
		Background = 'monkey';
        CreditReward = 1000;
        MapData = {        
            '---- ---- ---- ----';
            '-### -### ###- ###-';
            '-### #### #### ###-';
            '-### -### ###- ###-';
            '---- ---- ---- -#--';
            '---- ---- ---- -#--';
            '---- ---- ---- -#--';
            '-### -### ###- ###-';
            '-### #### #### ###-';
            '-### -### ###- ###-';
            '---- ---- ---- ----';
            '---- ---- ---- ----';
        };
        UploadZones = {{3,9}};
        ExtraCreditList = {{14,2},{14,3},{15,3},{14,9},{14,10},{15,9}};
		CodeList = {{3,3}};
        ProgramList = {
            {Id = 'firewall'; Tail = {
				{6,9},{6,10},{7,10},{7,9},{8,9},{8,10},{9,10},{9,9},{10,9},{10,10},{11,10},{11,9},
				{11,8},{10,8},{9,8},{8,8},{7,8},{6,8}
			}};
            {Id = 'firewall'; Tail = {
				{11,3},{11,2},{10,2},{10,3},{9,3},{9,2},{8,2},{8,3},{7,3},{7,2},{6,2},{6,3},
				{6,4},{7,4},{8,4},{9,4},{10,4},{11,4}
			}};
        };
    };

    place{
        Id = 'L44';
		Background = 'ped';
        CreditReward = 1000;
        MapData = {        
            '--## #### #### ##--';
            '--#- ---# #--- -#--';
            '--#- #### #### -#--';
            '--#- #### #### -#--';
            '--#- #### #### -#--';
            '--## #### #### ##--';
            '--#- #### #### -#--';
            '--#- #### #### -#--';
            '--#- #### #### -#--';
            '--#- ---# ##-- -#--';
            '--## #### #### ##--';
            '---- ---- ---- ----';
        };
        UploadZones = {{7,5}, {10,5}, {7,7}, {10,7}};
        ExtraCreditList = {{8,6}, {9,6}};
		CodeList = {};
        ProgramList = {
            {Id = 'mandelbug'; Tail = {{4,1}}};
            {Id = 'mandelbug'; Tail = {{3,2}}};
            {Id = 'mandelbug'; Tail = {{13,1}}};
            {Id = 'mandelbug'; Tail = {{14,2}}};
            {Id = 'mandelbug'; Tail = {{13,11}}};
            {Id = 'mandelbug'; Tail = {{14,10}}};
            {Id = 'mandelbug'; Tail = {{3,10}}};
            {Id = 'mandelbug'; Tail = {{4,11}}};
        };
    };

    place{
        Id = 'L45';
		Background = 'pharmhaus';
        CreditReward = 1000;
        MapData = {        
            '-### #### #### ###-';
            '-### #### #--- -##-';
            '---- -### #### ###-';
            '-### ###- ---# ###-';
            '-### #### #### ##--';
            '-##- ---# #### ###-';
            '-### #### ###- -##-';
            '-### ###- -### ###-';
            '--## #### #### #---';
            '-### #--- -### ###-';
            '-### #### #### ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {{3,11}, {4,11}, {11,11}, {12,11}};
        ExtraCreditList = {{3,7},{4,7},{11,6},{12,6}};
		CodeList = {};
        ProgramList = {
            {Id = 'sentinel3'; Tail = {{4,1}}};
            {Id = 'watchmansp'; Tail = {{6,1}}};
            {Id = 'watchmansp'; Tail = {{10,1}}};
            {Id = 'sentinel3'; Tail = {{13,1}}};
            {Id = 'watchmansp'; Tail = {{3,2}}};
            {Id = 'sentinel3'; Tail = {{9,2}}};
            {Id = 'watchmansp'; Tail = {{15,2}}};
            {Id = 'watchmansp'; Tail = {{7,3}}};
            {Id = 'watchmansp'; Tail = {{11,3}}};
            {Id = 'watchmansp'; Tail = {{13,3}}};
        };
    };

    place{
        Id = 'L46';
		Background = 'ped';
        CreditReward = 1000;
        MapData = {        
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '--#- #-## ##-# -#--';
            '--#- #-#- -#-# -#--';
            '--#- #-## ##-# -#--';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {{7,1}, {8,1}, {9,1}, {10,1}};
        ExtraCreditList = {{8,11},{9,11},{8,9},{9,9}};
		CodeList = {};
        ProgramList = {
            {Id = 'radar'; Tail = {{8,10}}};
            {Id = 'radar'; Tail = {{9,10}}};
            {Id = 'firewall'; Tail = {{5,7},{5,8},{6,8},{6,9},{5,9},{4,9},{3,9},{2,9},{2,8},{3,8},{4,8}}};
            {Id = 'firewall'; Tail = {{12,7},{12,8},{11,8},{11,9},{12,9},{13,9},{14,9},{15,9},{15,8},{14,8},{13,8}}};
            {Id = 'sumo'; Tail = {{7,10},{7,11},{6,11},{5,11},{4,11},{3,11},{2,11}}};
            {Id = 'sumo'; Tail = {{10,10},{10,11},{11,11},{12,11},{13,11},{14,11},{15,11}}};
            {Id = 'guarddog'; Tail = {{3,6}}};
            {Id = 'guarddog'; Tail = {{7,6}}};
            {Id = 'guarddog'; Tail = {{10,6}}};
            {Id = 'guarddog'; Tail = {{14,6}}};
        };
    };

    place{
        Id = 'L47';
		Background = 'ped';
        CreditReward = 1000;
        MapData = {        
            '-#-# #### #### #-#-';
            '---# #### #### #---';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '---# #### #### #---';
            '-#-# #### #### #-#-';
            '---- ---- ---- ----';
        };
        UploadZones = {{7,5},{10,5},{10,7},{7,7},{8,6},{9,6}};
        ExtraCreditList = {{2,1},{15,1},{15,11},{2,11}};
		CodeList = {};
        ProgramList = {
            {Id = 'pup'; Tail = {{4,1}}};
            {Id = 'pup'; Tail = {{5,1}}};
            {Id = 'sentinel'; Tail = {{7,1}}};
            {Id = 'sentinel'; Tail = {{8,1}}};
            {Id = 'sentinel'; Tail = {{9,1}}};
            {Id = 'sentinel'; Tail = {{10,1}}};
            {Id = 'pup'; Tail = {{12,1}}};
            {Id = 'pup'; Tail = {{13,1}}};
            {Id = 'pup'; Tail = {{4,11}}};
            {Id = 'pup'; Tail = {{5,11}}};
            {Id = 'sentinel'; Tail = {{7,11}}};
            {Id = 'sentinel'; Tail = {{8,11}}};
            {Id = 'sentinel'; Tail = {{9,11}}};
            {Id = 'sentinel'; Tail = {{10,11}}};
            {Id = 'pup'; Tail = {{12,11}}};
            {Id = 'pup'; Tail = {{13,11}}};
			{Id = 'pup'; Tail = {{2,3}}};
			{Id = 'watchman'; Tail = {{2,5}}};
			{Id = 'watchman'; Tail = {{2,6}}};
			{Id = 'watchman'; Tail = {{2,7}}};
			{Id = 'pup'; Tail = {{2,9}}};
			{Id = 'pup'; Tail = {{15,3}}};
			{Id = 'watchman'; Tail = {{15,5}}};
			{Id = 'watchman'; Tail = {{15,6}}};
			{Id = 'watchman'; Tail = {{15,7}}};
			{Id = 'pup'; Tail = {{15,9}}};
        };
    };

    place{
        Id = 'L48';
		Background = 'ped';
        CreditReward = 1000;
        MapData = {        
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### --## ###-';
            '-### #### #### ##--';
            '--## #--# #### ##--';
            '--## #### #### ###-';
            '-### #### #### ###-';
            '-### #### #-## ###-';
            '-### #### #-## ###-';
            '-### #### #### ###-';
            '-### #--# #### ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {{2,10},{2,9},{2,8},{5,8},{11,3},{11,4,},{11,5}};
        ExtraCreditList = {{4,5},{9,1},{9,5},{9,6},{9,11},{10,1},{10,5},{10,6},{10,11}};
		CodeList = {};
        ProgramList = {
            {Id = 'wardenpp'; Tail = {{3,1}}};
            {Id = 'wardenpp'; Tail = {{4,1}}};
            {Id = 'wardenpp'; Tail = {{6,1}}};
            {Id = 'wardenpp'; Tail = {{7,1}}};
            {Id = 'wardenpp'; Tail = {{13,1}}};
            {Id = 'watchmansp'; Tail = {{3,3}}};
            {Id = 'watchmansp'; Tail = {{7,3}}};
            {Id = 'watchmansp'; Tail = {{8,3}}};
            {Id = 'watchmansp'; Tail = {{12,3}}};
            {Id = 'wardenpp'; Tail = {{15,3}}};
            {Id = 'watchmansp'; Tail = {{13,4}}};
            {Id = 'wardenpp'; Tail = {{15,6}}};
            {Id = 'watchmansp'; Tail = {{12,7}}};
            {Id = 'wardenpp'; Tail = {{15,7}}};
            {Id = 'watchmansp'; Tail = {{12,8}}};
            {Id = 'watchmansp'; Tail = {{13,10}}};
            {Id = 'wardenpp'; Tail = {{15,10}}};
            {Id = 'wardenpp'; Tail = {{15,11}}};
        };
    };

    place{
        Id = 'L49';
		Background = 'pharmhaus';
        CreditReward = 1000;
        MapData = {        
            '-### -### ##-- ###-';
            '-### -### ##-- ###-';
            '-### -### ##-- ###-';
            '---- -### ##-- ----';
            '-### #### ##-- ----';
            '-### #### #### ###-';
            '---- --## #### ###-';
            '---- --## ###- ----';
            '-### --## ###- ###-';
            '-### --## ###- ###-';
            '-### --## ###- ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {{2,9},{2,11},{4,11},{4,9}};
        ExtraCreditList = {{2,1},{3,1},{2,2},{15,10},{15,11},{14,11}};
		CodeList = {{15,1}};
        ProgramList = {
            {Id = 'radar'; Tail = {{4,1}}};
            {Id = 'radar'; Tail = {{3,2}}};
            {Id = 'radar'; Tail = {{2,3}}};
            {Id = 'radar'; Tail = {{13,11}}};
            {Id = 'radar'; Tail = {{14,10}}};
            {Id = 'radar'; Tail = {{15,9}}};
            {Id = 'radar'; Tail = {{15,3}}};
            {Id = 'radar'; Tail = {{14,2}}};
            {Id = 'radar'; Tail = {{13,1}}};
            {Id = 'radar'; Tail = {{13,3}}};
            {Id = 'sensor'; Tail = {{8,6}}};
            {Id = 'sensor'; Tail = {{9,6}}};
            {Id = 'attackdog'; Tail = {{7,1}}};
            {Id = 'attackdog'; Tail = {{10,11}}};
            {Id = 'watchmanx'; Tail = {{15,6}}};
            {Id = 'watchmanx'; Tail = {{15,7}}};
        };
    };

    place{
        Id = 'L310';
		Background = 'ped';
        CreditReward = 1000;
        MapData = {        
            '-### #--- ---- ----';
            '-### #--- #### ###-';
            '-### #--- #--- --#-';
            '-### #--- #--- --#-';
            '-### #--- #### --#-';
            '-### #--- #### --#-';
            '-### #--- #### --#-';
            '-### #--- ---- --#-';
            '-### #--- ---- --#-';
            '-### #--- ---- --#-';
            '-### #### #### ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {{2,11},{3,11},{4,11},{5,11}};
        ExtraCreditList = {{9,5},{10,5},{11,5},{12,5},{9,6},{12,6},{9,7},{10,7},{11,7},{12,7}};
		CodeList = {{2,1}};
        ProgramList = {
            {Id = 'guarddog'; Tail = {{2,3}}};
            {Id = 'guarddog'; Tail = {{3,2}}};
            {Id = 'guarddog'; Tail = {{4,2}}};
            {Id = 'guarddog'; Tail = {{5,3}}};
            {Id = 'attackdog'; Tail = {{3,1}}};
            {Id = 'attackdog'; Tail = {{4,1}}};
            {Id = 'radar'; Tail = {{15,11}}};
            {Id = 'radar'; Tail = {{15,2}}};
            {Id = 'radar'; Tail = {{10,6}}};
            {Id = 'radar'; Tail = {{11,6}}};
        };
    };

    place{
        Id = 'L311';
		Background = 'automa';
        CreditReward = 1000;
        MapData = {        
            '---- #### ---- ###-';
            '-### #### #### ###-';
            '-### -### #### ###-';
            '-### #### -### ###-';
            '-### #### -### ###-';
            '-### ###- --## ###-';
            '-### ###- -### -##-';
            '-### ##-- #### -##-';
            '---# ##-# #### ###-';
            '---# #### #### #---';
            '---# #### ##-- ----';
            '---- ---- ---- ----';
        };
        UploadZones = {{2,4},{6,6},{11,5},{15,8}};
        ExtraCreditList = {{4,3},{11,8}};
		CodeList = {};
        ProgramList = {
            {Id = 'sentinel3'; Tail = {{15,4}}};
            {Id = 'sentinel3'; Tail = {{15,2}}};
            {Id = 'sentinel3'; Tail = {{13,2}}};
            {Id = 'sentinel3'; Tail = {{7,11}}};
            {Id = 'sentinel3'; Tail = {{5,10}}};
            {Id = 'sentinel3'; Tail = {{4,9}}};
            {Id = 'attackdog'; Tail = {{9,10}}};
            {Id = 'attackdog'; Tail = {{7,1}}};
        };
    };

    place{
        Id = 'L312';
		Background = 'automa';
        CreditReward = 1000;
        MapData = {        
            '--## ##-- ---# #---';
            '--## ##-- ##-# #---';
            '--## ##-- ##-- ----';
            '--## #### ##-# #---';
            '---- -### ##-# #---';
            '---- -### ##-# #---';
            '---# #### ##-# #---';
            '---# #### ##-# #---';
            '---- ---- ---# #---';
            '--## -### #### #---';
            '--## -### #### #---';
            '---- ---- ---- ----';
        };
        UploadZones = {{4,1}, {4,2}, {3,2}};
        ExtraCreditList = {{3,10},{3,11},{13,1},{12,1}};
		CodeList = {{13,11}};
        ProgramList = {
            {Id = 'watchmansp'; Tail = {{12,4}}};
            {Id = 'watchmansp'; Tail = {{12,5}}};
            {Id = 'watchmansp'; Tail = {{6,10}}};
            {Id = 'watchmansp'; Tail = {{7,10}}};
            {Id = 'sonar'; Tail = {{10,8}}};
            {Id = 'firewall'; Tail = {
				{6,4},{7,4},{8,4},
				{8,5},{7,5},{6,5},
				{6,6},{7,6},{8,6},
				{8,7},{7,7},
				{7,8},{8,8},{9,8},
				{9,7},{10,7},
				{10,6},{9,6},
				{9,5},{10,5}
			}};
        };
    };

    place{
        Id = 'L410';
		Background = 'pharmhaus';
        CreditReward = 1000;
        MapData = {        
            '-### #--- --## ###-';
            '-### ##-- ---- ###-';
            '-### ---- --## ###-';
            '-### #--- ---# ###-';
            '-### ###- -### ###-';
            '-### ---- --## ###-';
            '-### ##-- #### ###-';
            '-### #--- ---- ###-';
            '-### ##-- ---# ###-';
            '-### #### ---- ###-';
            '-### #--- ---# ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {{3,2}, {3,4}, {3,6}, {3,8}, {3,10}};
        ExtraCreditList = {};
		CodeList = {};
        ProgramList = {
            {Id = 'radar'; Tail = {{11,1}}};
            {Id = 'radar'; Tail = {{11,3}}};
            {Id = 'radar'; Tail = {{10,5}}};
            {Id = 'radar'; Tail = {{9,7}}};
            {Id = 'radar'; Tail = {{12,9}}};
            {Id = 'radar'; Tail = {{12,11}}};
            {Id = 'wardenpp'; Tail = {{14,4}}};
            {Id = 'wardenpp'; Tail = {{14,8}}};
        };
    };
--[[
    place{
        Id = '';
		Background = '';
        CreditReward = 1000;
        MapData = {        
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {{}};
        ExtraCreditList = {};
		CodeList = {};
        ProgramList = {
            {Id = ''; Tail = {{}}};
        };
    };
]]
    place{
        Id = 'L5';
		Background = 'disarray';
        CreditReward = 1000;
        MapData = {        
            '-### #### --## ###-';
            '-### #### -### ###-';
            '-### #### --## ###-';
            '-### #### -### ###-';
            '-### #### --## ###-';
            '-### #### ---# -#--';
            '-### #### ---- ----';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '-### #### #### ###-';
            '---- ---- ---- ----';
        };
        UploadZones = {
            {3, 9}, {4, 9}, {5, 9}, {6, 9}, {7, 9},
            {3, 10}, {4, 10}, {5, 10}, {6, 10}, {7, 10},
        };
        ExtraCreditList = {};
		CodeList = {};
        ProgramList = {
            {Id = 'attackdog'; Tail = {{2, 1}}};
            {Id = 'attackdog'; Tail = {{3, 1}}};
            {Id = 'attackdog'; Tail = {{7, 1}}};
            {Id = 'attackdog'; Tail = {{8, 1}}};
            {Id = 'watchmansp'; Tail = {{2, 2}}};
            {Id = 'watchmansp'; Tail = {{3, 2}}};
            {Id = 'watchmansp'; Tail = {{7, 2}}};
            {Id = 'watchmansp'; Tail = {{8, 2}}};
            {Id = 'wardenpp'; Tail = {{4, 1}}};
            {Id = 'wardenpp'; Tail = {{5, 1}}};
            {Id = 'wardenpp'; Tail = {{6, 1}}};
            {Id = 'wardenp'; Tail = {{4, 2}}};
            {Id = 'wardenp'; Tail = {{5, 2}}};
            {Id = 'wardenp'; Tail = {{6, 2}}};
            {Id = 'radar'; Tail = {{10, 2}}};
            {Id = 'radar'; Tail = {{10, 4}}};
            {Id = 'radar'; Tail = {{12, 6}}};
            {Id = 'radar'; Tail = {{14, 6}}};
            {Id = 'sumo'; Tail = {
				{11, 9}, {11, 8}, {12, 8}, {12, 9}, 
				{13, 9}, {13, 8}, {14, 8}, {14, 9},
				{15, 9}, {15, 8}, 
			}};
            {Id = 'sumo'; Tail = {
				{11, 10}, {11, 11}, {12, 11}, {12, 10}, 
				{13, 10}, {13, 11}, {14, 11}, {14, 10},
				{15, 10}, {15, 11},  
			}};
            {Id = 'boss'; Tail = {
				{11, 2}, {11, 1},
				{12, 1}, {12, 2}, {12, 3}, {12, 4}, {12, 5},
				{13, 5}, {13, 4}, {13, 3}, {13, 2}, {13, 1},
				{14, 1}, {14, 2}, {14, 3}, {14, 4}, {14, 5},
				{15, 5}, {15, 4}, {15, 3}, {15, 2}, {15, 1},  
			}};
        };
    };
}