if managers.network:session() and not managers.network.matchmake:set_server_state("HostStateInGame") then
	if managers.preplanning:has_current_level_preplanning() then
		managers.menu:open_node("preplanning")
	else
		managers.assets:unlock_all_availible_assets()
	end
end