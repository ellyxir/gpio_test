defmodule HelloNerves.SoundManager do
  @moduledoc """
  GenServer that manages continuous audio playback based on distance
  """
  
  use GenServer
  alias HelloNerves.AudioStream
  alias HelloNerves.UltrasonicServer
  
  @buffer_duration_ms 50  # Shorter buffer for less delay
  @crossfade_ms 3  # Shorter crossfade
  @schedule_ahead_ms 10  # Schedule next buffer 10ms before current ends
  
  # Distance range in cm
  @min_distance 5
  @max_distance 50
  
  # Frequency range in Hz
  @min_freq 200
  @max_freq 2000
  
  defmodule State do
    defstruct [:audio_port, :frequency, :phase, :sample_rate, :current_buffer, 
               :start_time, :audio_generated_ms]
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
    sample_rate = 22050
    
    # Start the audio port
    audio_port = AudioStream.start_aplay(sample_rate)
    
    # Generate initial buffer
    initial_buffer = generate_buffer(440, 0, @buffer_duration_ms, sample_rate)
    AudioStream.send_audio(audio_port, initial_buffer.pcm_data)
    
    # Record start time
    start_time = System.monotonic_time(:millisecond)
    
    # Schedule next buffer generation
    Process.send_after(self(), :generate_buffer, @buffer_duration_ms - @schedule_ahead_ms)
    
    state = %State{
      audio_port: audio_port,
      frequency: 440,
      phase: initial_buffer.end_phase,
      sample_rate: sample_rate,
      current_buffer: :a,
      start_time: start_time,
      audio_generated_ms: @buffer_duration_ms  # We generated one buffer
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_info(:generate_buffer, state) do
    # Check if we're ahead of real time
    elapsed_ms = System.monotonic_time(:millisecond) - state.start_time
    ahead_by = state.audio_generated_ms - elapsed_ms
    
    # If we're more than 10ms ahead, wait
    if ahead_by > 10 do
      # We're ahead - reschedule for when we should generate
      Process.send_after(self(), :generate_buffer, ahead_by)
      {:noreply, state}
    else
      # Get distance from UltrasonicServer
      distance = UltrasonicServer.get_distance()
      
      # Calculate frequency based on distance
      new_frequency = if distance do
        freq = distance_to_frequency(distance)
        # Uncomment for debug: IO.puts("Distance: #{Float.round(distance, 1)}cm -> Freq: #{round(freq)}Hz, Ahead: #{ahead_by}ms")
        round(freq)
      else
        state.frequency  # Keep previous frequency if no reading
      end
      
      # Generate next buffer with phase continuity and crossfade
      buffer = if abs(new_frequency - state.frequency) > 50 do
        # Large frequency change - do crossfade
        generate_buffer_with_crossfade(state.frequency, new_frequency, state.phase, 
                                       @buffer_duration_ms, @crossfade_ms, state.sample_rate)
      else
        # Small change - just continue with phase tracking
        generate_buffer(new_frequency, state.phase, @buffer_duration_ms, state.sample_rate)
      end
      
      # Send the buffer
      AudioStream.send_audio(state.audio_port, buffer.pcm_data)
      
      # Schedule next buffer generation
      Process.send_after(self(), :generate_buffer, @buffer_duration_ms - @schedule_ahead_ms)
      
      # Update state
      next_buffer = if state.current_buffer == :a, do: :b, else: :a
      {:noreply, %{state | 
        frequency: new_frequency,
        phase: buffer.end_phase,
        current_buffer: next_buffer,
        audio_generated_ms: state.audio_generated_ms + @buffer_duration_ms
      }}
    end
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
  
  defp generate_buffer(frequency, start_phase, duration_ms, sample_rate) do
    samples = round(sample_rate * duration_ms / 1000)
    omega = 2.0 * :math.pi() * frequency / sample_rate
    
    {pcm_data, end_phase} = generate_samples(samples, omega, start_phase)
    
    %{pcm_data: pcm_data, end_phase: end_phase}
  end
  
  defp generate_buffer_with_crossfade(old_freq, new_freq, start_phase, duration_ms, crossfade_ms, sample_rate) do
    total_samples = round(sample_rate * duration_ms / 1000)
    crossfade_samples = round(sample_rate * crossfade_ms / 1000)
    
    # Generate the crossfade portion
    omega_old = 2.0 * :math.pi() * old_freq / sample_rate
    omega_new = 2.0 * :math.pi() * new_freq / sample_rate
    
    # Crossfade: fade out old frequency while fading in new frequency
    crossfade_data = for i <- 0..(crossfade_samples - 1) do
      fade_out = (crossfade_samples - i) / crossfade_samples
      fade_in = i / crossfade_samples
      
      old_sample = :math.sin(start_phase + omega_old * i) * fade_out
      new_sample = :math.sin(omega_new * i) * fade_in
      
      value = (old_sample + new_sample) * 32767
      sample = round(value) |> max(-32768) |> min(32767)
      <<sample::little-signed-16>>
    end
    
    # Generate the rest with new frequency
    new_phase = omega_new * crossfade_samples
    remaining_samples = total_samples - crossfade_samples
    {remaining_data, end_phase} = generate_samples(remaining_samples, omega_new, new_phase)
    
    pcm_data = IO.iodata_to_binary([crossfade_data | remaining_data])
    %{pcm_data: pcm_data, end_phase: end_phase}
  end
  
  defp generate_samples(num_samples, omega, start_phase) do
    pcm_list = for i <- 0..(num_samples - 1) do
      phase = start_phase + omega * i
      value = :math.sin(phase)
      sample = round(value * 32767) |> max(-32768) |> min(32767)
      <<sample::little-signed-16>>
    end
    
    end_phase = start_phase + omega * num_samples
    # Normalize phase to 0..2π to prevent overflow
    normalized_phase = :math.fmod(end_phase, 2.0 * :math.pi())
    
    {pcm_list, normalized_phase}
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