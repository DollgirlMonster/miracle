// Example ZScript code demonstrating how to use the new sound position functions
// for rhythm game synchronization as mentioned in the Reddit post

class RhythmGameManager : Actor
{
    // Track timing information
    int musicStartTime;
    int gameStartTime;
    int currentBeat;
    double beatsPerMinute;
    double secondsPerBeat;
    
    // Sound channels
    enum SoundChannels
    {
        CHAN_MUSIC = CHAN_AUTO,
        CHAN_SFX = CHAN_ITEM
    }
    
    override void BeginPlay()
    {
        Super.BeginPlay();
        
        // Initialize rhythm game with 120 BPM
        beatsPerMinute = 120.0;
        secondsPerBeat = 60.0 / beatsPerMinute;
        
        // Start the background music
        A_StartSound("music/rhythmtrack", CHAN_MUSIC, CHANF_LOOP);
        
        // Record when we started
        musicStartTime = level.time;
        gameStartTime = level.time;
    }
    
    // Function to get current music position in samples
    int GetMusicPositionSamples()
    {
        return A_GetSoundPosition(CHAN_MUSIC);
    }
    
    // Function to get current music position in milliseconds
    // Assuming 44100 Hz sample rate (common for audio)
    double GetMusicPositionMS()
    {
        int samples = GetMusicPositionSamples();
        return (samples * 1000.0) / 44100.0;
    }
    
    // Function to sync music to a specific position (for beat correction)
    void SyncMusicToPosition(double targetTimeMS)
    {
        // Convert milliseconds to samples (44100 Hz)
        int targetSamples = int((targetTimeMS * 44100.0) / 1000.0);
        A_SetSoundPosition(CHAN_MUSIC, targetSamples);
    }
    
    // Function to calculate expected beat position
    double GetExpectedBeatTime()
    {
        double gameTimeSeconds = (level.time - gameStartTime) / 35.0; // Doom ticks to seconds
        return gameTimeSeconds / secondsPerBeat;
    }
    
    // Function to get actual beat from music position
    double GetActualBeatFromMusic()
    {
        double musicTimeSeconds = GetMusicPositionMS() / 1000.0;
        return musicTimeSeconds / secondsPerBeat;
    }
    
    // Function to perform rhythm synchronization correction
    void PerformRhythmSync()
    {
        double expectedBeat = GetExpectedBeatTime();
        double actualBeat = GetActualBeatFromMusic();
        double beatDifference = expectedBeat - actualBeat;
        
        // If we're more than 0.1 beats off, correct it
        if (abs(beatDifference) > 0.1)
        {
            double correctionTimeMS = beatDifference * secondsPerBeat * 1000.0;
            double newTargetTimeMS = GetMusicPositionMS() + correctionTimeMS;
            
            // Clamp to reasonable bounds
            if (newTargetTimeMS >= 0)
            {
                SyncMusicToPosition(newTargetTimeMS);
                Console.Printf("Rhythm sync correction: %.2f beats, %.2f ms", beatDifference, correctionTimeMS);
            }
        }
    }
    
    // Function to trigger beat-synchronized effects
    void OnBeat(int beatNumber)
    {
        // Play a beat sound effect
        A_StartSound("rhythm/beat", CHAN_SFX);
        
        // Visual effect could go here
        Console.Printf("Beat %d at music position: %.2f ms", beatNumber, GetMusicPositionMS());
    }
    
    override void Tick()
    {
        Super.Tick();
        
        // Check for rhythm sync every few ticks to avoid performance issues
        if (level.time % 35 == 0) // Once per second
        {
            PerformRhythmSync();
        }
        
        // Detect beats
        double currentBeatFloat = GetActualBeatFromMusic();
        int newBeat = int(currentBeatFloat);
        
        if (newBeat > currentBeat)
        {
            OnBeat(newBeat);
            currentBeat = newBeat;
        }
    }
}

// Example usage in a player or game controller
class RhythmPlayer : PlayerPawn
{
    RhythmGameManager rhythmManager;
    
    override void BeginPlay()
    {
        Super.BeginPlay();
        
        // Spawn the rhythm manager
        rhythmManager = RhythmGameManager(Spawn("RhythmGameManager"));
    }
    
    // Example function for player input timing
    void OnPlayerAction()
    {
        if (rhythmManager)
        {
            double currentBeat = rhythmManager.GetActualBeatFromMusic();
            double beatFraction = currentBeat - int(currentBeat);
            
            // Check if player is hitting on the beat (within 0.2 beat tolerance)
            if (beatFraction < 0.2 || beatFraction > 0.8)
            {
                Console.Printf("Perfect timing! Beat accuracy: %.3f", beatFraction);
                A_StartSound("rhythm/perfect", CHAN_VOICE);
            }
            else
            {
                Console.Printf("Off beat. Beat accuracy: %.3f", beatFraction);
                A_StartSound("rhythm/miss", CHAN_VOICE);
            }
        }
    }
}