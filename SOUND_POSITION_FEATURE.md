# Sound Position Control Feature for GZDoom

This feature adds the ability to get and set the playback position of sounds on specific channels via ZScript functions. This enables precise audio synchronization for rhythm games and other timing-sensitive applications.

## New ZScript Functions

### Actor.A_SetSoundPosition(int slot, int position)
Sets the playback position of a sound playing on the specified channel.

**Parameters:**
- `slot`: The sound channel (CHAN_AUTO, CHAN_WEAPON, CHAN_VOICE, etc.)
- `position`: The position in samples to seek to

**Example:**
```zscript
// Seek to 2 seconds into the sound (assuming 44100 Hz sample rate)
A_SetSoundPosition(CHAN_AUTO, 88200);
```

### Actor.A_GetSoundPosition(int slot) -> int
Returns the current playback position of a sound on the specified channel.

**Parameters:**
- `slot`: The sound channel to query

**Returns:**
- Current position in samples, or 0 if no sound is playing

**Example:**
```zscript
int currentPos = A_GetSoundPosition(CHAN_AUTO);
double timeInSeconds = currentPos / 44100.0; // Convert to seconds
```

## Use Cases

### Rhythm Games
The primary use case is for rhythm games where you need to:
1. Track the exact position in a music track
2. Synchronize game events to the beat
3. Correct timing drift between game logic and audio playback

### Audio Synchronization
- Synchronize visual effects with audio
- Create perfectly timed audio sequences
- Implement audio scrubbing/seeking functionality
- Handle audio dropouts and resynchronization

## Implementation Details

### Sample Rate Considerations
- Most audio in GZDoom is played at 44100 Hz sample rate
- To convert samples to time: `timeInSeconds = samples / 44100.0`
- To convert time to samples: `samples = timeInSeconds * 44100.0`

### Performance Notes
- Getting/setting position is relatively fast but shouldn't be called every tick
- Consider caching position values and updating periodically
- Use timers or frame counting to avoid excessive API calls

### Limitations
- Position is in samples, not milliseconds (requires conversion)
- Only works with sounds currently playing on a channel
- Seeking to invalid positions may stop the sound
- Some compressed audio formats may have seeking limitations

## Example: Basic Rhythm Game

See `rhythm_game_example.zs` for a complete implementation showing:
- Music position tracking
- Beat detection
- Rhythm synchronization correction
- Player input timing validation

## Technical Implementation

This feature extends the GZDoom sound system by:
1. Adding `SetPosition` and `GetPosition` methods to the sound renderer interface
2. Implementing these methods in the OpenAL sound backend
3. Exposing the functionality through the sound engine
4. Creating ZScript native function bindings

The implementation uses OpenAL's `AL_SAMPLE_OFFSET` parameter for precise sample-level positioning.

## Compatibility

- Requires OpenAL sound backend (default in most GZDoom builds)
- Works with all supported audio formats (WAV, OGG, MP3, FLAC, etc.)
- No impact on existing mods or gameplay when not used
- Functions return 0/do nothing if sound system is unavailable