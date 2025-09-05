defmodule HelloNerves.UV do
  @uv_trig 25
  @uv_echo 21
  @trigger_duration_us 10

  def open() do
    {:ok, trig} = Circuits.GPIO.open("GPIO#{@uv_trig}", :output)
    {:ok, echo} = Circuits.GPIO.open("GPIO#{@uv_echo}", :input)
    {trig, echo}
  end

  def pulse() do
    Trig.pulse_us(@uv_trig, @trigger_duration_us)
  end

  def run() do
    {trig, echo} = open()
    pid = spawn_receiver(echo)
    pulse()
    {trig, echo, pid}
  end

  # pass in reference()
  def spawn_receiver(echo_gpio) do
    spawn(fn ->
      :ok = Circuits.GPIO.set_interrupts(echo_gpio, :both)
      listen_loop(nil)
    end)
  end

  defp listen_loop(rising_timestamp) do
    IO.puts("in receiver loop")

    receive do
      {:circuits_gpio, pin, timestamp, value} ->
        IO.puts("pin: #{inspect(pin)}, timestamp=#{inspect(timestamp)}, value=#{value}")

        case {value, rising_timestamp} do
          {1, _} ->
            # Rising edge - echo started
            IO.puts("Echo started - Rising timestamp: #{timestamp}")
            listen_loop(timestamp)

          {0, nil} ->
            # Falling edge but no rising edge recorded - ignore
            IO.puts("Falling edge without rising edge - ignoring")
            listen_loop(nil)

          {0, rising_ts} ->
            # Falling edge - echo ended, calculate distance
            IO.puts("Echo ended - Falling timestamp: #{timestamp}")
            IO.puts("Rising timestamp was: #{rising_ts}")
            duration_ns = timestamp - rising_ts
            IO.puts("Duration: #{duration_ns} ns")
            distance_cm = calculate_distance(duration_ns)
            IO.puts("Distance: #{distance_cm} cm")
            listen_loop(nil)

          _ ->
            listen_loop(rising_timestamp)
        end

      msg ->
        IO.puts("got unknown message: #{inspect(msg)}")
        listen_loop(rising_timestamp)
    end
  end

  # Calculate distance from echo duration
  # Speed of sound is ~343 m/s at 20°C
  # Distance = (Duration × Speed of Sound) / 2
  # We divide by 2 because the sound travels to the object and back
  defp calculate_distance(duration_ns) do
    # Convert nanoseconds to seconds
    duration_s = duration_ns / 1_000_000_000

    # Speed of sound in cm/s (343 m/s = 34300 cm/s)
    speed_of_sound = 34300

    # Calculate distance (divide by 2 for round trip)
    distance = duration_s * speed_of_sound / 2

    # Round to 2 decimal places
    Float.round(distance, 2)
  end
end
