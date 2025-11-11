shader_type canvas_item;

// Parameter to control the warning intensity (0.0 = normal, 1.0 = full white flash)
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;

// Flash speed multiplier
uniform float flash_speed : hint_range(0.0, 10.0) = 5.0;

void fragment() {
	// Get the original texture color
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Create a pulsing effect using sine wave
	float pulse = sin(TIME * flash_speed) * 0.5 + 0.5; // Oscillates between 0 and 1
	
	// Mix between pulse and constant based on intensity
	// At low intensity, more pulsing. At high intensity, more constant white
	float flash_amount = flash_intensity * (0.3 + pulse * 0.7);
	
	// Blend original color with white based on flash amount
	vec3 white = vec3(1.0, 1.0, 1.0);
	vec3 final_color = mix(tex_color.rgb, white, flash_amount);
	
	// Output the final color with original alpha
	COLOR = vec4(final_color, tex_color.a);
}
