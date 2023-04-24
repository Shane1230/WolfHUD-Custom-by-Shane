if managers.network:session() and not managers.network.matchmake:set_server_state("HostStateInGame") then
	managers.multi_profile:next_profile()
end