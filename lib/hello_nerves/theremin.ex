defmodule HelloNerves.Theremin do
  @moduledoc """
  Simple theremin that maps ultrasonic distance to audio frequency
  """
  
  alias HelloNerves.UltrasonicServer
  alias HelloNerves.AudioStream
  
  # Distance range in cm
  @min_distance 5
  @max_distance 50
  
  # Frequency range in Hz
  @min_freq 200
  @max_freq 2000
  
  @doc """
  Start the theremin - reads distance and plays tones
  Non-blocking version using Port and GenServer
  """
  def run(tone_duration_ms \\ 50) do
    IO.puts("Starting ultrasonic sensor...")
    
    # Start the sensor GenServer if not already started
    case GenServer.whereis(UltrasonicServer) do
      nil -> 
        {:ok, _pid} = UltrasonicServer.start_link()
        IO.puts("Started UltrasonicServer")
      pid -> 
        IO.puts("UltrasonicServer already running: #{inspect(pid)}")
    end
    
    # Give sensor time to get first reading
    Process.sleep(200)
    
    # Start the audio port
    audio_port = AudioStream.start_aplay()
    IO.puts("Audio port started")
    
    IO.puts("Theremin started! Move your hand between 5-50cm from sensor")
    IO.puts("Press Ctrl+C twice to stop")
    
    # Start the theremin loop with the audio port
    loop_with_genserver(tone_duration_ms, audio_port)
    
    # Cleanup on exit (won't reach here until interrupted)
    AudioStream.stop(audio_port)
  end
  
  defp loop_with_genserver(tone_duration_ms, audio_port) do
    # Get distance from GenServer
    distance = UltrasonicServer.get_distance()
    
    if distance do
      # Map distance to frequency
      frequency = distance_to_frequency(distance)
      freq_rounded = round(frequency)
      
      IO.puts("Distance: #{Float.round(distance, 1)}cm -> Frequency: #{freq_rounded}Hz")
      
      # Generate and send audio (non-blocking)
      pcm_data = AudioStream.generate_tone(freq_rounded, tone_duration_ms)
      AudioStream.send_audio(audio_port, pcm_data)
    end
    
    # Small delay to control loop rate
    Process.sleep(tone_duration_ms)
    
    # Continue loop
    loop_with_genserver(tone_duration_ms, audio_port)
  end
  
  defp loop_nonblocking(tone_duration_ms, audio_port) do
    # Check for distance messages (non-blocking)
    distance = receive do
      {:distance, d} -> d
    after
      0 -> nil
    end
    
    if distance do
      # Map distance to frequency
      frequency = distance_to_frequency(distance)
      freq_rounded = round(frequency)
      
      IO.puts("Distance: #{Float.round(distance, 1)}cm -> Frequency: #{freq_rounded}Hz")
      
      # Generate and send audio (non-blocking)
      pcm_data = AudioStream.generate_tone(freq_rounded, tone_duration_ms)
      AudioStream.send_audio(audio_port, pcm_data)
    end
    
    # Small delay to control loop rate
    Process.sleep(20)
    
    # Continue loop
    loop_nonblocking(tone_duration_ms, audio_port)
  end
  
  @doc """
  Run with blocking audio (original version for comparison)
  """
  def run_blocking(tone_duration_ms \\ 50) do
    IO.puts("Starting ultrasonic sensor...")
    sensor_state = UV.run(50, self())
    
    IO.puts("Theremin started! Move your hand between 5-50cm from sensor")
    IO.puts("Press Ctrl+C twice to stop")
    
    loop_blocking(tone_duration_ms)
    
    UV.stop(sensor_state)
  end
  
  defp loop_blocking(tone_duration_ms) do
    # Get the latest distance
    distance = get_latest_distance()
    
    if distance do
      # Map distance to frequency
      frequency = distance_to_frequency(distance)
      freq_rounded = round(frequency)
      
      # Play the tone with debugging
      IO.puts("Distance: #{Float.round(distance, 1)}cm -> Playing: #{freq_rounded}Hz")
      
      # Try playing the beep and show the result
      result = AudioTest.beep(freq_rounded, tone_duration_ms)
      IO.puts("  Beep result: #{inspect(result)}")
    else
      # No valid reading
      IO.puts("  No distance reading, waiting...")
      Process.sleep(tone_duration_ms)
    end
    
    # Continue loop
    loop_blocking(tone_duration_ms)
  end
  
  @doc """
  Get the most recent distance measurement from the mailbox
  Discards old messages and returns the latest one
  """
  def get_latest_distance() do
    # Flush all messages and get the last one
    messages = flush_distance_messages([])
    
    case messages do
      [] -> nil
      distances -> 
        # Return the most recent (last) distance
        List.last(distances)
    end
  end
  
  defp flush_distance_messages(acc) do
    receive do
      {:distance, distance} ->
        flush_distance_messages([distance | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
  
  @doc """
  Map distance to frequency using logarithmic scale
  Distance: 5cm (close) = 2000Hz (high pitch)
  Distance: 50cm (far) = 200Hz (low pitch)
  """
  def distance_to_frequency(distance) do
    # Clamp distance to valid range
    distance = max(@min_distance, min(@max_distance, distance))
    
    # Normalize distance to 0-1 range (inverted: close = 1, far = 0)
    normalized = 1.0 - (distance - @min_distance) / (@max_distance - @min_distance)
    
    # Logarithmic mapping
    # log(max_freq/min_freq) gives us the range in log space
    log_range = :math.log(@max_freq / @min_freq)
    
    # Scale normalized value to log range and convert back
    @min_freq * :math.exp(normalized * log_range)
  end
  
  @doc """
  Test the frequency mapping
  """
  def test_mapping() do
    distances = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50]
    
    IO.puts("\nDistance -> Frequency mapping:")
    IO.puts("------------------------------")
    
    for d <- distances do
      freq = distance_to_frequency(d)
      IO.puts("#{d}cm -> #{round(freq)}Hz")
    end
  end
  
  @doc """
  Test if we're receiving distance messages
  """  
  def test_messages() do
    IO.puts("Starting message test...")
    
    # Use UV.run which now sends messages to us
    sensor_state = UV.run(100, self())
    
    # Check messages for 2 seconds
    for _ <- 1..20 do
      receive do
        {:distance, d} -> 
          IO.puts("Got distance: #{Float.round(d, 1)}cm")
      after
        100 -> 
          IO.puts("No message...")
      end
    end
    
    UV.stop(sensor_state)
  end
end