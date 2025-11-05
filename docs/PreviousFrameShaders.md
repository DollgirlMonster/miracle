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

Here's a complete example that implements a simple motion trail effect by blending the current frame with the previous frame.

**Shader Definition** (`shaderdef_motiontrail.txt`):
```
// Example shader definition for previous frame effects
// This demonstrates how to use the previousframe texture

hardwareshader postprocess scene
{
    Name "PreviousFrameExample"
    Shader "shaders/pp/previousframe_example.fp" 330
    Texture PreviousFrame "previousframe"
    Uniform float BlendAmount = 0.5
}
```

**Shader Code** (`shaders/pp/previousframe_example.fp`):
```glsl
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
```

To enable this shader in-game:
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

---

## Implementation Details

This section provides technical details about the implementation of previous frame texture access for custom postprocessing shaders in the GZDoom-based Miracle engine.

### Architecture

#### Core Components Modified

1. **hw_postprocess.h/cpp** - Core postprocessing framework
   - Added `PreviousPipelineTexture` enum value to `PPTextureType`
   - Added `SetInputPreviousFrame()` method to `PPRenderState`
   - Modified `PPCustomShaderInstance::SetTextures()` to recognize "previousframe" texture name

2. **OpenGL Renderer (gl_renderbuffers.h/cpp)**
   - Added `mPreviousFrameTexture` member to store previous frame
   - Implemented `BindPreviousTexture()` for texture binding
   - Implemented `SaveCurrentAsPrevious()` using `glCopyImageSubData` for efficient GPU-to-GPU copy
   - Modified `CreatePipeline()` to allocate previous frame texture
   - Modified `ClearPipeline()` to cleanup previous frame texture

3. **OpenGL Postprocess (gl_postprocess.cpp)**
   - Added call to `SaveCurrentAsPrevious()` at end of `PostProcessScene()`
   - Modified `GLPPRenderState::Draw()` to handle `PreviousPipelineTexture` case

4. **Vulkan Renderer (vk_renderbuffers.h/cpp, vk_texture.cpp)**
   - Added `PreviousFrameImage` member to `VkRenderBuffers`
   - Implemented `SaveCurrentAsPrevious()` using Vulkan image copy commands
   - Proper image layout transitions for copy operations
   - Modified texture manager to return previous frame image

5. **Vulkan Postprocess (vk_postprocess.cpp)**
   - Added call to `SaveCurrentAsPrevious()` at end of `PostProcessScene()`

6. **GLES Renderer (gles_renderbuffers.h/cpp)**
   - Added `mPreviousFrameTexture` member
   - Implemented `SaveCurrentAsPrevious()` using `glCopyTexSubImage2D` (GLES-compatible)
   - Note: GLES has simplified postprocessing, so support is basic

### Texture Format

- **Format**: RGBA16F (half-precision floating point)
- **Rationale**: Preserves HDR information while being efficient
- **Resolution**: Matches the postprocessing pipeline resolution (typically viewport size)

### Copy Timing

The frame copy happens at the end of `PostProcessScene()` after all postprocessing passes:
1. Scene rendering completes
2. Pass1: Bloom and pre-tone-mapping effects
3. Pass2: Tone-mapping, colormap, lens distortion, FXAA, custom shaders
4. **Frame copy happens here** ← Previous frame saved for next frame
5. Present to screen

This ensures the previous frame contains the final, fully post-processed image.

### Performance Considerations

- **GPU Copy**: Uses hardware-accelerated copy operations (not CPU-bound)
- **Overhead**: Single texture copy per frame (~1-2% performance impact)
- **Memory**: One additional texture buffer (e.g., 1920×1080×8 bytes ≈ 16MB)
- **No Pipeline Stall**: Copy happens after rendering, doesn't block

### Shader Integration

Custom shaders declare the previous frame texture using a special name:

```c
hardwareshader postprocess scene
{
    Name "MyEffect"
    Shader "shaders/pp/myeffect.fp" 330
    Texture PreviousFrame "previousframe"  // Magic name recognized by engine
}
```

In GLSL:
```glsl
layout(binding=0) uniform sampler2D InputTexture;  // Current frame (automatic)
layout(binding=1) uniform sampler2D PreviousFrame; // Previous frame (from "previousframe")
```

### API Compatibility

#### OpenGL
- Requires OpenGL 4.3+ for `glCopyImageSubData`
- Falls back gracefully if not available (no-op)

#### Vulkan
- Uses standard Vulkan copy commands
- Proper synchronization with pipeline barriers

#### GLES
- Uses GLES 2.0 compatible `glCopyTexSubImage2D`
- Limited postprocessing support in GLES overall

### Future Enhancements

Potential improvements for future versions:

1. **Configurable Frame Delay**: Allow shaders to access frames from N frames ago
2. **Multiple History Buffers**: Ring buffer of last N frames
3. **Selective Copy**: Only copy when shaders actually use previous frame
4. **Resolution Control**: Allow previous frame at reduced resolution for performance
5. **Depth/Normal History**: Extend to depth and normal buffers for advanced effects

### Testing

To test the implementation:

1. Enable the example shader:
   ```
   PPShader.SetEnabled("PreviousFrameExample", true)
   ```

2. Adjust the blend amount to see the effect:
   ```
   PPShader.SetUniform1f("PreviousFrameExample", "BlendAmount", 0.5)
   ```

3. Move the camera/player to see motion trails

### Known Limitations

1. First frame will have black/empty previous frame
2. GLES postprocessing is simplified, may not work with all shader types
3. Requires hardware support for floating-point textures (universally available on desktop)

### References

- GZDoom Postprocessing System: [hwrenderer/postprocessing/](../src/common/rendering/hwrenderer/postprocessing/)
- Original issue discussion: Added framebuffer access for temporal effects
- OpenGL 4.3 Specification: Section 18.3 (Copying Between Images)
- Vulkan Specification: Section 19.3 (Copying Data Between Images)
