if RequiredScript == "lib/managers/platformmanager" then
	core:module("PlatformManager")

	local set_rich_presence_original = WinPlatformManager.set_rich_presence
	function WinPlatformManager:set_rich_presence(name, ...)
		set_rich_presence_original(self, name or self._current_rich_presence, ...)

		if SystemInfo:distribution() == Idstring("STEAM") then
			-- Default config
			local display = "#raw_status" --"#DisplayMe"
			local group_key = ""
			local group_count = ""
			local group_max = ""

			local game_state = "menu"
			local game_mode = ""
			local game_heist = ""
			local game_heistday = ""
			local game_difficulty = ""

			if self._current_rich_presence ~= "Idle" then
				if Global.game_settings.permission == "private" and not Global.game_settings.single_player then
					game_state = "private"
				else
					-- Handle Steam RP Grouping
					if not Global.game_settings.single_player then
						if managers.network.matchmake and managers.network.matchmake.lobby_handler then
							group_key = managers.network.matchmake.lobby_handler:id()
						end

						local session = managers.network:session()
						group_count = tostring(session and #session:all_peers() or 1)
						group_max = tostring(_G.tweak_data.max_players)
					end

					-- Determine game state
					if _G.game_state_machine and (_G.game_state_machine:current_state_name() == "menu_main" or _G.game_state_machine:current_state_name() == "ingame_lobby_menu") then
						game_state = "lobby"
					elseif self._current_rich_presence == "SPEnd" or self._current_rich_presence == "MPEnd" then
						game_state = "payday"
					else
						game_state = "playing"
					end

					-- Popululate gamemode, heist and difficulty
					if managers.crime_spree and managers.crime_spree:is_active() then		-- Crime Spree
						game_mode = "crime_spree"
						game_heist = self:get_current_level_id()
						local spree_lvl = managers.crime_spree:server_spree_level()
						game_difficulty = spree_lvl and managers.money:add_decimal_marks_to_string(tostring(spree_lvl)) or "(N/A)"
					elseif managers.skirmish and managers.skirmish:is_skirmish() then		-- Holdout
						game_mode = "skirmish"
						game_heist = self:get_current_level_id()
						game_difficulty = string.format("%i/%i", managers.skirmish:current_wave_number() or 1, tweak_data and #tweak_data.skirmish.ransom_amounts or 9)
					elseif managers.job:has_active_job() then								-- Heists
						game_heist = self:get_current_job_id()

						if #(managers.job:current_job_chain_data() or {}) > 1 then
							game_mode = "heist_chain"
							game_heistday = tostring(managers.job:current_stage() or "")
						else
							game_mode = "heist"
						end

						game_difficulty = tweak_data and tweak_data:index_to_difficulty(managers.job:current_difficulty_stars() + 2) or Global.game_settings.difficulty or "easy"
					else
						-- Overwrite game state if nothing is selected
						game_state = "lobby_no_job"
					end
				end
			end

			-- Send our data to Steam
			Steam:set_rich_presence("steam_display", display)		-- Currently not usable, only Overkill can setup required localized strings here...
			Steam:set_rich_presence("steam_player_group", group_key)
			Steam:set_rich_presence("steam_player_group_size", group_count)
			Steam:set_rich_presence("max_peers", group_count)

			Steam:set_rich_presence("game:state", game_state)
			Steam:set_rich_presence("game:mode", game_mode)
			Steam:set_rich_presence("game:heist", game_heist)
			Steam:set_rich_presence("game:heist_day", game_heistday)
			Steam:set_rich_presence("game:difficulty", game_difficulty)

			Steam:set_rich_presence("status", self:build_status_string(display, game_state, game_mode, game_heist, game_heistday, group_count, group_max, game_difficulty))
		end
	end

	local suffixList = {
		"_prof$",
		"_day$",
		"_night$",
		"_wrapper$",
		"^skm_"
	}
	local ignoreSuffix = {
		["election_day"] = true
	}

	function WinPlatformManager:get_current_job_id()
		local job_id = managers.job:current_job_id()

		if job_id and not ignoreSuffix[job_id] then
			for _, suffix in ipairs(suffixList) do
				job_id = job_id:gsub(suffix, "")
			end
		end

		return job_id or "UNKNOWN"
	end

	function WinPlatformManager:get_current_level_id()
		local level_id = Global.game_settings.level_id

		if level_id and not ignoreSuffix[level_id] then
			for _, suffix in ipairs(suffixList) do
				level_id = level_id:gsub(suffix, "")
			end
		end

		return level_id or self:get_current_job_id()
	end

    function WinPlatformManager:build_status_string(display, state, mode, heist, day, peercount, maxpeer, difficulty)
		local tokens = {
			["#raw_status"] =				"{#State_%game:state%}",

			-- Game states
			["#State_menu"] =				"At the main menu",
			["#State_private"] =			"In a private lobby",
			["#State_lobby_no_job"] =		"In a lobby %steam_player_group_size%/%max_peers%",
			["#State_lobby"] =				"Lobby: {#Mode_%game:mode%}",
			["#State_playing"] =			"Playing: {#Mode_%game:mode%}",
			["#State_payday"] =				"Payday: {#Mode_%game:mode%}",

			-- Game modes
			["#Mode_crime_spree"] =			"[CS] {#Level_%game:heist%} %steam_player_group_size%/%max_peers% (Lvl. %game:difficulty%)",
			["#Mode_skirmish"] =			"[HO] {#Level_%game:heist%} %steam_player_group_size%/%max_peers% (Wave %game:difficulty%)",
			["#Mode_heist"] =				"{#Job_%game:heist%} %steam_player_group_size%/%max_peers% ({#Difficulty_%game:difficulty%})",
			["#Mode_heist_chain"] =			"{#Job_%game:heist%}, Day:%game:heist_day% %steam_player_group_size%/%max_peers% ({#Difficulty_%game:difficulty%})",

			-- Difficulties
			["#Difficulty_easy"] =			"EASY",
			["#Difficulty_normal"] =		"NORMAL",
			["#Difficulty_hard"] =			"HARD",
			["#Difficulty_overkill"] =		"VERY HARD",
			["#Difficulty_overkill_145"] =	"OVERKILL",
			["#Difficulty_easy_wish"] =		"MAYHEM",
			["#Difficulty_overkill_290"] =	"DEATHWISH",
			["#Difficulty_sm_wish"] =		"DEATH SENTENCE",

			["#Job_short"] = 				"The Basics",					-- Tutorials
			["#Job_short1"] = 				"Flash Drive - Stealth",
			["#Level_short1_stage1"] = 		"Stealth - Flash Drive",
			["#Level_short1_stage2"] = 		"Stealth  - Erasing History",
			["#Job_short2"] = 				"Get The Coke - Loud",
			["#Level_short2_stage1"] = 		"Loud - Get The Coke",
			["#Level_short2_stage2b"] = 	"Loud - Plan B",
			["#Job_chill"] = 				"Safe House",					-- Safe House
			["#Level_chill"] = 				"Safe House",
			["#Job_chill_combat"] = 		"Safe House Raid",
			["#Level_chill_combat"] = 		"Safe House Raid",
			["#Job_safehouse"] = 			"The Safe House",
			["#Level_safehouse"] = 			"The Safe House",
			["#Job_haunted"] = 				"Safe House Nightmare",
			["#Level_haunted"] = 			"Safe House Nightmare",
			["#Job_branchbank"] = 			"Bank Heist: Random",			-- Bank Heist
			["#Job_branchbank_gold"] = 		"Bank Heist: Gold",
			["#Job_branchbank_deposit"] = 	"Bank Heist: Deposit",
			["#Job_branchbank_cash"] = 		"Bank Heist: Cash",
			["#Level_branchbank"] = 		"Bank Heist",
			["#Job_arm"] = 					"Transport Heists",				-- Transport Heists
			["#Job_arm_und"] = 				"Transport: Underpass",
			["#Level_arm_und"] = 			"Transport: Underpass",
			["#Job_arm_hcm"] = 				"Transport: Downtown",
			["#Level_arm_hcm"] = 			"Transport: Downtown",
			["#Job_arm_cro"] = 				"Transport: Crossroads",
			["#Level_arm_cro"] = 			"Transport: Crossroads",
			["#Job_arm_for"] = 				"Transport: Train Heist",
			["#Level_arm_for"] = 			"Transport: Train Heist",
			["#Job_arm_fac"] = 				"Transport: Harbor",
			["#Level_arm_fac"] = 			"Transport: Harbor",
			["#Job_arm_par"] = 				"Transport: Park",
			["#Level_arm_par"] = 			"Transport: Park",
			["#Job_watchdogs"] = 			"Watchdogs",					-- Watchdogs
			["#Level_watchdogs_1"] = 		"Truck Load",
			["#Level_watchdogs_2"] = 		"Boat Load",
			["#Job_watchdogs_stage2"] = 	"Boat Load",
			["#Level_watchdogs_stage2"] = 	"Boat Load",
			["#Job_election_day"] = 		"Election Day",					-- Election day
			["#Level_election_day_1"] = 	"Right Track",
			["#Level_election_day_2"] = 	"Swing Vote",
			["#Level_election_day_3"] = 	"Breaking Ballot",
			["#Job_alex"] = 				"Rats",							-- Rats
			["#Level_alex_1"] = 			"Cook Off",
			["#Level_alex_2"] = 			"Code for Meth",
			["#Level_alex_3"] = 			"Bus Stop",
			["#Job_framing_frame"] = 		"Framing Frame",				-- Framing Frame
			["#Level_framing_frame_1"] = 	"Art Gallery",
			["#Level_framing_frame_2"] = 	"Train Trade",
			["#Level_framing_frame_3"] = 	"Framing",
			["#Job_firestarter"] = 			"Firestarter",					-- Firestarter
			["#Level_firestarter_1"] = 		"Airport",
			["#Level_firestarter_2"] = 		"FBI Server",
			["#Level_firestarter_3"] = 		"Trustee Bank",
			["#Job_welcome_to_the_jungle"] = 		"Big Oil",				-- Big Oil
			["#Level_welcome_to_the_jungle_1"] = 	"Club House",
			["#Level_welcome_to_the_jungle_2"] = 	"Engine Problem",
			["#Job_hox"] = 					"Hoxton Breakout",				-- Hoxton Breakout
			["#Level_hox_1"] = 				"The Breakout",
			["#Level_hox_2"] = 				"The Search",
			["#Job_mia"] = 					"Hotline Miami",				-- Hotline Miami
			["#Level_mia_1"] = 				"Hotline Miami",
			["#Level_mia_2"] = 				"Four Floors",
			["#Job_peta"] = 				"Goat Simulator",				-- Goat Simulator
			["#Level_peta"] = 				"This was not the deal",
			["#Level_peta2"] = 				"Dirty work",

			["#Job_hox_3"] = 				"Hoxton Revenge",
			["#Level_hox_3"] = 				"The Revenge",
			["#Job_mus"] = 					"The Diamond",
			["#Level_mus"] = 				"The Diamond",
			["#Job_run"] = 					"Heat Street",
			["#Level_run"] = 				"Heat Street",
			["#Job_red2"] = 				"First World Bank",
			["#Level_red2"] = 				"First World Bank",
			["#Job_born"] = 				"The Biker Heist",
			["#Level_born"] = 				"Lion's Den",
			["#Level_chew"] = 				"Interception",
			["#Job_rvd"] = 					"Reservoir Dogs Heist",
			["#Level_rvd2"] = 				"Garnet Group Boutique",
			["#Level_rvd1"] = 				"Highland Mortuary",
			["#Job_nightclub"] = 			"Nightclub",
			["#Level_nightclub"] = 			"Nightclub",
			["#Job_brb"] = 					"Brooklyn Bank",
			["#Level_brb"] = 				"Brooklyn Bank",
			["#Job_flat"] = 				"Panic Room",
			["#Level_flat"] = 				"Panic Room",
			["#Job_cage"] = 				"Car Shop",
			["#Level_cage"] = 				"Car Shop",
			["#Job_pbr2"] = 				"Birth of Sky",
			["#Level_pbr2"] = 				"Birth of Sky",
			["#Job_rat"] = 					"Cook Off",
			["#Level_rat"] = 				"Cook Off",
			["#Job_ukrainian_job"] = 		"Ukrainian Job",
			["#Level_ukrainian_job"] = 		"Ukrainian Job",
			["#Job_gallery"] = 				"Art Gallery",
			["#Level_gallery"] = 			"Art Gallery",
			["#Job_glace"] = 				"Green Bridge",
			["#Level_glace"] = 				"Green Bridge",
			["#Job_sah"] = 					"Shacklethorne Auction",
			["#Level_sah"] = 				"Shacklethorne Auction",
			["#Job_roberts"] = 				"GO Bank",
			["#Level_roberts"] = 			"GO Bank",
			["#Job_tag"] = 					"Breakin' Feds",
			["#Level_tag"] = 				"Breakin' Feds",
			["#Job_dark"] = 				"Murky Station",
			["#Level_dark"] = 				"Murky Station",
			["#Level_wwh"] = 				"Alaskan Deal",
			["#Job_wwh"] = 					"Alaskan Deal",
			["#Job_friend"] = 				"Scarface Mansion",
			["#Level_friend"] = 			"Scarface Mansion",
			["#Job_man"] = 					"Undercover",
			["#Level_man"] = 				"Undercover",
			["#Job_des"] = 					"Henry's Rock",
			["#Level_des"] = 				"Henry's Rock",
			["#Job_help"] = 				"Prison Nightmare",
			["#Level_help"] = 				"Prison Nightmare",
			["#Job_big"] = 					"The Big Bank",
			["#Level_big"] = 				"The Big Bank",
			["#Level_big2"] = 				"The Big Bank",
			["#Job_cane"] = 				"Santa's Workshop",
			["#Level_cane"] = 				"Santa's Workshop",
			["#Job_spa"] = 					"Brooklyn 10-10",
			["#Level_spa"] = 				"Brooklyn 10-10",
			["#Job_jewelry_store"] = 		"Jewelry Store",
			["#Level_jewelry_store"] = 		"Jewelry Store",
			["#Job_jolly"] = 				"Aftershock",
			["#Level_jolly"] = 				"Aftershock",
			["#Job_family"] = 				"Diamond Store",
			["#Level_family"] = 			"Diamond Store",
			["#Job_arena"] = 				"The Alesso Heist",
			["#Level_arena"] = 				"The Alesso Heist",
			["#Job_pines"] = 				"White Xmas",
			["#Level_pines"] = 				"White Xmas",
			["#Job_kenaz"] = 				"Golden Grin Casino",
			["#Level_kenaz"] = 				"Golden Grin Casino",
			["#Level_cas"] = 				"Golden Grin Casino",
			["#Job_shoutout_raid"] = 		"Meltdown",
			["#Level_shoutout_raid"] = 		"Meltdown",
			["#Job_mad"] = 					"Boiling Point",
			["#Level_mad"] = 				"Boiling Point",
			["#Job_moon"] = 				"Stealing Xmas",
			["#Level_moon"] = 				"Stealing Xmas",
			["#Job_fish"] = 				"The Yacht Heist",
			["#Level_fish"] = 				"The Yacht Heist",
			["#Job_pal"] = 					"Counterfeit",
			["#Level_pal"] = 				"Counterfeit",
			["#Job_dinner"] = 				"Slaughterhouse",
			["#Level_dinner"] = 			"Slaughterhouse",
			["#Job_pbr"] = 					"Beneath the Mountain",
			["#Level_pbr"] = 				"Beneath the Mountain",
			["#Job_crojob1"] = 				"The Bomb: Dockyard",
			["#Level_crojob2"] = 			"The Bomb: Dockyard",
			["#Job_four_stores"] = 			"Four Stores",
			["#Level_four_stores"] = 		"Four Stores",
			["#Job_crojob"] = 				"The Bomb: Forest",
			["#Job_crojob2"] = 				"The Bomb: Forest",
			["#Level_crojob3"] = 			"The Bomb: Forest",
			["#Job_kosugi"] = 				"Shadow Raid",
			["#Level_kosugi"] = 			"Shadow Raid",
			["#Job_hvh"] = 					"Cursed Kill Room",
			["#Level_hvh"] = 				"Cursed Kill Room",
			["#Job_nail"] = 				"Lab Rats",
			["#Level_nail"] = 				"Lab Rats",
			["#Job_dah"] = 					"Diamond Heist",
			["#Level_dah"] = 				"Diamond Heist",
			["#Job_mallcrasher"] = 			"Mallcrasher",
			["#Level_mallcrasher"] = 		"Mallcrasher",
			["#Job_bph"] = 					"Hell's Island",
			["#Level_bph"] = 				"Hell's Island",
			["#Job_nmh"] = 					"No Mercy",
			["#Level_nmh"] = 				"No Mercy Hospital",
			["#Job_vit"] = 					"The White House",
			["#Level_vit"] = 				"The White House",
			["#Job_mex_cooking"] = 			"Border Crystals",
			["#Level_mex_cooking"] = 		"Border Crystals",
			["#Job_mex"] = 					"Border Crossing",
			["#Level_mex"] = 				"Border Crossing",
			["#Job_bex"] = 					"San Martín Bank",
			["#Level_bex"] = 				"San Martín Bank",
			["#Job_pex"] = 					"Breakfast in Tijuana",
			["#Level_pex"] = 				"Breakfast in Tijuana",
			["#Job_fex"] = 					"Buluc's Mansion",
			["#Level_fex"] = 				"Buluc's Mansion",
			["#Job_chas"] =					"Dragon Heist",
			["#Level_chas"] =				"Dragon Heist",
			["#Job_sand"] =					"Ukrainian Prisoner",
			["#Level_sand"] =				"Ukrainian Prisoner",
			["#Job_chca"] = 				"Black Cat",
			["#Level_chca"] = 				"Black Cat",
			["#Job_pent"] = 				"Mountain Master",
			["#Level_pent"] =				"Mountain Master",
			["#Job_ranc"] = 				"Midland Ranch",
			["#Level_ranc"] = 				"Midland Ranch",
			["#Job_trai"] = 				"Lost In Transit",
			["#Level_trai"] = 				"Lost In Transit",
			["#Job_corp"] = 				"Hostile Takeover",
			["#Level_corp"] = 				"Hostile Takeover",
			["#Job_deep"] = 				"Crude Awakening",
			["#Level_deep"] = 				"Crude Awakening",

			--Custom Heists
			["#Job_zm_kino"] =					"Kino Der Minetoten",
			["#Level_zm_kino"] =				"Kino Der Minetoten",
			["#Job_zm_house"] =					"Zombie House",
			["#Level_zm_hox_3"] =				"Zombie House",
			["#Job_broken_arrow2"] =			"Broken Arrow",
			["#Level_zm_broken_arrow"] =		"Broken Arrow",
			["#Job_zm_the_forest"] =			"Wald Der Untoten",
			["#Level_zm_the_forest"] =			"Wald Der Untoten",
			["#Job_Hoxton Breakout Zombies"] =	"Zombie Breakout",
			["#Level_hox_2_zombie"] =			"Zombie Breakout",
			["#Job_zm_arena"] =					"Zombies Arena",
			["#Level_zm_arena"] =				"Zombies Arena",
			["#Job_zm_dah"] =					"Garnet Group Tower",
			["#Level_zm_dah"] =					"Garnet Group Tower",
			["#Job_not_expected"] =				"Stalk Fraud",
			["#Level_thechase"] =				"Stalk Fraud",
			["#Job_The Late Holiday Special"] = "The Late Holiday Special",
			["#Level_santa_pain"] =				"The Late Holiday Special",
			["#Job_Virtual"] =					"Ready Player None",
			["#Level_Victor Romeo"] =			"Ready Player None",
			["#Job_Assault"] =					"Bag Simulator: The Heist",
			["#Level_endless_assault"] =		"Bag Simulator: The Heist",
			["#Job_colosseum"] =				"Bag Simulator 2: The Rehashed Heist",
			["#Level_bag_sim_2"] =				"Bag Simulator 2: The Rehashed Heist",
			["#Job_shovelforge"] =				"Shovelforge Cook Off",
			["#Level_mc_shovelforge"] =			"Shovelforge Cook Off",
			["#Job_mc_jewlerystore"] =			"Jewelry Crafters",
			["#Level_mc_jewlerystore_lvl"] =	"Jewelry Crafters",
			["#Job_mcparkour"] =				"Simple Fun Platforming",
			["#Level_mcparkour"] =				"Simple Fun Platofrming",
			["#Job_eclipse"] =					"Project Eclipse",
			["#Level_eclipse"] =				"Project Eclipse",
			["#Job_eclipse_research_facility"] = "Project Eclipse: Eclipse Research Facility",
			["#Level_the_factory"] =			"Project Eclipse: Eclipse Research Facility",
			["#Job_ascension"] =				"Project Eclipse: Ascension",
			["#Level_ascension_III"] =			"Project Eclipse: Ascension",
			["#Job_infinitebank"] =				"First World Tower", 
			["#Level_infinitebank_room"] =		"First World Tower",
			["#Job_heist_runner"] =				"Diamond Runners",
			["#Level_pk_hcm"] =					"Diamond Runners",
			["#Job_AnotherFourStores"] =		"Four More Stores",
			["#Level_lvl_fourmorestores"] =		"Four More Stores",
			["#Job_daymare"] =					"Hells Nightmare",
			["#Level_daymare"] =				"Hells Nightmare",
			["#Job_YouAreNeverAloneInTheDark"] = "Cargoship Raid",
			["#Level_Xanax"] =					"Cargoship Raid",
			["#Job_Armsdeal Alleyway"] =		"Armsdeal: Alleyway", 
			["#Level_amsdeal1"] =				"Armsdeal: Alleyway",
			["#Job_modders_devmap"] =			"Proving Grounds",
			["#Level_modders_devmap"] =			"Proving Grounds",
			["#Job_Election_Funds"] =			"Election Funds",
			["#Level_Election_Funds"] =			"Election Funds",
			["#Job_tonisn1"] =					"Grand Harvest",
			["#Level_tonisl1"] =				"Grand Harvest",
			["#Job_Underground_Bargains"] =		"Underground_Bargains",
			["#Level_Gambling_room"] =			"Underground_Bargains",
			["#Job_hardware_store_wrapper"] =	"Hardware Store", 
			["#Level_hardware_store"] =			"Hardware Store",
			["#Job_family_jewels_wrapper"] =	"Family Jewels",
			["#Level_family_jewels"] =			"Family Jewels",
			["#Job_red_money"] =				"Red Money",
			["#Level_red_money_stage_001"] =	"Red Money",
			["#Job_hidden_vault"] =				"Hidden Vault",
			["#Level_hidden_vault"] =			"Hidden Vault",
			["#Job_Zdann_Enemy_Spawner"] =		"Enemy Spawner",
			["#Level_Zdann_Enemy_Spawner"] =	"Enemy Spawner",
		}

		local data = {
			["game:state"] = state,
			["game:mode"] = mode,
			["game:heist"] = heist,
			["game:heist_day"] = day,
			["game:difficulty"] = difficulty,
			["steam_player_group_size"] = peercount,
			["max_peers"] = maxpeer,
		}

		local s = string.format("{%s}", display or "#raw_status")

		local function populate_data(s, tokens, data, count)
			count = count or 1
			if count > 100 then
				log("Infinite loop in RP update!", "error")
				return s
			end

			if s:gmatch("%%(.+)%%") then
				for k, v in pairs(data or {}) do
					s = s:gsub("%%" .. k .. "%%", v)
				end
			end

			if s:gmatch("{(.+)}") then
				for k, v in pairs(tokens or {}) do
					local key = string.format("{%s}", k)
					if s:find(key) then
						s = s:gsub(key, populate_data(v, tokens, data, count + 1))
					end
				end
			end

			return s
		end

		s = populate_data(s, tokens, data)
		--log(string.format("Steam RP updated: %s", s))
		return s
	end
elseif RequiredScript == "lib/managers/skirmishmanager" then
	local update_matchmake_attributes_original = SkirmishManager.update_matchmake_attributes
	function SkirmishManager:update_matchmake_attributes(...)
		update_matchmake_attributes_original(self, ...)

		if Global.game_settings.permission ~= "private" then
			--local game_difficulty = string.format("%i/%i", self:current_wave_number() or 1, tweak_data and #tweak_data.skirmish.ransom_amounts or 9)
			--Steam:set_rich_presence("game:difficulty", game_difficulty)
			if managers.platform then
				managers.platform:set_rich_presence()
			end
		end
	end
end

if Hooks then	-- Basegame doesn't update RP on peer count changes...
	Hooks:Add("BaseNetworkSessionOnPeerEnteredLobby", "BaseNetworkSessionOnPeerEnteredLobby_WolfHUD_RP", function(session, peer, peer_id)
		local session = managers.network:session()
		if session and Global.game_settings.permission ~= "private" then
			local group_count = tostring(session and #session:all_peers() or 1)
			local group_max = tostring(_G.tweak_data.max_players)
			Steam:set_rich_presence("steam_player_group_size", group_count)
			Steam:set_rich_presence("max_peers", group_count)
		end
	end)

	Hooks:Add("BaseNetworkSessionOnPeerRemoved", "BaseNetworkSessionOnPeerRemoved_WolfHUD_RP", function(session, peer, peer_id, reason)
		local session = managers.network:session()
		if session and Global.game_settings.permission ~= "private" then
			local group_count = tostring(session and #session:all_peers() or 1)
			local group_max = tostring(_G.tweak_data.max_players)
			Steam:set_rich_presence("steam_player_group_size", group_count)
			Steam:set_rich_presence("max_peers", group_count)
		end
	end)
end