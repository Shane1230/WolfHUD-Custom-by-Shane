local is_ready = managers.network:session():local_peer():waiting_for_player_ready()
if managers.network:session() then
	if managers.preplanning:has_current_level_preplanning() and managers.preplanning._rebuy_assets.reminder_active then
		if managers.preplanning:get_can_rebuy_assets() and not is_ready then
			-- Rebuy PrePlanning
			local rebuy_assets = managers.preplanning._rebuy_assets.assets
			local votes = managers.preplanning._rebuy_assets.votes

			for i, data in ipairs(rebuy_assets) do
				local td = managers.preplanning:get_tweak_data_by_type(data.type)
				local can_unlock = managers.preplanning:can_reserve_mission_element(data.type)

				if td.dlc_lock then
					can_unlock = can_unlock and managers.dlc:is_dlc_unlocked(td.dlc_lock)
				end
				if td.upgrade_lock then
					can_unlock = can_unlock and managers.player:has_category_upgrade(td.upgrade_lock.category, td.upgrade_lock.upgrade)
				end

				if can_unlock then
					managers.preplanning:reserve_mission_element(data.type, data.id)
				end
			end

			for i, data in ipairs(votes) do
				if data.id then
					if managers.preplanning:can_vote_on_plan(data.type, managers.network:session():local_peer():id()) then
						managers.preplanning:mass_vote_on_plan(data.type, data.id)
					end
				else
					local id = data.id or managers.preplanning:get_mission_element_id(data.type, data.index)
					managers.preplanning:vote_on_plan(data.type, id)
				end
			end
			
			managers.preplanning._rebuy_assets.reminder_active = false
		else
			-- Open PrePnanning Menu
			local opened_node = managers.menu:active_menu() and managers.menu:active_menu().logic:selected_node()
			if not opened_node or opened_node._parameters.name ~= "preplanning" then
				managers.menu:open_node("preplanning")
			end
		end
	else
		-- Buy All Assets
		managers.assets:unlock_all_availible_assets()
	end
end