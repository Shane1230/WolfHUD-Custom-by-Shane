local is_ready = managers.network:session():local_peer():waiting_for_player_ready()
if managers.network:session() and managers.multi_profile:has_previous() and not is_ready then
	managers.multi_profile:previous_profile()
end