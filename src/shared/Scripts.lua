
local ScriptColors = require(game.ReplicatedStorage.ScriptColors)

local function script(id, name, move, maxSize, color, img, desc, ...)
	local commands = {}
	local commandList = {}
	for i, command in pairs{...} do
		commands[command.Id] = command
		commandList[i] = command
	end
    return {
        Id = id;
        Name = name;
        Desc = desc;
		Color = color;
		Image = img;
        Move = move;
        MaxSize = maxSize;
        Commands = commands;
		CommandList = commandList;
    }
end

function enemyScript(id, name, move, maxSize, color, img, desc, ...)
    local data = script(id, name, move, maxSize, color, img, desc, ...)
    data.Enemy = true
    return data
end

local function command(id: string, name: string, type: string, sizeReq: number, cost: number, range: number, amount: number)
    return {
        Id = id;
        Type = type;
        Name = name;
        Desc = "todo";
        SizeReq = sizeReq;
        Cost = cost;
        Range = range;
        Amount = amount;
    }
end

local function scripts(tb)
    local lookup = {}
    for k, v in pairs(tb) do
        lookup[v.Id] = v
    end
    return lookup
end

return scripts{
    --======================================================================--
    --========================== Friendly Programs =========================--
    --======================================================================--
    script('bitman', "Bit-Man", 3, 3,
		ScriptColors.LightGreen, 'rbxassetid://1338011879',
        "Make sectors of the grid appear or disappear... forever!",
        command('zero', "Zero", 'zero', 0, 0, 1, 1),
        command('one', "One", 'one', 0, 0, 1, 1));    

    script('hack', "Hack", 2, 4,
		ScriptColors.LightBlue, 'rbxassetid://1338015926',
        "Basic attack script.",
        command('slice', "Slice", 'damage', 0, 0, 1, 2));

    script('hack2', "Hack 2.0", 3, 4,
		ScriptColors.LightBlue, 'rbxassetid://1338007330',
        "Improved hacking script.",
        command('slice', "Slice", 'damage', 0, 0, 1, 2),
        command('dice', "Dice", 'damage', 3, 0, 1, 3));

    script('hack3', "Hack 3.0", 4, 4,
		ScriptColors.LightBlue, 'rbxassetid://1338007329',
        "Top of the line hacking script.",
        command('slice', "Slice", 'damage', 0, 0, 1, 2),
        command('mutilate', "Mutilate", 'damage', 4, 0, 1, 4));

    script('golemmud', "Golem.mud", 1, 5,
		ScriptColors.Cyan, 'rbxassetid://1338016455',
        "Slow and steady attack script.",
        command('thump', "Thump", 'damage', 0, 0, 1, 3));        
    
    script('golemclay', "Golem.clay", 2, 6,
		ScriptColors.Cyan, 'rbxassetid://1338016453',
        "Clay is stronger than mud.",
        command('bash', "Bash", 'damage', 0, 0, 1, 5));

    script('golemstone', "Golem.stone", 3, 7,
		ScriptColors.Cyan, 'rbxassetid://1338015921', 
        "Nothing can stand in its way.",
        command('crash', "Crash", 'damage', 0, 0, 1, 7));

    script('wolfspider', "Wolf Spider", 3, 3,
		ScriptColors.DarkGreen, 'rbxassetid://1338024506',
        "Speedy and creepy little program.",
        command('byte', "Byte", 'damage', 0, 0, 1, 2));

    script('blackwidow', "Black Widow", 4, 3,
		ScriptColors.DarkGreen, 'rbxassetid://1338012734',
        "Speedier and creepier.",
        command('byte', "Byte", 'damage', 0, 0, 1, 2),
        command('paralyze', "Paralyze", 'speedMod', 0, 0, 1, -3));

    script('tarantula', "Tarantula", 5, 3,
		ScriptColors.DarkGreen, 'rbxassetid://1338022749',
        "Fast, with a venomous byte.",
        command('megabyte', "Megabyte", 'damage', 0, 0, 1, 3),
        command('paralyze', "Paralyze", 'speedMod', 0, 0, 1, -3));

    script('bug', "Bug", 5, 1,
		ScriptColors.LightGreen, 'rbxassetid://1338012740',
        "Fast, cheap... and out of control!",
        command('fglitch', "Fractal Glitch", 'damage', 0, 0, 1, 2));

    script('mandelbug', "MandelBug", 5, 1,
		ScriptColors.LightGreen, 'rbxassetid://1338018437',
        "It's not a true bug, it's a feature.",
        command('fglitch', "Fractal Glitch", 'damage', 0, 0, 1, 4));

    script('heisenbug', "HeisenBug", 5, 1,
		ScriptColors.LightGreen, 'rbxassetid://1338017917',
        "They can't kill what they can't catch!",
        command('qglitch', "Quantum Glitch", 'damage', 0, 0, 1, 6));

    script('buzzbomb', "BuzzBomb", 8, 2,
		ScriptColors.DarkBlue, 'rbxassetid://1338010617',
        "Fast an annoying. Bzzzt!",
        command('sting', "Sting", 'damage', 0, 0, 1, 1),
        command('kamikazee', "Kamikazee", 'damage', 0, 1337, 1, 5));

    script('logicbomb', "LogicBomb", 3, 6,
		ScriptColors.DarkBlue, 'rbxassetid://1338017916',
        "Self-Destructing attack script.",
        command('selfdestruct', "Self-Destruct", 'damage', 6, 1337, 1, 10));
    
    script('fiddle', "Fiddle", 3, 3,
		ScriptColors.DarkBlue, 'rbxassetid://1338014721',
        "Twiddle and tweak the features of your scripts.",
        command('tweak', "Tweak", 'speedMod', 0, 1, 1, 1),
        command('twiddle', "Twiddle", 'sizeMod', 0, 1, 1, 1));

    script('medic', "Medic", 3, 3,
		ScriptColors.DarkBlue, 'rbxassetid://1338018442',
        "Grows you programs from a distance.",
        command('hypo', "Hypo", 'grow', 0, 0, 3, 2));

    script('dr', "Data Doctor", 4, 5,
		ScriptColors.DarkBlue, 'rbxassetid://1338014722',
        "Helps grow your scripts.",
        command('grow', "Grow", 'grow', 0, 0, 1, 2));

    script('drpro', "Data Dr. Pro", 5, 8,
		ScriptColors.DarkBlue, 'rbxassetid://1338007722',
        "Twice the expansion power of data doctor.",
        command('megagrow', "MegaGrow", 'grow', 0, 0, 1, 4),
        command('surgery', "Surgery", 'sizeMod', 0, 0, 1, 1));

    script('turbo', "Turbo", 3, 3,
		ScriptColors.DarkBlue, 'rbxassetid://1338022746',
        "A little bit of optimization never hurts.",
        command('boost', "Boost", 'speedMod', 0, 1, 1, 1));

    script('tdulux', "Turbo Delux", 4, 4,
		ScriptColors.DarkBlue, 'rbxassetid://1338007705',
        "Slow and steady is for losers.",
        command('megaboost', "Megaboost", 'speedMod', 3, 2, 2, 2));

    script('sumo', "Sumo", 2, 12,
		ScriptColors.DarkGreen, 'rbxassetid://1338021932',
        "A massive and slow-moving powerhouse.",
        command('dataslam', "Dataslam", 'damage', 6, 0, 1, 8));

    script('seeker', "Seeker", 3, 4,
		ScriptColors.Teal, 'rbxassetid://1338019825',
        "Solid distance attack script.",
        command('peek', "Peek", 'damage', 0, 0, 2, 2));

    script('seeker2', "Seeker 2.0", 3, 4,
		ScriptColors.Teal, 'rbxassetid://1338019835',
        "Bigger and better than seeker.",
        command('poke', "Poke", 'damage', 0, 0, 3, 2));

    script('seeker3', "Seeker 3.0", 4, 5,
		ScriptColors.Teal, 'rbxassetid://1338019838',
        "Seeker with extra deletion power.",
        command('poke', "Poke", 'damage', 0, 0, 3, 2),
        command('seekndestroy', "Seek and Destroy", 'damage', 5, 2, 2, 5));

    script('tower', "Tower", 0, 1,
		ScriptColors.Teal, 'rbxassetid://1338022748',
        "Immobile long range script.",
        command('spot', "Spot", 'damage', 0, 0, 3, 3));

    script('mobiletower', "Mobile Tower", 1, 1,
		ScriptColors.Teal, 'rbxassetid://1338019051',
        "Slow moving long range script.",
        command('spot', "Spot", 'damage', 0, 0, 3, 3));

    script('sat', "Satellite", 1, 1,
		ScriptColors.Teal, 'rbxassetid://1338019824',
        "Short range hard-hitting script.",
        command('scramble', "Scramble", 'damage', 0, 0, 2, 4));

    script('lasersat', "Laser Satellite", 2, 1,
		ScriptColors.Teal, 'rbxassetid://1338017919',
        "Long range hard-hitting script.",
        command('megascramble', "Megascramble", 'damage', 0, 0, 3, 4));

    script('slingshot', "Slingshot", 4, 2,
		ScriptColors.Teal, 'rbxassetid://1338021929',
        "Basic ranged attack script.",
        command('stone', "Stone", 'damage', 0, 0, 3, 1));

    script('ballista', "Ballista", 1, 2,
		ScriptColors.Teal, 'rbxassetid://1338011878',
        "No trebuches allowed!",
        command('fling', "Fling", 'damage', 0, 0, 4, 2));

    script('catapult', "Catapult", 2, 3,
		ScriptColors.Teal, 'rbxassetid://1338007726',
        "For real though, no trebuches.",
        command('fling', "Fling", 'damage', 0, 0, 4, 2));

    script('clog1', "Clog 1.0", 2, 4,
		ScriptColors.Cyan, 'rbxassetid://1338007328',
        "Standard anti-lag script.",
        command('chug', "Chug", 'speedMod', 0, 0, 3, -1));

    script('clog2', "Clog 2.0", 2, 4,
		ScriptColors.Cyan, 'rbxassetid://1338007326',
        "Twice as effective as the first version.",
        command('chug', "Chug", 'speedMod', 0, 0, 3, -2));

    script('clog3', "Clog 3.0", 2, 4,
		ScriptColors.Cyan, 'rbxassetid://1338007331',
        "Solving the halting problem, one script at a time.",
        command('chug', "Chug", 'speedMod', 0, 0, 3, -2),
        command('hang', "Hang", 'speedMod', 4, 0, 3, -1337));

    script('guru', "Guru", 2, 3,
		ScriptColors.Cyan, 'rbxassetid://1338045535',
        "Multipurpose script for the l33tist of the l33t.",
        command('fire', "Fire", 'damage', 0, 0, 2, 4),
        command('ice', "Ice", 'speedMod', 0, 0, 2, -3));

    script('hog', "Memory Hog", 5, 30,
		ScriptColors.LightGreen, 'rbxassetid://1338018438',
        "PED's magnum opus: Massive memory-filling bloatware.");

    script('wizard', "Wizard", 3, 4,
		ScriptColors.Cyan, 'rbxassetid://1338024507',
        "Pay no attention to the man behind the curtain.",
        command('scorch', "Scorch", 'damage', 0, 0, 3, 2),
        command('stretch', "Stretch", 'sizeMod', 0, 0, 2, 1));

        
    --======================================================================--
    --=========================== Enemy Programs ===========================--
    --======================================================================--
    enemyScript('pup', "Pup", 3, 2,
		ScriptColors.YellowOrange, 'rbxassetid://1338019047',
        "A speedy little corporate cur.",
        command('byte', "Byte", 'damage', 0, 0, 1, 2));

    enemyScript('guarddog', "Guard Dog", 3, 3,
		ScriptColors.YellowOrange, 'rbxassetid://1338015923',
        "Who let this dog out?",
        command('kilobyte', "Kilobyte", 'damage', 0, 0, 1, 2));

    enemyScript('attackdog', "Attack Dog", 4, 7,
		ScriptColors.YellowOrange, 'rbxassetid://1338011876',
        "Ravenous and bloodthirsty corporate canine.",
        command('megabyte', "Megabyte", 'damage', 0, 0, 1, 3));

    enemyScript('sentinel', "Sentinel", 1, 3,
		ScriptColors.DarkOrange, 'rbxassetid://1335235117',
        "Corporate data defender.",
        command('cut', "Cut", 'damage', 0, 0, 1, 2));

    enemyScript('sentinel2', "Sentinel 2.0", 2, 4,
		ScriptColors.DarkOrange, 'rbxassetid://1338020694',
        "Corporate data defender.",
        command('cut', "Cut", 'damage', 0, 0, 1, 2));

    enemyScript('sentinel3', "Sentinel 3.0", 2, 4,
		ScriptColors.DarkOrange, 'rbxassetid://1338020693',
        "Sentinel that attacks several scripts at once.",
        command('tazer', "Tazer", 'damage', 0, 0, 1, 4));

    enemyScript('watchman', "Watchman", 1, 2,
		ScriptColors.Magenta, 'rbxassetid://1338024148',
        "Corporate ranged attack script.",
        command('phaser', "Phaser", 'damage', 0, 0, 2, 2));

    enemyScript('watchmanx', "Watchman X", 1, 4,
		ScriptColors.Magenta, 'rbxassetid://1338024153',
        "Improved version of the watchman.",
        command('phaser', "Phaser", 'damage', 0, 0, 2, 2));

    enemyScript('watchmansp', "Watchman SP", 1, 4,
		ScriptColors.Magenta, 'rbxassetid://1338024149',
        "Watching from an even greater distance.",
        command('phaser', "Phaser", 'damage', 0, 0, 3, 2));

    enemyScript('warden', "Warden", 1, 5,
		ScriptColors.Red, 'rbxassetid://1338023568',
        "Slow and steady corporate attack script.",
        command('smash', "Smash", 'damage', 0, 0, 1, 3));

    enemyScript('wardenp', "Warden+", 2, 6,
		ScriptColors.Red, 'rbxassetid://1338023564',
        "Get out of its way.",
        command('bash', "Bash", 'damage', 0, 0, 1, 5));

    enemyScript('wardenpp', "Warden++", 3, 7,
		ScriptColors.Red, 'rbxassetid://1338023565',
        "The last word in corporate security.",
        command('crash', "Crash", 'damage', 0, 0, 1, 7));

    enemyScript('boss', "Boss", 6, 25,
		ScriptColors.EnemyOrange, 'rbxassetid://1338012731',
        "No introduction needed.",
        command('shutdown', "Shutdown", 'damage', 0, 0, 5, 5));

    enemyScript('firewall', "Firewall", 2, 20,
		ScriptColors.EnemyOrange, 'rbxassetid://1338014739',
        "Keeps unwanted scripts out of corporate data.",
        command('burn', "Burn", 'damage', 0, 0, 1, 1));

    enemyScript('sensor', "Sensor", 0, 1,
		ScriptColors.EnemyYellow, 'rbxassetid://1338020695',
        "Immobile program erradicator.",
        command('blip', "Blip", 'damage', 0, 0, 5, 1));

    enemyScript('radar', "Radar", 0, 1,
		ScriptColors.EnemyYellow, 'rbxassetid://1338019045',
        "Deadly program erradicator.",
        command('pong', "Pong", 'damage', 0, 0, 5, 2));

    enemyScript('sonar', "Sonar", 0, 1,
		ScriptColors.EnemyYellow, 'rbxassetid://1338021930',
        "Long-range program erradicator.",
        command('ping', "Ping", 'damage', 0, 0, 8, 1));
}