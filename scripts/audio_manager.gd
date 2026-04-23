extends Node

# Professional Sound Manager Singleton
# Standardize audio playback and prevent "cluttered" sound node management.

func play_sound_2d(sound_path: String, position: Vector2, volume: float = 0.0, pitch: float = 1.0) -> void:
	var stream = load(sound_path)
	if not stream:
		return
		
	var player = AudioStreamPlayer2D.new()
	player.stream = stream
	player.position = position
	player.volume_db = volume
	player.pitch_scale = pitch
	player.autoplay = true
	
	# Add to the current scene root so it exists in world space
	get_tree().current_scene.add_child(player)
	
	# Auto-cleanup
	player.finished.connect(func(): player.queue_free())