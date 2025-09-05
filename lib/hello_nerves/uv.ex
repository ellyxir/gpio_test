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

  # pass in reference()
  def spawn_receiver(echo_gpio) do
    spawn(fn ->
      :ok = Circuits.GPIO.set_interrupts(echo_gpio, :both)
      listen_loop()
    end)
  end

  defp listen_loop() do
    IO.puts("in receiver loop")
    receive do
      {:circuits_gpio, pin, timestamp, value} ->
        IO.puts("pin: #{inspect pin}, timestamp=#{inspect timestamp}, value=#{value}")
      msg ->
        IO.puts("got unknown message: #{inspect msg}")
    end
    listen_loop()
  end
end

