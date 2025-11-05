# Implementation Notes: Previous Frame Texture Access

## Overview

This document provides technical details about the implementation of previous frame texture access for custom postprocessing shaders in the GZDoom-based Miracle engine.

## Architecture

### Core Components Modified

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

## Technical Details

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

## API Compatibility

### OpenGL
- Requires OpenGL 4.3+ for `glCopyImageSubData`
- Falls back gracefully if not available (no-op)

### Vulkan
- Uses standard Vulkan copy commands
- Proper synchronization with pipeline barriers

### GLES
- Uses GLES 2.0 compatible `glCopyTexSubImage2D`
- Limited postprocessing support in GLES overall

## Future Enhancements

Potential improvements for future versions:

1. **Configurable Frame Delay**: Allow shaders to access frames from N frames ago
2. **Multiple History Buffers**: Ring buffer of last N frames
3. **Selective Copy**: Only copy when shaders actually use previous frame
4. **Resolution Control**: Allow previous frame at reduced resolution for performance
5. **Depth/Normal History**: Extend to depth and normal buffers for advanced effects

## Testing

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

## Known Limitations

1. First frame will have black/empty previous frame
2. GLES postprocessing is simplified, may not work with all shader types
3. Requires hardware support for floating-point textures (universally available on desktop)

## References

- GZDoom Postprocessing System: [hwrenderer/postprocessing/](../src/common/rendering/hwrenderer/postprocessing/)
- Original issue discussion: Added framebuffer access for temporal effects
- OpenGL 4.3 Specification: Section 18.3 (Copying Between Images)
- Vulkan Specification: Section 19.3 (Copying Data Between Images)
