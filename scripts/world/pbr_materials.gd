extends RefCounted

# PBR material palette used by `velvet_strip_builder.gd`.
# The previous version only defined a few keys, so most district assets fell
# back to a flat gray default and looked reverted.
var _cache := {}

func _new_surface(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat

func _new_emissive(color: Color, alpha := 1.0, energy := 3.2) -> StandardMaterial3D:
	var mat := _new_surface(Color(color.r, color.g, color.b, alpha), 0.28, 0.0)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	if alpha < 0.999:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _new_glass(color: Color, alpha: float, roughness: float, metallic := 0.08, emission_color := Color(0, 0, 0, 1), emission_energy := 0.0) -> StandardMaterial3D:
	var mat := _new_surface(Color(color.r, color.g, color.b, alpha), roughness, metallic)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission_color
		mat.emission_energy_multiplier = emission_energy
	return mat

func _build_material(key: String) -> StandardMaterial3D:
	match key:
		"aged_concrete":
			return _new_surface(Color("616870"), 0.9, 0.02)
		"awning_canvas":
			var awning := _new_surface(Color("6d2530"), 0.86, 0.0)
			awning.rim_enabled = true
			awning.rim = 0.35
			awning.rim_tint = 0.22
			return awning
		"bar_top":
			var bar := _new_surface(Color("2c2224"), 0.24, 0.18)
			bar.clearcoat_enabled = true
			bar.clearcoat = 0.55
			bar.clearcoat_roughness = 0.15
			return bar
		"black_lacquer":
			var lacquer := _new_surface(Color("101217"), 0.2, 0.1)
			lacquer.clearcoat_enabled = true
			lacquer.clearcoat = 0.85
			lacquer.clearcoat_roughness = 0.08
			return lacquer
		"brushed_gold":
			return _new_surface(Color("c9aa63"), 0.28, 0.95)
		"chrome":
			return _new_surface(Color("bcc7d3"), 0.09, 1.0)
		"dark_marble":
			return _new_surface(Color("221f26"), 0.22, 0.2)
		"dark_wood":
			return _new_surface(Color("3a2a21"), 0.74, 0.0)
		"grating":
			return _new_surface(Color("5a646f"), 0.48, 0.72)
		"lamp_bulb":
			return _new_emissive(Color("ffd6a2"), 0.98, 4.6)
		"marble_floor":
			return _new_surface(Color("ddd8cf"), 0.16, 0.04)
		"marble_wall":
			return _new_surface(Color("e5dfd5"), 0.3, 0.02)
		"mirrored_glass":
			return _new_glass(Color("8ea0b4"), 0.32, 0.05, 0.32, Color("8ea8bf"), 0.7)
		"neon_amber":
			return _new_emissive(Color("ffbf66"), 0.95, 4.8)
		"neon_cyan":
			return _new_emissive(Color("5edbff"), 0.95, 4.8)
		"neon_pink":
			return _new_emissive(Color("ff5da6"), 0.95, 4.8)
		"neon_red":
			return _new_emissive(Color("ff5a62"), 0.95, 4.6)
		"painted_brick_cool":
			return _new_surface(Color("546171"), 0.8, 0.05)
		"painted_brick_warm":
			return _new_surface(Color("7f6756"), 0.78, 0.03)
		"polished_gold":
			var gold := _new_surface(Color("e0c27a"), 0.12, 1.0)
			gold.clearcoat_enabled = true
			gold.clearcoat = 0.42
			gold.clearcoat_roughness = 0.06
			return gold
		"puddle":
			var puddle := _new_glass(Color("1c2331"), 0.7, 0.03, 0.18)
			puddle.clearcoat_enabled = true
			puddle.clearcoat = 1.0
			puddle.clearcoat_roughness = 0.02
			return puddle
		"rope_velvet":
			var rope := _new_surface(Color("6d0f24"), 0.82, 0.0)
			rope.rim_enabled = true
			rope.rim = 0.3
			rope.rim_tint = 0.18
			return rope
		"service_floor":
			return _new_surface(Color("2b3340"), 0.88, 0.04)
		"signage_backing":
			return _new_surface(Color("191e28"), 0.4, 0.12)
		"stanchion":
			return _new_surface(Color("6f777f"), 0.2, 0.9)
		"stucco_cream":
			return _new_surface(Color("dacfbf"), 0.86, 0.01)
		"tinted_glass":
			return _new_glass(Color("5e748d"), 0.26, 0.04, 0.12, Color("5e748d"), 0.3)
		"velvet_red":
			var velvet := _new_surface(Color("5b1222"), 0.88, 0.0)
			velvet.rim_enabled = true
			velvet.rim = 0.52
			velvet.rim_tint = 0.24
			return velvet
		"wet_asphalt":
			var asphalt := _new_surface(Color("121823"), 0.22, 0.24)
			asphalt.clearcoat_enabled = true
			asphalt.clearcoat = 0.7
			asphalt.clearcoat_roughness = 0.1
			return asphalt
		# Backward-compatible aliases for older naming.
		"velvet":
			return _build_material("velvet_red")
		"gold":
			return _build_material("polished_gold")
		"marble":
			return _build_material("marble_wall")
		"glass":
			return _build_material("tinted_glass")
		"neon_blue":
			return _new_emissive(Color("6ab9ff"), 0.95, 4.6)
		_:
			return _new_surface(Color("666a72"), 0.72, 0.08)

func get_material(material_name: String) -> StandardMaterial3D:
	var key := material_name.to_lower()
	if not _cache.has(key):
		_cache[key] = _build_material(key)
	return _cache[key]
