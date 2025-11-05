
layout(location=0) in vec2 TexCoord;
layout(location=0) out vec4 FragColor;

layout(binding=0) uniform sampler2D InputTexture;
layout(binding=1) uniform sampler2D PreviousFrame;

void main()
{
	// Get current frame color
	vec4 current = texture(InputTexture, TexCoord);
	
	// Get previous frame color
	vec4 previous = texture(PreviousFrame, TexCoord);
	
	// Simple motion trail effect: blend with previous frame
	// Use BlendAmount to control how much of the previous frame to keep
	FragColor = mix(current, previous, BlendAmount);
}
