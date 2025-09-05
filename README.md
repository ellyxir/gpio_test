# HelloNerves

**TODO: Add description**
In my project, I have:
* Ultrasonic sensor TRIG on GPIO25, it needs a 10uS pulse to activate.
* Ultrasonic sensor ECHO on GPIO21, thats the :input pin.

How to run:
```elixir
{trig, echo} = HelloNerves.UV.open()
pid = HelloNerves.UV.spawn_receiver(echo)
HelloNerves.UV.pulse()
```

## Targets

Nerves applications produce images for hardware targets based on the
`MIX_TARGET` environment variable. If `MIX_TARGET` is unset, `mix` builds an
image that runs on the host (e.g., your laptop). This is useful for executing
logic tests, running utilities, and debugging. Other targets are represented by
a short name like `rpi3` that maps to a Nerves system image for that platform.
All of this logic is in the generated `mix.exs` and may be customized. For more
information about targets see:

https://hexdocs.pm/nerves/supported-targets.html

## Getting Started

To start your Nerves app:
  * `export MIX_TARGET=my_target` or prefix every command with
    `MIX_TARGET=my_target`. For example, `MIX_TARGET=rpi3`
  * Install dependencies with `mix deps.get`
  * Create firmware with `mix firmware`
  * Burn to an SD card with `mix burn`

### Build and Deploy Workflow for Raspberry Pi Zero 2W

For the Raspberry Pi Zero 2W, use the `rpi3a` target:

1. Install dependencies (only needed once):
   ```bash
   MIX_TARGET=rpi3a mix deps.get
   ```

2. Compile the project:
   ```bash
   MIX_TARGET=rpi3a mix compile
   ```

3. Build the firmware:
   ```bash
   MIX_TARGET=rpi3a mix firmware
   ```

4. Deploy to SD card or device:
   ```bash
   # For initial burn to SD card:
   MIX_TARGET=rpi3a mix burn
   
   # For updates over network:
   MIX_TARGET=rpi3a mix upload
   ```

Note: Always include `MIX_TARGET=rpi3a` before each command to ensure you're building for the correct target.

## Learn more

  * Official docs: https://hexdocs.pm/nerves/getting-started.html
  * Official website: https://nerves-project.org/
  * Forum: https://elixirforum.com/c/nerves-forum
  * Elixir Slack #nerves channel: https://elixir-slack.community/
  * Elixir Discord #nerves channel: https://discord.gg/elixir
  * Source: https://github.com/nerves-project/nerves
