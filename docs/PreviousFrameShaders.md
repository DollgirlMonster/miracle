# Previous Frame Texture Access for Shaders

This feature allows custom postprocessing shaders to access the final rendered frame from the previous frame. This enables effects such as:

- **Hall of Mirrors**: Reflective surfaces showing delayed reflections
- **Motion Trails**: Light trails based on player or object movement
- **Feedback Effects**: Any effect that depends on temporal information

## Usage

### In Shader Definitions (GLDEFS/SHADERDEF)

To use the previous frame texture in your custom postprocess shader, declare it using the special texture name `"previousframe"`:

```
hardwareshader postprocess scene
{
    Name "MyFeedbackEffect"
    Shader "shaders/pp/myfeedback.fp" 330
    Texture PreviousFrame "previousframe"
    Uniform float BlendAmount = 0.5
}
```

### In GLSL Shader Code

Access the previous frame texture like any other sampler:

```glsl
layout(location=0) in vec2 TexCoord;
layout(location=0) out vec4 FragColor;

layout(binding=0) uniform sampler2D InputTexture;  // Current frame
layout(binding=1) uniform sampler2D PreviousFrame; // Previous frame

void main()
{
    vec4 current = texture(InputTexture, TexCoord);
    vec4 previous = texture(PreviousFrame, TexCoord);
    
    // Blend current and previous frames for a motion trail effect
    FragColor = mix(current, previous, BlendAmount);
}
```

## Technical Details

- The previous frame texture is automatically updated at the end of each frame's postprocessing pass
- The texture contains the final rendered output from the previous frame (after all postprocessing)
- The texture is in RGBA16F format to preserve HDR information
- Both OpenGL and Vulkan renderers are supported

## Example Effects

### Motion Trail Effect

See `wadsrc/static/shaderdef_previousframe_example.txt` for a complete example that implements a simple motion trail effect by blending the current frame with the previous frame.

To enable this example shader in-game:
```
PPShader.SetEnabled("PreviousFrameExample", true)
PPShader.SetUniform1f("PreviousFrameExample", "BlendAmount", 0.3)
```

### Hall of Mirrors Effect

For a hall of mirrors effect, you could sample the previous frame with a slight offset or distortion:

```glsl
vec2 offset = vec2(0.01, 0.0); // Horizontal shift
vec4 previous = texture(PreviousFrame, TexCoord + offset);
FragColor = mix(current, previous, 0.5);
```

## Notes

- The first frame will have an empty/black previous frame texture
- High blend amounts (closer to 1.0) will create stronger trailing effects
- This feature has minimal performance impact as it only requires a single texture copy per frame
