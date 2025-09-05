defmodule Trig do
  require Bitwise

  def pulse_us(pin, us) when is_integer(pin) and us >= 1 do
    :ok = Pigpiox.GPIO.set_mode(pin, :output)
    :ok = Pigpiox.GPIO.write(pin, 0)
    :ok = Pigpiox.Waveform.clear_all()

    {:ok, _} =
      Pigpiox.Waveform.add_generic([
        %Pigpiox.Waveform.Pulse{gpio_on: pin, delay: us},
        # use 1 for low delay just to make sure it actually happens
        %Pigpiox.Waveform.Pulse{gpio_off: pin, delay: 1}
      ])

    {:ok, wid} = Pigpiox.Waveform.create()
    {:ok, _} = Pigpiox.Waveform.send(wid)

    # Wait for completion so we don't delete mid-flight
    wait_done()
    :ok = Pigpiox.Waveform.delete(wid)
  end

  defp wait_done do
    case Pigpiox.Waveform.busy?() do
      {:ok, true} ->
        Process.sleep(1)
        wait_done()

      {:ok, false} ->
        :ok

      _ ->
        :ok
    end
  end
end

# Use:
# Trig.pulse_us(17, 10)
