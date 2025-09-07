defmodule HelloNerves.UltrasonicServer do
  use GenServer
  
  @uv_trig 25
  @trigger_duration_us 10
  @measurement_interval 50  # ms between measurements
  
  defmodule State do
    defstruct [:trig, :echo, :receiver_pid, :latest_distance, :history, max_history: 10]
  end
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, Keyword.put_new(opts, :name, __MODULE__))
  end
  
  def get_distance() do
    GenServer.call(__MODULE__, :get_distance)
  end
  
  def get_smoothed_distance(window_size \\ 5) do
    GenServer.call(__MODULE__, {:get_smoothed_distance, window_size})
  end
  
  def get_history() do
    GenServer.call(__MODULE__, :get_history)
  end
  
  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_) do
    # Open GPIO pins using UV.open()
    {trig, echo} = HelloNerves.UV.open()
    
    # Spawn receiver using UV.spawn_receiver()
  # TK: lets try and move this listen_loop() logic into ultrasonic sensor, i think
  # we can just make this a handle_info() instead of a loop right?
  # so we set interrupts ourselves here then we add our handle_info that
  # does the same thing that listen_loop does
  # still use calculate_disntace and all that from the uv module
    receiver_pid = HelloNerves.UV.spawn_receiver(echo)
    
    # Schedule the sensor loop to start
    Process.send_after(self(), :loop_sensor, 100)
    
    state = %State{
      trig: trig,
      echo: echo,
      receiver_pid: receiver_pid,
      latest_distance: nil,
      history: []
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:get_distance, _from, state) do
    {:reply, state.latest_distance, state}
  end
  
  @impl true
  def handle_call({:get_smoothed_distance, window_size}, _from, state) do
    recent = Enum.take(state.history, window_size)
    smoothed = if length(recent) > 0 do
      Enum.sum(recent) / length(recent)
    else
      state.latest_distance
    end
    {:reply, smoothed, state}
  end
  
  @impl true
  def handle_call(:get_history, _from, state) do
    {:reply, state.history, state}
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
  
  
  @impl true
  def handle_info(:loop_sensor, state) do
    # Send pulse to trigger ultrasonic measurement
    Trig.pulse_us(@uv_trig, @trigger_duration_us)
    
    # Schedule next pulse
    Process.send_after(self(), :loop_sensor, @measurement_interval)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:distance, distance}, state) do
    # Update state with new distance
    new_history = [distance | state.history] |> Enum.take(state.max_history)
    
    new_state = %{state | 
      latest_distance: distance,
      history: new_history
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def terminate(_reason, state) do
    # Cleanup GPIO and processes
    if state.receiver_pid, do: Process.exit(state.receiver_pid, :shutdown)
    if state.trig, do: Circuits.GPIO.close(state.trig)
    if state.echo, do: Circuits.GPIO.close(state.echo)
    :ok
  end
  
end
