shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform float transparency : hint_range(0.0, 1.0) = 0.3;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;
uniform vec3 tint : source_color = vec3(0.8, 0.9, 1.0);
uniform sampler2D normal_map : hint_normal, filter_nearest;
uniform float fresnel_power : hint_range(0.5, 5.0) = 2.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = VERTEX;
	world_normal = NORMAL;
}

void fragment() {
	vec3 N = normalize(TANGENT * texture(normal_map, UV).rgb * 2.0 - 1.0);
	vec3 V = normalize(VIEW);
	
	float fresnel = pow(1.0 - dot(N, V), fresnel_power);
	
	ALBEDO = tint * (1.0 - fresnel * 0.7);
	METALLIC = metallic;
	ROUGHNESS = roughness;
	ALPHA = 1.0 - transparency * (1.0 - fresnel);
	NORMAL_MAP = texture(normal_map, UV).rgb;
	
	// Subtle reflections
	vec3 reflect_dir = reflect(-V, N);
	float specular = pow(max(dot(reflect_dir, V), 0.0), 32.0);
	EMISSION = vec3(0.1, 0.15, 0.2) * specular * 0.5;
}
