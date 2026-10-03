shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform int surface_kind = 0; // masonry / paving / attached growth / terrain / far bank
varying vec3 world_point;
varying vec3 world_normal;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL,0.0)).xyz);
}

void fragment() {
	vec3 source = COLOR.rgb;
	float tone = dot(source,vec3(0.3,0.5,0.2));
	float top = smoothstep(0.35,0.9,world_normal.y);
	// Very broad, low-amplitude stone color variation. No fine noise, bump or alpha.
	float mineral = sin(world_point.x * 2.7 + sin(world_point.z * 1.8)) * sin(world_point.z * 2.1 + world_point.y * 2.0);
	vec3 stone = mix(vec3(0.73,0.65,0.50),vec3(0.93,0.83,0.63),top) * tone;
	float edge_distance = min(min(UV.x,1.0-UV.x)*UV2.x,min(UV.y,1.0-UV.y)*UV2.y);
	float wear = 1.0-smoothstep(0.003,0.027,edge_distance);
	if (surface_kind == 0 || surface_kind == 1) {
		// Existing dark doorway and incised relief vertex colors retain their depth.
		stone *= 1.0 + mineral * (surface_kind == 1 ? 0.018 : 0.035);
		stone = mix(stone,stone*1.15,wear*(surface_kind == 1 ? 0.28 : 0.62));
		// Vertical faces are cool toward the footing. It never paints across a slab.
		float footing = (1.0-top)*(1.0-smoothstep(0.0,0.22,UV.y));
		stone = mix(stone,stone*vec3(0.82,0.94,0.83),footing*0.45);
		ALBEDO = stone;
	} else if (surface_kind == 2) {
		// Authored moss/roots/leaves keep their locations and distinct vertex tints.
		ALBEDO = source * vec3(0.78,0.91,0.65);
	} else if (surface_kind == 4) {
		// Atmosphere lives on existing far-bank geometry, not on actors or warnings.
		ALBEDO = mix(source*vec3(0.74,0.95,0.93),vec3(0.40,0.59,0.55),0.38);
	} else {
		bool water = source.b > source.r * 1.18 && source.g > source.r * 1.2;
		bool bare_soil = source.g > source.r * 1.025;
		if (water) ALBEDO = source*vec3(0.67,0.80,0.79);
		else if (bare_soil && top > 0.6) ALBEDO = source*vec3(0.82,0.86,0.73);
		else ALBEDO = stone * (1.0+mineral*0.012);
	}
	ROUGHNESS = 1.0;
}
