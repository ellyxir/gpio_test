defmodule HelloNerves.SoundManager do
  @moduledoc """
  GenServer that manages continuous audio playback
  """
  
  use GenServer
  alias HelloNerves.AudioStream
  
  @tone_duration_ms 50  # Duration of each tone
  @fixed_frequency 440  # Fixed frequency for now
  
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
      frequency: @fixed_frequency,
      tone_duration: @tone_duration_ms
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_info(:play_tone, state) do
    # Generate and send tone
    pcm_data = AudioStream.generate_tone(state.frequency, state.tone_duration)
    AudioStream.send_audio(state.audio_port, pcm_data)
    
    # Schedule next tone
    Process.send_after(self(), :play_tone, state.tone_duration)
    
    {:noreply, state}
  end
  
  @impl true
  def terminate(_reason, state) do
    # Cleanup audio port
    if state.audio_port, do: AudioStream.stop(state.audio_port)
    :ok
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