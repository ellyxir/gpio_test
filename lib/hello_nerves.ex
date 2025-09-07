defmodule HelloNerves do
  @moduledoc """
  Helper functions for the theremin
  """
  
  def start() do
    IO.puts("Starting Theremin...")
    
    # Start ultrasonic sensor
    case HelloNerves.UltrasonicServer.start_link() do
      {:ok, _pid} -> IO.puts("✓ Ultrasonic sensor started")
      {:error, {:already_started, _}} -> IO.puts("✓ Ultrasonic sensor already running")
      error -> IO.puts("✗ Ultrasonic sensor failed: #{inspect(error)}")
    end
    
    # Small delay to get first reading
    Process.sleep(100)
    
    # Start sound manager
    case HelloNerves.SoundManager.start_link() do
      {:ok, _pid} -> IO.puts("✓ Sound manager started")
      {:error, {:already_started, _}} -> IO.puts("✓ Sound manager already running")
      error -> IO.puts("✗ Sound manager failed: #{inspect(error)}")
    end
    
    IO.puts("\nTheremin ready! Move your hand 5-50cm from sensor")
    :ok
  end
  
  def stop() do
    IO.puts("Stopping Theremin...")
    
    # Stop sound manager first to stop audio
    try do
      HelloNerves.SoundManager.stop()
      IO.puts("✓ Sound manager stopped")
    catch
      :exit, _ -> IO.puts("✓ Sound manager already stopped")
    end
    
    # Stop ultrasonic sensor
    try do
      HelloNerves.UltrasonicServer.stop()
      IO.puts("✓ Ultrasonic sensor stopped")
    catch
      :exit, _ -> IO.puts("✓ Ultrasonic sensor already stopped")
    end
    
    :ok
  end
  
  def debug_timing() do
    IO.puts("Checking timing...")
    
    # Check distance update rate
    d1 = HelloNerves.UltrasonicServer.get_distance()
    Process.sleep(100)
    d2 = HelloNerves.UltrasonicServer.get_distance()
    Process.sleep(100)
    d3 = HelloNerves.UltrasonicServer.get_distance()
    
    IO.puts("Distance readings over 200ms: #{inspect(d1)}, #{inspect(d2)}, #{inspect(d3)}")
    
    if d1 == d2 and d2 == d3 do
      IO.puts("WARNING: Distance not updating!")
    else
      IO.puts("Distance is updating properly")
    end
    
    :ok
  end
end
