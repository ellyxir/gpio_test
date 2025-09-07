defmodule HelloNerves.AudioStream do
  @moduledoc """
  Non-blocking audio playback using Port
  """
  
  @doc """
  Start an aplay process that accepts raw PCM data
  Returns a port that can be sent audio data
  """
  def start_aplay(sample_rate \\ 22050) do
    Port.open({:spawn, "aplay -f S16_LE -r #{sample_rate} -c 1 -q"}, [:binary])
  end
  
  @doc """
  Send PCM data to the audio port
  Non-blocking - returns immediately
  """
  def send_audio(port, pcm_data) do
    Port.command(port, pcm_data)
  end
  
  @doc """
  Generate a sine wave tone as PCM data
  """
  def generate_tone(frequency, duration_ms, sample_rate \\ 22050) do
    samples = round(sample_rate * duration_ms / 1000)
    omega = 2.0 * :math.pi() * frequency / sample_rate
    
    pcm_data = for i <- 0..(samples - 1) do
      value = :math.sin(omega * i)
      sample = round(value * 32767)
      sample = max(-32768, min(32767, sample))
      <<sample::little-signed-16>>
    end
    
    IO.iodata_to_binary(pcm_data)
  end
  
  @doc """
  Stop the audio port
  """
  def stop(port) do
    Port.close(port)
  end
end