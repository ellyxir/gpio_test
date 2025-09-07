defmodule HelloNerves.AudioTest do
  @moduledoc """
  audio test
  """

  @doc """
  Generate a simple sine wave tone and play it
  """
  def beep(frequency \\ 440, duration_ms \\ 1000) do
    sample_rate = 22050
    samples = round(sample_rate * duration_ms / 1000)
    
    # Generate sine wave samples
    pcm_data = generate_sine_wave(frequency, sample_rate, samples)
    
    # Write to temp file
    temp_file = "/tmp/test_tone.raw"
    File.write!(temp_file, pcm_data)
    
    # Play using aplay
    # -f S16_LE = Signed 16-bit Little Endian
    # -r 22050 = Sample rate
    # -c 1 = Mono
    System.cmd("aplay", ["-f", "S16_LE", "-r", "#{sample_rate}", "-c", "1", temp_file])
    
    # Clean up
    File.rm(temp_file)
    :ok
  end

  def startup_sound() do
    beep(261, 200)  # C
    beep(329, 200)  # E
    beep(392, 200)  # G
    beep(523, 400)  # High C
    :ok
  end

  @doc """
  Generate a WAV file for testing
  """
  def generate_wav(filename \\ "/tmp/test.wav", frequency \\ 440, duration_ms \\ 1000) do
    sample_rate = 22050
    samples = round(sample_rate * duration_ms / 1000)
    
    # Generate sine wave
    pcm_data = generate_sine_wave(frequency, sample_rate, samples)
    
    # Create WAV header
    wav_header = create_wav_header(byte_size(pcm_data), sample_rate)
    
    # Write WAV file
    File.write!(filename, wav_header <> pcm_data)
    filename
  end

  # Generate sine wave as 16-bit PCM
  defp generate_sine_wave(frequency, sample_rate, num_samples) do
    omega = 2.0 * :math.pi() * frequency / sample_rate
    
    samples = for i <- 0..(num_samples - 1) do
      # Generate sine wave sample
      value = :math.sin(omega * i)
      # Convert to 16-bit signed integer
      sample = round(value * 32767)
      # Clamp
      sample = max(-32768, min(32767, sample))
      # Convert to little-endian
      <<sample::little-signed-16>>
    end
    
    IO.iodata_to_binary(samples)
  end

  # Create a minimal WAV header
  defp create_wav_header(data_size, sample_rate) do
    # WAV header for 16-bit mono PCM
    channels = 1
    bits_per_sample = 16
    byte_rate = sample_rate * channels * div(bits_per_sample, 8)
    block_align = channels * div(bits_per_sample, 8)
    
    <<
      "RIFF",                           # ChunkID
      (data_size + 36)::little-32,     # ChunkSize
      "WAVE",                           # Format
      "fmt ",                           # Subchunk1ID
      16::little-32,                    # Subchunk1Size (16 for PCM)
      1::little-16,                     # AudioFormat (1 = PCM)
      channels::little-16,              # NumChannels
      sample_rate::little-32,          # SampleRate
      byte_rate::little-32,            # ByteRate
      block_align::little-16,          # BlockAlign
      bits_per_sample::little-16,      # BitsPerSample
      "data",                           # Subchunk2ID
      data_size::little-32             # Subchunk2Size
    >>
  end
end
