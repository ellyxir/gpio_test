defmodule HelloNerves.SoundManager do
  @moduledoc """
  GenServer that manages continuous audio playback based on distance
  """
  
  use GenServer
  alias HelloNerves.AudioStream
  alias HelloNerves.UltrasonicServer
  
  @tone_duration_ms 50  # Duration of each tone
  
  # Distance range in cm
  @min_distance 5
  @max_distance 50
  
  # Frequency range in Hz
  @min_freq 200
  @max_freq 2000
  
  defmodule State do
    defstruct [:audio_port, :frequency, :tone_duration]
  end
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, Keyword.put_new(opts, :name, __MODULE__))
  end
  
  def stop() do
    GenServer.stop(__MODULE__)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_) do
    # Start the audio port
    audio_port = AudioStream.start_aplay()
    
    # Schedule first tone
    Process.send_after(self(), :play_tone, 100)
    
    state = %State{
      audio_port: audio_port,
      frequency: 440,  # Default frequency
      tone_duration: @tone_duration_ms
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_info(:play_tone, state) do
    # Get distance from UltrasonicServer
    distance = UltrasonicServer.get_distance()
    
    # Calculate frequency based on distance
    new_frequency = if distance do
      freq = distance_to_frequency(distance)
      IO.puts("Distance: #{Float.round(distance, 1)}cm -> Frequency: #{round(freq)}Hz")
      round(freq)
    else
      state.frequency  # Keep previous frequency if no reading
    end
    
    # Generate and send tone
    pcm_data = AudioStream.generate_tone(new_frequency, state.tone_duration)
    AudioStream.send_audio(state.audio_port, pcm_data)
    
    # Schedule next tone
    Process.send_after(self(), :play_tone, state.tone_duration)
    
    # Update state with new frequency
    {:noreply, %{state | frequency: new_frequency}}
  end
  
  @impl true
  def terminate(_reason, state) do
    # Cleanup audio port
    if state.audio_port, do: AudioStream.stop(state.audio_port)
    :ok
  end
  
  # Private functions
  
  @doc false
  defp distance_to_frequency(distance) do
    # Clamp distance to valid range
    distance = max(@min_distance, min(@max_distance, distance))
    
    # Normalize distance to 0-1 range (inverted: close = 1, far = 0)
    normalized = 1.0 - (distance - @min_distance) / (@max_distance - @min_distance)
    
    # Logarithmic mapping
    log_range = :math.log(@max_freq / @min_freq)
    
    # Scale normalized value to log range and convert back
    @min_freq * :math.exp(normalized * log_range)
  end
  
  # Original test functions for backwards compatibility
  
  @doc """
  Play a simple beep for testing
  """
  def beep(frequency \\ 440, duration_ms \\ 100) do
    # Start aplay port
    port = AudioStream.start_aplay()
    
    # Generate and send the tone
    pcm_data = AudioStream.generate_tone(frequency, duration_ms)
    AudioStream.send_audio(port, pcm_data)
    
    # Wait for the tone to finish
    Process.sleep(duration_ms)
    
    # Close the port
    AudioStream.stop(port)
    
    :ok
  end
  
  @doc """
  Test function to verify audio works
  """
  def test() do
    IO.puts("Playing 440Hz beep for 1 second...")
    beep(440, 1000)
    IO.puts("Done!")
  end
end