local Netmap = {}

Netmap.ById = {}

local mDefaultIntrusionMessage = 
	"The node you are attempting to access is the property of %s. Unauthorized access beyond this point is strictly prohibited.\nIf you proceed you will be in violation of international corporate statute 71J-36WF9 and will be disconnected."

local function node(tb)
	Netmap.ById[tb.Id] = tb
	if tb.Id == 'hq' then
		tb.Level = 1
	elseif tb.Id == 'end' then
		tb.Level = 5
	else
		tb.Level = tonumber(tb.Id:sub(3,3))
	end
	if tb.Id == 'hq' then
		tb.Image = 'rbxassetid://1423258609' --rbxgameasset://Images/NodeHQ64'
		tb.BeatenImage = 'rbxassetid://1423259025' --rbxgameasset://Images/NodeHQBeaten64'
		tb.Sound = nil
		tb.Org = "SMART"
	elseif tb.Id:sub(1,2) == 'lm' then
		tb.Image = 'rbxassetid://1423258606' --rbxgameasset://Images/NodeLuckyMonkey64'
		tb.BeatenImage = 'rbxassetid://1423259444' --rbxgameasset://Images/NodeLuckyMonkeyBeaten64'
		tb.Sound = 'EnterLuckyMonkey'
		tb.Org = "Lucky Monkey Media"
	elseif tb.Id:sub(1,2) == 'ph' then
		tb.Image = 'rbxassetid://1423259023' --rbxgameasset://Images/NodePharmhaus64'
		tb.BeatenImage = 'rbxassetid://1423259445' --rbxgameasset://Images/NodePharmhausBeaten64'
		tb.Sound = 'EnterPharmhaus'
		tb.Org = "Pharmhaus"
	elseif tb.Id:sub(1,2) == 'dr' then
		tb.Image = 'rbxassetid://1423257835' --rbxgameasset://Images/NodeDrDonut64'
		tb.BeatenImage = 'rbxassetid://1423257839' --rbxgameasset://Images/NodeDrDonutBeaten64'
		tb.Sound = 'EnterDrDonut'
		tb.Org = "Dr. Donut"
	elseif tb.Id:sub(1,2) == 'pd' then
		tb.Image = 'rbxassetid://1423259034' --rbxgameasset://Images/NodePED64'
		tb.BeatenImage = 'rbxassetid://1423259024' --rbxgameasset://Images/NodePEDBeaten64'
		tb.Sound = 'EnterPED'
		tb.Org = "P.E.D. Consultants"
	elseif tb.Id == 'end' then
		tb.Image = 'rbxassetid://1423258610' --rbxgameasset://Images/NodeDisarray64'
		tb.BeatenImage = 'rbxassetid://1423258607' --rbxgameasset://Images/NodeDisarrayBeaten64'
		tb.Sound = 'EnterDisarray'
		tb.Org = "Dignity"
	elseif tb.Id:sub(1,2) == 'ca' then
		tb.Image = 'rbxassetid://1423257836' --rbxgameasset://Images/NodeCelularAutoma64'
		tb.BeatenImage = 'rbxassetid://1423257851' --rbxgameasset://Images/NodeCelularAutomaBeaten64'
		tb.Sound = 'EnterCelularAutoma'
		tb.Org = "Celular Automa"
	elseif tb.Id:sub(1,2) == 'wz' then
		tb.Image = 'rbxassetid://1423257394' --rbxgameasset://Images/NodeWarez64'
		tb.BeatenImage = 'rbxassetid://1445926191' --rbxgameasset://Images/NodeWarezBeaten64'
		tb.Sound = nil
	else
		error("Bad node type: "..tb.Id)
	end
	if not tb.PlaceId then
		tb.PlaceId = 'tutorial'
	end
end

local function part(text, response1, target1, response2, target2)
	local tb = {
		Text = text;
		Response1 = response1;
		Target1 = target1;
		Response2 = response2;
		Target2 = target2;
	}
	return tb
end

local function conversation(tb)
	if tb.User == 'spinner' then
		tb.User = "Vexedly"
		tb.Image = 'rbxassetid://1353163481' --rbxgameasset://Images/UserVexedly'
	elseif tb.User == 'superphreak' then
		tb.User = "Aeacus"
		tb.Image = 'rbxassetid://1352624214' --rbxgameasset://Images/UserAeacus'
	elseif tb.User == 'wintermutant' then
		tb.User = "Minish"
		tb.Image = 'rbxassetid://1353163480' --rbxgameasset://Images/UserMinish'
	elseif tb.User == 'joana' then
		tb.User = "Are92"
		tb.Image = 'rbxassetid://1353163482' --rbxgameasset://Images/UserAre92'
	elseif tb.User == 'disarray' then
		tb.User = "Dignity"
		tb.Image = 'rbxassetid://1367227087' --rbxgameasset://Images/UserDignity'
	else
		error("Invalid user: "..tostring(tb.User))
	end
	return tb
end

local function functionRevealNode(nodeId)
	return {
		Type = 'revealNode';
		Id = nodeId;
	}
end

local function functionUpgradeSecurity(level)
	return {
		Type = 'upgradeSecurity';
		Level = level;
	}
end

local function functionGetProgram(id)
	return {
		Type = 'getProgram';
		Id = id;
	}
end

local function functionGetCredits(amount)
	return {
		Type = 'getCredits';
		Amount = amount;
	}
end

local function functionBeginNightfall()
	return {
		Type = 'beginNightfall';
	}
end

local function functionEndNightfall()
	return {
		Type = 'endNightfall';
	}
end

-- Display names, derived from the node id prefix ("Pharmhaus - ph14" style)
local kNodeFamilyNames = {
	ph = "Pharmhaus",
	lm = "Lucky Monkey",
	ca = "Celular Automa",
	dr = "Dr. Donut",
	pd = "PED",
	wz = "Warez",
	hq = "smart HQ",
	en = "Nightfall",
}
function Netmap.GetNodeDisplayName(id)
	return (kNodeFamilyNames[id:sub(1, 2)] or "Node") .. " - " .. id
end

Netmap.TutorialCallout = conversation{
	User = 'superphreak';
	Parts = {
		main = part("Hey, newbie. Rogue scripts are chewing up the network and I'm swamped. You've got to help me out.", "Okay, I'm on it.", 'end');
	}
}

Netmap.PostTutorialConversation = conversation{
	User = 'superphreak';
	Parts = {
		main = part("Way to go, you won your first databattle! This is the netmap: click a node to jack in and battle for control of it. Buy new scripts at warez nodes to grow stronger. You're on your own now, good luck!", "Got it.", 'end');
	}
}

node{
	Id = 'hq';
	Links = {'wz1', 'lm12', 'ph11'};
}

node{
	Id = 'ph11';
	Links = {'ca13', 'ph16'};
	PlaceId = 'L11';
	Name = "PR Database";
	Conversation = conversation{
		User = 'spinner';
		Parts = {
			main = part("Hey Pal. I see that you've been doing some sweet code slinging. Was wondering if you were interested in some extra business.", "What Kind of Business?", 'a');
			a = part("A little side business in data policing. It turns out that Pharmhaus was testing some new security and it went haywire. They can't even access their network.", "What do I get?", 'b');
			b = part("Well, Pharmhause is offering a nice shiny piece of software for someone to quietly access their node and disable teh security system. What do you think?", "Sure, I'll do it.", 'c');
			c = part("I knew you were the agent for the job! I'm putting the node up on your netmap now.", "Ready to recieve net data", 'end')		
		};
		Function = functionRevealNode('ph15');
	};
}

node{
	Id = 'wz1';
	Warez = {
		hack = 500;
		bug = 750;
		slingshot = 750;
		dr = 500;
		bitman = 250;
	};
	Links = {};
}

node{
	Id = 'lm12';
	Links = {'lm22'};
	PlaceId = 'L12';
	Name = "Tech Support";
	Mission = "SMART uses this node's security as a test mission. Defeat all hostile scripts.";
	Conversation = conversation{
		User = 'disarray';
		Parts = {
			main = part("Are you the newbie? I saw you beat the test run.", "No sweat.", 'a');
			a = part("Fellow smart agent on patrol. I was just executing some elite hacks in security level two. Where are you headed next?", "Just hacking through level one.", 'b');
			b = part("Cool. You'll definitely want to grab some better programs. Have you checked out the warez node? I'll show you where it is. Later.", "Later.", 'end');	
		};
		Function = functionRevealNode('wz1');
	};
}

node{
	Id = 'ph16';
	Links = {};
	PlaceId = 'L16';
	Name = "Employee Records";
	Conversation = conversation{
		User = 'superphreak';
		Parts = {
			main = part("Newbie, are you reading me?", "Sure, go ahead.", 'a');
			a = part("Great. I have some information for __ __ __", "You're breaking up.", 'b');
			b = part("____ ___ __  ____", "Done", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'ca13';
	Links = {'ca14', 'ph15', 'lm21'};
	PlaceId = 'L13';
	Name = "Memory Tower #43";
	Conversation = conversation{
		User = 'superphreak';
		Parts = {
			main = part("Hey. Not bad ___ ___ so far ___ you're almost ____ ready for level two ____ access.", "Thanks.", 'a');
			a = part("Hmm __ something __ ____ wierd's going on. I think I __ breaking up. __ look, you've got ___ get the access codes. We've put __ program there ___ help ___ out.", "What's wrong?", 'b');
			b = part("You ___ can find ____ ____ ___ _ ____ ___", "Aeacus? Hello?", 'c');
			c = part("____ ___ ___  ___ __ > EOF", "Done", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'ca14';
	Links = {};
	PlaceId = 'L14';
	Name = "Sydney Project";
	Mission = "This node contains the security level 2 access codes. Capture the codes to proceed.";
	Conversation = conversation{
		User = 'superphreak';
		Parts = {
			main = part("__ __ __ __ Hold on __ __ TRying to connect ___", "Aeacus?", 'a');
			a = part("Yeah, I'm back. I see you got the access codes. I'll think I have time to uprade your status and show you a new warez node before I get cut off again.", "Why did you get cut off before?", 'b');
			b = part("Someone's been screwing around with Smart. Some kind of corrupt program got loose in our network and I got cut off. For a second, I thought it was 12AM out here.", "12AM?", 'c');
			c = part("12AM = midnight. That's what we call a total network blackout. No access for anybody. It happened once a while ago during the worldwide power crisis. You wouldn't believe how bad it got before the network game back online.", "Got it.", 'd');
			d = part("Anyways, someone directly sabotaged smart and it's crippling our agents. But it's not affecting you because we haven't put your info into the smart system yet.", "Who's responsible for this?", 'e');
			e = part("I'm not sure yet, I'm going to keep looking into it. But with all of us popping in and out, I guess that leaves you as the only functional agent.", "Great.", 'f');
			f = part("I ran a trace on the problem that led back to the lucky monkey eastern distribution site. Somebody must have sent the corrupt program from there.", "Okay.", 'g');
			g = part("I guess you should see if you can pick up the local records. I'll get back to you when I can.", "Ready for Security Upgrade", 'end');
		};
		Function = functionUpgradeSecurity(2);
	}
}

node{
	Id = 'ph15';
	Links = {};
	PlaceId = 'L15';
	Name = "Government Affairs";
	Mission = "Pharmhaus offered this mission in exchange for a new piece of software. Disable all the malfunctioning security scripts.";
	Conversation = conversation{
		User = 'spinner';
		Parts = {
			main = part("Hey, knew I could count on you! Pharmhaus is reporting everything all clear. Here's the software they promised", "Ready to Receive Software", 'end');
		};
		Function = functionGetProgram('clog1');
	}
}

node{
	Id = 'lm21';
	Links = {'ph29'};
	PlaceId = 'L21';
	Name = "Eastern Distribution Site";
	Mission = "This node contains logs related to the Pharmhaus and Celular Automa corrupted programs. Retrieve the logs.";
	Conversation = conversation{
		User = 'superphreak';
		Parts = {
			main = part("Hey, good work. The logs you just found will be really helpful. We need all the data we can get to help figure out what's going on.", "What should I do next?", 'a');
			a = part("Hmm, just keep hacking __ __ nodes to see if you can ___ some more logs. Watch out for corporate ___ and don't forget what you learned using bit-man. L8r.", "Later.", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'ph29';
	Links = {'lm33'};
	PlaceId = 'L29';
	Name = "Clinical Trial Database";
	Mission = "Aeacus asked for the logs of this node to find a pattern in the corrupt script attacks. Collect the logs to succeed.";
	Conversation = conversation{
		User = 'disarray';
		Parts = {
			main = part("Hello again.", "Hello.", 'a');
			a = part("Nice work on that last node. I was just coming to check it out myself. Guess the work here is done.", "What do you mean?", 'b');
			b = part("What do I mean? Just took care of the rest of the nodes in this area. Everything's totally clean.", "Are you sure about that?", 'c');
			c = part("Look kid, I'm a much better hacker than you are. If I tell you that they're clean, they're clean. Check you later.", "See you around.", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'lm33';
	Links = {'wz3', 'pd34'};
	PlaceId = 'L33';
	Name = "Toy Properties";
	Mission = "Dignity said he took care of this node, but security systems seem unusually active...";
	Conversation = conversation{
		User = 'superphreak';
		Parts = {
			main = part("Wow. Good thing you checked out this node. This whole area's a mess.", "What do you mean?", 'a');
			a = part("From what I can tell, the problem with program corruption is escalating.", "Who's doing it?", 'b', "What do we do?", 'b');
			b = part("I'm not sure, but there's got to be some useful information in those logs you picked up. Since I can't seem to stay on the net for five minutes, I'll keep analyzing those logs.", "What about me?", 'c');
			c = part("Work your way across these nodes. Somebody's hiding something from us. See if you can find out what it is. Welcome to the big time, newbie. Send me those logs so I can get starcted. Ready to recieve data.", "Send Log Data", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'wz3';
	Links = {};
	Warez = {
		hack3 = 3500;
		golemclay = 3000;
		blackwidow = 2000;
		mandelbug = 3000;
		buzzbomb = 3500;
		fiddle = 2400;
		seeker2 = 2500;
		mobiletower = 1800;
		sat = 3500;
		ballista = 3000;
		clog2 = 2000;
		tdulux = 1750;
	}
}

node{
	Id = 'pd34';
	Links = {'ph35'};
	PlaceId = 'L34';
	Name = "Offshore Transactions";
	Mission = "Firewalls and heavy defenses are keeping all users out. Disable the defenses.";
	Conversation = conversation{
		User = 'disarray';
		Parts = {
			main = part("Hey. What are you doing here? Didn't I tell you I cleaned this area up already?", "Well, there are still problems.", 'a', "Did you miss that last databattle?", 'a');
			a = part("Why don't you scram and let me take care of these nodes?", "Aeacus told me to check it out.", 'b', "Looks like you need some help!", 'b');
			b = part("Hey, if you want, go ahead, keep hacking. You won't get very far before security beats you back to level one. Contact me when you get stuck.", "Close", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'ph35';
	Links = {'ph36'};
	PlaceId = 'L35';
	Name = "Vaccine Database";
	Mission = "Firewalls and heavy defenses are keeping all users out. Disable the defenses.";
	Conversation = conversation{
		User = 'superphreak';
		Parts = {
			main = part("___ __ __ _ ___ Man, it's hard to stay connected. Nice work so far.", "What did you find out so far?", 'a', "Thanks.", 'a');
			a = part("I used a neural net sequence to cross reference all of the logs you've given me so gar. I was able to trace the programs back to the node that originally spawned them onto the net.", "Any idea who's behind it?", 'b');
			b = part("No idea. It's an unknown node in a high security level.", "So what should I do?", 'c');
			c = part("You're doing an excelent job. Keep on Hacking and tell me what you find. I'll load the new node on your netmap now.", "Ready to receive net data", 'end');
		};
		Function = functionRevealNode('end');
	}
}

node{
	Id = 'ph36';
	Links = {};
	PlaceId = 'L36';
	Name = "HMO Proceedure Management";
	Mission = "This node contains the security level 4 access codes. Capture the access codes.";
	Conversation = conversation{
		User = 'superphreak';
		Parts = {
			main = part("Excelent work. Welcome to level four.", "Thanks.", 'a');
			a = part("No problem. You earned it. Now try to get to that mysterious node I showed you. Something big is going down, and it looks like it's up to you to stop it.", "Do you think I can handle that?", 'b');
			b = part("I know you can. And smart is counting on you. Get ready for the level four upgrade, and good luck.", "Ready for security upgrade.", 'end');
		};
		Function = functionUpgradeSecurity(4);
	}
}

node{
	Id = 'lm22';
	Links = {'ca23', 'ca24'};
	PlaceId = 'L22';
	Name = "Club Centre";
	Mission = "This node has a security bug that locked down its internal network. Defeat the security scripts.";
	Conversation = conversation{
		User = 'wintermutant';
		Parts = {
			main = part("Hey dude, sorry to interrupt an elite smart angent like yourself. Is it okay if we chat for a second.", "Um, who are you?", 'a');
			a = part("Oh, I'm sort of a hacker too. I mean, I'd like to be one. I hope you don't mind tat I've been checking out your radical runs. Taking care of the DR Donut problems?", "What Dr. Donut problems?", 'b');
			b = part("I guess that's way beneath your radar. Some hacker screwed around with their systems and now they're all buggy.", "Could you tell me where the node is?", 'c', "give me the info about the node", 'c');
			c = part("Sure, I'll send it to you right away, I know I've got it around here somewhere, hang on a sec...", "I'm waiting.", 'd', "take your time...", 'd');
			d = part("Got it! I'm uploading the node on to your netmap now. Kewl talkin to you. CuL8R.", "Ready to receive net data", 'end');
			e = part("", "", 'end');
		};
		Function = functionRevealNode('dr31');
	}
}

node{
	Id = 'ca23';
	Links = {'wz2'};
	PlaceId = 'L23';
	Name = "Inventory Archives";
	Mission = "This node's security is hyperalert after a recent hack job. Disable it to proceed to the warez node.";
	Conversation = conversation{
		User = 'superphreak';
		Parts = {
			main = part("Hey newbie. Still working on getting smart on its feet. What are you up to?", "Do you know Wintermutant?", 'a');
			a = part("He's a good kid. By the way, that node up there is network city. And there are a couple more warez nodes hidden out on the net.", "Nice.", 'b');
			b = part("And while you're looking at software, don't just load up on attack programs. You should check out some meta programs like metic and turbo. There may come a time when you need to boost up your hack to handle an _____ enemy. ___ oops gotta go.", "Done", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'wz2';
	Links = {};
	Warez = {
		hack2 = 1500;
		golemmud = 1200;
		wolfspider = 750;
		seeker = 1000;
		tower = 1000;
		medic = 1000;
		turbo = 1000;
	};
}

node{
	Id = 'ca24';
	Links = {'dr25', 'lm26'};
	PlaceId = 'L24';
	Name = "Communications Hub";
	Mission = "This node is reporting corrupted script problems similar to the Pharmhaus intrusions. Terminate the corrupted scripts.";
	Conversation = conversation{
		User = 'joana';
		Parts = {
			main = part("Hello, Agent. I suppose I should thank you for assisting my company.", "All in a day's work.", 'a');
			a = part("We have a problem with one of our nodes.", "What's in it for me?", 'b');
			b = part("An experimental piece of software, along with whatever credits you can find during the mission.", "What is the mission?", 'c');
			c = part("Use a backdoor through the ped feduciary node to access our sysadmin archives. The archives node lock down after an aborted crash attempt, and we needa file from there immediately.", "Sure thing.", 'd', "Let me think about it.", 'd');
			d = part("I'm adding the archives node to your netmap. I'll contact you when you are in the vicinity of the node.", "Ready to receive net data", 'end');
		};
		Function = functionRevealNode('ca312');
	}
}

node{
	Id = 'lm26';
	Links = {'lm27'};
	PlaceId = 'L26';
	Name = "Print Assets";
	Mission = "Dignity wants me to deactivate the security at this node.";
	Conversation = conversation{
		User = 'wintermutant';
		Parts = {
			main = part("Hey dude. It's me again.", "Hey Minish.", 'a', "What's up?", 'a');
			a = part("Kewl Battle! Hey, I was lookin over some of the nodes you've been through and I found something funny. Whoever did the dack job through pharmhaus left somethin behind.", "Left what behind?", 'b');
			b = part("Some kind of wierd program. I couldn't get a good luck at it cause it disappeared before I could catch it.", "Where was it from?", 'c');
			c = part("I'm not sure. Maybe the same hacker that's been corrupting these nodes. I saw a link to something called nightfall. I'll keep checking the logs and see if I can find anything else.", "Thanks a lot.", 'end', "You do that.", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'lm27';
	Links = {};
	PlaceId = 'L27';
	Node = "Banané System";
	Mission = "This node contains the security level 3 access codes. Capture the access codes.";
	Conversation = conversation{
		User = 'superphreak';
		Parts = {
			main = part("Nice work. You keep going at this rate, you may just be an elite agent yet. Welcome to level 3.", "Thanks. How's the smart system?", 'a');
			a = part("Still a wreck. We're going off-line like every few minutes. It's all I can do to keep the communications.", "Hang in there.", 'b');
			b = part("I'll do my best. With all these corrupt programs squirming around, I've got a feeling something big is going on.", "Like what?", 'c');
			c = part("Like something that's going to damage the whole net. Keep looking around. I'll upgrade you to security level three now.", "Ready to receive security upgrade", 'end');
		};
		Function = functionUpgradeSecurity(3);
	}
}

node{
	Id = 'dr25';
	Links = {'dr28'};
	PlaceId = 'L25';
	Name = "Supply Management";
	Mission = "This is one of the malfunctioning nodes Minish mentioned. Disable the security to repair the damage.";
	Conversation = conversation{
		User = 'disarray';
		Parts = {
			main = part("Still up out there?", "Hey Dignity.", 'a', "Still here.", 'a');
			a = part("Of course I'm still online. Nothing this puny is going to take a hacker of my skills down. Anyway, I'e been digging around and I found something. Do you have time to check it out?", "I don't know, what is it?", 'b', "Sure.", 'b');
			b = part("Smart has a special program that would really help with the crashing and all. To get it running I need a couple of files that are hidden in some corporate nodes around here, two nodes to be exact.", "What's the program?", 'c');
			c = part("Network software, it's complicated. Anyway, the program is encrypted, so I'm going to need a lot of time to decipher it. Can you shut down security so I can get in there and concentrate on the real work?", "Sure thing.", 'd', "Let me think about it.", 'd');
			d = part("Okay. You can get to the nodes through this one. They're all level three, so you'll need to get the access code for that level first.", "Got it.", 'e');
			e = part("I'll load the first node onto your map now. Hack that to access the nodes that contain the program. I'll catch up with you when you've taken care of the security. Later newbie.", "Later.", 'end');
		};
		Function = functionRevealNode('lm39');
	}
}

node{
	Id = 'dr28';
	Links = {'pd32', 'dr31'};
	PlaceId = 'L28';
	Name = "Franchise Office";
	Mission = "This is one of the malfunctioning nodes Minish mentioned. Disable the security to repair the damage.";
	Conversation = conversation{
		User = 'superphreak';
		Parts = {
			main = part("Ok, I'm finally back on the net. Hey, news on the smart bug.", "Go for it.", 'a');
			a = part("Looks like it must have been an inside job. Just happened too quickly. The hacker had the passwords.", "Do you have any idea who's responsible?", 'b', "So what do we do?", 'b');
			b = part("A couple ideas, but nothing definite. I'll keep woring on it. Still, as the only smart angent left, you'll have to handle the net problems.", "Actually, another agent wrote me.", 'c', "What about Dignity?", 'd');
			c = part("Hold on, Smart's down. Who was the agent?", "His name was Dignity.", 'd');
			d = part("If you're talking about who I think you are, that's bad news. I was training an agent named disarray a couple of months ago. He got thrown out for being the reckless and greedy loser that he is. Don't trust a word he says.", "What do we do about him?", 'e', "He asked me to do a mission.", 'e');
			e = part("__ __ __ don't have a lot of time left. I'll start tracing disarray. Go along with his idea so I can see what he's doing. On, and, __ __ __ __.", "Close", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'pd32';
	Links = {'pd310', 'ca311'};
	PlaceId = 'L32';
	Name = "Fiduciary Node";
	Mission = "This node is a backdoor entrance to the Celular Automa S.A. Archives. Disable the security to proceed.";
	Conversation = conversation{
		User = 'spinner';
		Parts = {
			main = part("Hey, agent. You've been pretty hot lately. Looking for some extra work?", "I'm already on a couple of missions.", 'a', "What's the operation?", 'a');
			a = part("For a hacker of your talent, this should be a breeze. All you have to do is rescue some files from a PED exec who stole them.", "What do I get out of this?", 'b', "Where's the node?", 'b');
			b = part("Pharmhaus is offering a nice credit bonus as a reward. And the best part is, the node is the PED node that you just opened, the re-insurance database.", "Let me think about it.", 'c', "I'm in.", 'c');
			c = part("You know where to go. I'll contact you when you're finished.", "Close", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'pd310';
	Links = {};
	PlaceId = 'L310';
	Name = "Re-Insurance Database";
	Mission = "There is a large reward to recover stolen files from a P.E.D. executive. He hid the files in this node, cature them.";
	Conversation = conversation{
		User = 'spinner';
		Parts = {
			main = part("As always, an excelent job from the best agent smart's got. Here are the credits they promised. Keep in touch.", "Ready to receive credits.", 'end');
		};
		Function = functionGetCredits(5000);
	}
}

node{
	Id = 'ca311';
	Links = {'ca312'};
	PlaceId = 'L311';
	Node = "Sub-Station Gamma";
	Mission = "This node is the gateway to the Celular Automa Sysadmin Archives. Disable the security to proceed.";
	Conversation = conversation{
		User = 'joana';
		Parts = {
			main = part("I can see you're about to enter our sysadmin archives. Thank you for handling this mission. I wanted to give you some advice.", "Go ahead.", 'a');
			a = part("If you are successful, we will reward you with a copy of some new software that we just developed. I'm told that's the proper way to motivate people such as yourself.", "Thanks, I guess.", 'b');
			b = part("Good luck agent.", "Over and out.", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'ca312';
	Links = {};
	PlaceId = 'L312';
	Name = "Sys-Admin Archives";
	Mission = "This node is currently locked down, and Celular Automa needs a file from it. Retrieve the file to win a new script.";
	Conversation = conversation{
		User = 'joana';
		Parts = {
			main = part("Well done, agent. You have accomplished your task, and I am happy to fulfill the terms of our argeement. Prepare to receive the software we promised.", "Ready to receive software", 'end');
		};
		Function = functionGetProgram('hog');
	}
}

node{
	Id = 'dr31';
	Links = {'dr37', 'lm39', 'dr38'};
	PlaceId = 'L31';
	Name = "Market Research";
	Mission = "This node connects to the two nodes containing the program Dignity wanted. Disable the security to proceed to them.";
	Conversation = conversation{
		User = 'wintermutant';
		Parts = {
			main = part("Hey partner! You really cleaned up those DR. D Nodes!", "Thanks Minish.", 'a', "What's up?", 'a');
			a = part("I went sneaking around there after you left, and guess what? I found more traces of that wierd program.", "Any idea where it came from?", 'b', "Know what it's for?", 'b');
			b = part("Totally! The traces had the same nightfall signature, so I did this special kind of search I made up, and I found something.", "What did you find?", 'c');
			c = part("A nice piece of software somebody made. It's stashed away deep in sector 4 in a luck monkey node, not that they know it's there of course.", "Did you find anything else?", 'd');
			d = part("Not yet, but I'm gonna keep searching for the nightfall hacker and see what else I find + I'll put the monkey node up on your map. C U partner.", "Done", 'end');
		};
		Function = functionRevealNode('lm43');
	}
}

node{
	Id = 'dr37';
	Links = {};
	PlaceId = 'L37';
	Name = "Flavor Evaluation Lab";
	Mission = "Half of the program Dignity wants is here. Collect the keys to temporarily shut down the node's surveillance and allow Dignity access.";
	Conversation = conversation{
		User = 'superphreak';
		Parts = {
			main = part("Hey, I can see which program disarray's getting. It has to do with rapid sumiltaneous network communication - Floodinga huge number of nodes at once.", "Why would he want to do that?", 'a');
			a = part("I don't know. What would disarray be doing that would affect the whole net? He'd still have to have hacked every node individually to be able to do anything.", "What's the next step?", 'b');
			b = part("Keep following him, and watch what he says. I'll keep up my trace and get back to you when I have more. L8r.", "Done", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'lm39';
	Links = {};
	PlaceId = 'L39';
	Name = "Lucky Jungle Central";
	Mission = "Half of the program Dignity wants is here. Collect the keys to temporarily shut down the node's surveillance and allow Dignity access.";
	Conversation = conversation{
		User = 'disarray';
		Parts = {
			main = part("Terrific. Thanks for handling the security. I could've done it myself, but that saved me some time.", "No problem.", 'a');
			a = part("Well, once the program is put together, everything will be set for smart, see you soon.", "Close", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'dr38';
	Links = {'lm41'};
	PlaceId = 'L38';
	Name = "Beverage Subsidiaries";
	Conversation = conversation{
		User = 'spinner';
		Parts = {
			main = part("Hey, pal. Got another job for you?", "Who is it for?", 'a', "What is the job?", 'b');
			a = part("It's PED, they always offer sweet credit rewards.", "And the job?", 'b');
			b = part("A memory unit in their privileged accounts node went bluescreen and needs to be shut down, quietly. Should be a walk in the park for someone with your ability.", "I'll think about it.", 'c', "Sign me up.", 'c');
			c = part("I'll put the node up on your map.", "Ready to receive net data", 'end');
		};
		Function = functionRevealNode('pd48'); -- TODO:
	}
}

node{
	Id = 'lm41';
	Links = {'wz4', 'dr42'};
	PlaceId = 'L41';
	Name = "Assimilation Timetable";
	Mission = "An enemy hacker has heightened the security in this node and locked out all users. Defeat these scripts to proceed.";
	Conversation = conversation{
		User = 'wintermutant';
		Parts = {
			main = part("Wow, you're level 4! That's radical!! I knew you'd made it!", "Thanks Minish.", 'a', "What's up?", 'a');
			a = part("I found something big! I finished my nightfall search and I found another secret stash!", "What did you find?", 'b');
			b = part("Some kind of access codes for a really tight private security set-up. It's hidden away in the pharmhaus proprietary research node. Nasty defense software.", "Okay", 'c');
			c = part("I'm putting the node up on your map now. I tired to get them myself, but I got rejected before I could even boot u. I'ts definitely nightfall though.", "Great work Minish.", 'd', "I'll handle it from here.", 'd');
			d = part("Thanks a lot. Kick butt! go smart!", "Close", 'end');
		};
		Function = functionRevealNode('ph49');
	}
}

node{
	Id = 'wz4';
	Links = {};
	Warez = {
		golemstone = 5000;
		tarantula = 3500;
		heisenbug = 4000;
		logicbomb = 3500;
		sumo = 4500;
		seeker3 = 4500;
		lasersat = 5000;
		catapult = 4000;
		clog3 = 3500;
		guru = 4500;
	}
}

node{
	Id = 'dr42';
	Links = {'lm43', 'pd44'};
	PlaceId = 'L42';
	Name = "Recipe Database";
	Mission = "The nightfall hacker has heightened the security in this node and locked out all users. Defeat these scripts to proceed.";
	Conversation = conversation{
		User = 'superphreak';
		Parts = {
			main = part(" __ __ ___ It's __ harder and harder to __ __ but I've got important information __ __ ready?", "Go ahead.", 'a');
			a = part("I've finished my trace on Dignity. Surprise surprise, he's the source __ __ __ corrupt programs and security screw-ups. Disarray's been infiltrating __ __ __ the web. I don't know why.", "What about the program he took?", 'b');
			b = part("__ __ A well-guarded communications hub. He's using the stolen script __ __ access to all the nodes on the net __ __ I just don't understand the point. Any ideas?", "Does Nightfall mean anything to you?", 'c');
			c = part("Nightfall? What does that mean?", "Dignity's secret project?", 'd');
			d = part("Nightfall... that's it! Disarray's __ _ use his Nightfall script to black out the net. Total midnight! __ __ __ crash the entire system! You have to stop him!!", "How?", 'e');
			e = part("Get ___ __ his personal node, defeat the secuity, __ deactivate the Nightfall script. And hurry, __ __ have much time!", "I'm on it.", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'lm43';
	Links = {};
	PlaceId = 'L43';
	Name = "Film Properties";
	Mission = "Minish found an experimental piece of software here. Retrieve the script before the corrupted programs left to protect it disconnect you.";
	Conversation = conversation{
		User = 'wintermutant';
		Parts = {
			main = part("That battle was sooo kewl! You rock! And managed to retrieve that experimental software.", "How does it work?", 'a');
			a = part("The program should be ready to use, just plug and play. Oh, one more thing. I've been scanning these nodes. Be sure to get some level four software and be ready for some nasty security. Go get'em partner.", "Ready to receive software", 'end');
		};
		Function = functionGetProgram('wizard');
	}
}

node{
	Id = 'pd44';
	Links = {'ph45'};
	PlaceId = 'L44';
	Name = "R&D Backup";
	Mission = "The nightfall hacker has heightened the security in this node and locked out all users. Defeat these scripts to proceed.";
	Conversation = conversation{
		User = 'joana';
		Parts = {
			main = part("Agent, I'm glad I found you. We've got a big problem here.", "What is it?", 'a');
			a = part("We've found an undocumented node rerouting data to our system core. A security breach at this level is completely unacceptable. What are you going to do about it?", "I'm a little bit busy right now.", 'b');
			b = part("If you can bypass the security we'll set up a link to the undocumented node for you. That should give you access to the node causing this mess.", "Sure.", 'c');
			c = part("Be warned agent, the security measures in our core are particularly fierce. The node is right up ahead.", "Ready to recieve net data.", 'end');
		};
		Function = functionRevealNode('ph45');
	}
}

node{
	Id = 'ph45';
	Links = {'end', 'pd46'};
	PlaceId = 'L45';
	Name = "System Core";
	Mission = "Deactivate the security system here and allow Are92 to set up a link to Dignity's headquarters.";
	Conversation = conversation{
		User = 'joana';
		Parts = {
			main = part("Congradulations, agent. You've opened up our system. As you can observe, we've established a link to that mysterious node. There is a problem however.", "What's wrong?", 'a');
			a = part("The node has an unknown security level. We don't have the access codes to reach it. Without those codes, the node is inaccessable.", "Don't worry, I'll get the codes.", 'b');
			b = part("We'll maintain the current link for you. Good luck and thank you.", "Done", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'pd46';
	Links = {'pd47'};
	PlaceId = 'L56';
	Name = "Executive Protocol";
	Mission = "Dignity has filled this node with corrupt scripts set to attack anyone who logs in. Terminate these corrupted scripts to proceed.";
	Conversation = conversation{
		User = 'disarray';
		Parts = {
			main = part("Hello there, smart amateur.", "What do you want?", 'a');
			a = part("What's the matter? No time to chat with an old smart buddy?", "Smart kicked you out.", 'b');
			b = part("clearly their loss. So I guess by now you know the whole nightfall story, huh?", "Why are you trying to crash the net?", 'c');
			c = part("Simple. The nightfall software I set up is going to take every single node off-line. That means I will control who gets access to the net and who doesn't.", "So?", 'd');
			d = part("People will be begging me to get back on-line. And I'll let them, just as long as they're willing to pay for the privelage. I'll make billions. What can I say - It's a brilliant plan.", "That will never happen.", 'e');
			e = part("Actually, it will. You don't have the codes to access my private node, and even if you did, you'd never beat my security. You're just a pathetic newbie. So why don't you stop wasting your time fighting me and go save up your credits to pay me off later?", "You're going down Dignity!", 'f');
			f = part("Suit yourself. It'll be fun to show you just how inferior you are. L8r loser.", "We'll see about that.", 'end');		
		};
		Function = nil;
	}
}

node{
	Id = 'end';
	Links = {};
	PlaceId = 'L5';
	Name = "Unknown Node";
	Mission = "Dignity's headquarters. Defeat all of his security to disable the nightfall scripts and prevent midnight.";
	Conversation = conversation{
		User = 'superphreak';
		Parts = {
			main = part("Awesome job! That's how it's done!", "Thanks.", 'a');
			a = part("You stood up for smart when everything was on the line and saved the net from complete shutdown, at least for now. I'd say that makes you an elite agent.", "You're not so bad yourself.", 'b');
			b = part("Dignity was so arrogant that he never disguised his upload location. Once nightfall was destroyed we traced his signal back to his home. Smart agents are on their way right now to apprehend him.", "What a loser.", 'c');
			c = part("It turns out he was working on this plan for years. All the time disarray was a smart agent, he was really just casing the network in preparation for his master plan. But that's all over now.", "So what now?", 'd');
			d = part("Well, until smart has another crisis for us to solve, take a break. You earned it. Kick back, relax, play some video games. :) cul8r.", "Who has time for video games?", 'end');
		};
		Function = functionEndNightfall();
	}
}

node{
	Id = 'ph410';
	Links = {};
	PlaceId = 'L410';
	Name = "Bonus Node";
	Mission = "Up for a challenge?";
	--[[Conversation = conversation{
		User = '';
		Parts = {
			main = part("", 'a');
			a = part("", "", 'b');
			b = part("", "", 'c');
			c = part("", "", 'd');
			d = part("", "", 'e');
			e = part("", "", 'end');
		};
		Function = nil;
	}]]
}

node{
	Id = 'pd47';
	Links = {'pd48', 'ph49', 'ph410'};
	PlaceId = 'L47';
	Name = "Treasury Funds";
	Mission = "Dignity has filled this node with corrupt scripts set to attack anyone who logs in. Terminate these scripts to proceed.";
	Conversation = conversation{
		User = 'superphreak';
		Parts = {
			main = part("Hey, I guess you found out __ __ get the access codes for disarray's node. Good work. I'm looking into how to stall the nightfall software. Gou go get the ___ codes and then de-activate the program. But first __ __ __ ___ what I know about this jerk.", "Tell me.", 'a');
			a = part("I'm sure disarray __ boobytrapped the node that has his access codes. I don't know __ __ __ when you access that node.", "Okay.", 'b');
			b = part("If you've got any unfinished missions, complete them to __ __ extra cash. ___ __ back to the L4 warez node and stock up on scripts.", "Got it.", 'c');
			c = part("Dignity's tactics: I know that _______ __ coward and will use ranged scripts to keep you ___ __ distance. Be prepared to see lots of radar and sonar along with __________ _____ ___ fought. I also know he deletes memory cells as a defense, so be sure ___", "Thanks.", 'd');
			d = part("no problem. Did all of that make sense? __ ___ ____ pretty soon there will be no turning back.", "I'm ready.", 'e');
			e = part("Alright, I'll be off-line for a while. Good luck ______ ___ codes, and be sure __ show disarray what it means to mess with smart.", "I'll do my best.", 'end');
		};
		Function = nil;
	}
}

node{
	Id = 'pd48';
	Links = {};
	PlaceId = 'L48';
	Name = "Privileged Accounts";
	Mission = "P.E.D. has offered a large credit reward to the agent who can destroy a malfunctioning memory cell. Eliminate the corrupted scripts.";
	Conversation = conversation{
		User = 'spinner';
		Parts = {
			main = part("Great work, agent. P.E.D. thanks you. So, mind letting little old Vexedly know what all the big, bad news is about?", "Later, I've got to work.", 'a');
			a = part("No problem, no problem. Duty first and all that. Just don't forget who's been your friend, okay? Here are you credits. Ciao, buddy.", "Ready to receive credit transfer", 'end');
		};
		Function = functionGetCredits(2000);
	}
}

node{
	Id = 'ph49';
	Links = {};
	PlaceId = 'L49';
	Name = "Proprietary Research";
	Mission = "This node contains the access codes to a private security level. Capture the access codes to access Dignity's headquarters.";
	Conversation = conversation{
		User = 'disarray';
		Parts = {
			main = part("Bravo, Bravo! You have honestly suprised me. I never thought a newbie like you could get this far.", "You're next Dignity!", 'a');
			a = part("I'm affraid not. You see, you're too late. My grand finale is already at hand. Is everybody ready? I ope you're not affraid of the dark. Three, Two, One, nightfall!", "NO!", 'end');
		};
		Function = functionBeginNightfall();
	}
}

function Netmap:Generate()
	for id, node in pairs(Netmap.ById) do
		local part = workspace:FindFirstChild(id)
		if not part then
			part = Instance.new('Part')
			part.Size = Vector3.new(2, 2, 2)
			part.Name = id
			if node.Level == 1 then
				part.Color = Color3.new(0, 1, 0)
			elseif node.Level == 2 then
				part.Color = Color3.new(0, 0, 1)
			elseif node.Level == 3 then
				part.Color = Color3.new(0, 1, 1)
			elseif node.Level == 4 then
				part.Color = Color3.new(1, 1, 0)
			elseif node.Level == 4 then
				part.Color = Color3.new(1, 0, 0)	
			end
			part.Position = Vector3.new(math.random(-5, 5), 2, node.Level * 2)
			part.Parent = workspace
		end
		if not part:FindFirstChild('Attachment') then
			local attachment = Instance.new('Attachment')
			attachment.Name = 'Attachment'
			attachment.Parent = part
		end
	end
	for id, node in pairs(Netmap.ById) do
		local part = workspace[id]
		for _, connectedTo in pairs(node.Links) do
			local beam = workspace.Beams:FindFirstChild(id..connectedTo)
			if not beam then
				beam = workspace.Beam:Clone()
				beam.Attachment0 = part.Attachment
				beam.Attachment1 = workspace[connectedTo].Attachment
				beam.Parent = workspace.Beams
			end
		end
	end
end

return Netmap

























