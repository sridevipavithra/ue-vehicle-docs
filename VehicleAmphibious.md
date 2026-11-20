# Vehicle Amphibious

Turns any Chaos wheeled vehicle into an amphibious one. It floats, carves through the water like a boat, and folds its wheels away as it transforms. It drives back onto land on its own.

- Buoyancy from a set of hull points, with separate float heights for car mode, boat mode and planing
- Directional water drag: cheap to move forward, expensive to slide sideways, so the boat carves
- Boat handling from the vehicle's normal throttle, brake and steering input: thrust, rudder, banking and bow lift
- Car ↔ boat transformation with timing that won't flicker at the shoreline, plus optional folding-wheel animation
- Works with any water system through a small query object
- Multiplayer: server-authoritative mode, forces applied every physics step on every machine
- Editor tools: tuning presets, a hull and waterline visualizer, data validation and map check

Engine: Unreal Engine 5.8. Platforms: Windows, macOS, Android and iOS. Requires the **Chaos Vehicles** plugin. The plugin enables it for you.

Programmers: the C++ reference, `VehicleAmphibious-CPP.md`, comes with the plugin in its `Docs` folder. It covers the architecture, the C++ API and how to extend it.

---

## Quick start (5 minutes)

1. Enable **Vehicle Amphibious** in *Edit → Plugins* and restart the editor.
2. Open your vehicle Blueprint. It needs a *Chaos Wheeled Vehicle Movement* component, as in Epic's Vehicle template. Click **Add → Amphibious**.
3. On the new component, set **Water** to **Flat Water**. Set *Surface Height* to the world Z of your water, or set *Height From Actor Tag* to a tag on your water plane actor.
4. *(Optional)* Visual wheels that should fold away: press **Fill Folding Wheels From Sockets** under *Transformation*. You can also add them by hand in *Folding Wheels*.
5. Press Play and drive into the water.

To change the handling, edit the values under *Tuning*, or assign one of the presets in `VehicleAmphibious/Presets` (Default, Heavy, Nimble).

> If **Water** is not set, the component reports an error in the Message Log, on screen and in the log, then disables itself. Data validation and Map Check catch it before you play.

---

## Demo map

Open `VehicleAmphibious Content/Demo/Maps/Map_AmphibiousDemo` and press Play. To see the plugin's content in the Content Browser, turn on *Settings → Show Plugin Content*.

The map has land, a beach sloping into the sea, a pier to drive off and buoys to steer around. The sea surface is at height 0. Lighting is fully dynamic, so there is nothing to build.

| Key | Gamepad | Touch | |
|---|---|---|---|
| W / S or ↑ / ↓ | Right / left trigger, or left stick up / down | Joystick up / down | Drive / brake, then reverse when stopped |
| A / D or ← / → | Left stick | Joystick left / right | Steer |
| Space | A | | Handbrake |
| X | B | STOP button | Stop and hold still; never reverses |
| R | Y | RESET button | Back to the start, at rest and in car mode |

Speed and gear are shown at the bottom of the screen. On phones and tablets a movement joystick (bottom left) and the STOP and RESET buttons (bottom right) appear as well. To try them on a PC, start the game with `-faketouches`; the mouse then acts as a finger. In `BP_AmphibiousCar`, clear *HUD Class* to hide the HUD, or set *Touch Interface* to your own Touch Interface asset to replace the joystick.

**Tuning playground:** open `Demo/BP_AmphibiousCar` and select the **Amphibious** component. Every water, buoyancy, boat and transformation setting is there, and the presets in `Presets/` are one click away under *Tuning*. Car handling is on the **Vehicle Movement** component.

The demo car is a placeholder: a box body, four cylinder wheels and a chase camera, built on the sample class `AAmphibiousDemoVehicle` (module `VehicleAmphibiousDemo`). Your own vehicles don't need any of it. They only need the Amphibious component (see Quick start). To try your own mesh on the demo car, set the Mesh component's skeletal mesh in `BP_AmphibiousCar`. Its physics asset must have a body on the root bone, and the four wheel bones are named `Wheel_FL`, `Wheel_FR`, `Wheel_RL` and `Wheel_RR`. Each wheel is positioned by its *Additional Offset* in Vehicle Movement → Wheel Setups.

To use your own input, assign an Input Mapping Context and Input Actions in the car's *Input* category. When those are left empty, the controls above are created at runtime.

**Multiplayer:** the demo's game mode, `GM_AmphibiousDemo`, places each player's car in a row beside the map's Player Start: the first on it, then alternately right and left, *Spawn Spacing* apart (default 6 m). With several Player Starts in a map, it uses the one whose *Player Start Tag* is `Anchor`. To try it, set *Number of Players* to 2 and *Net Mode* to *Play As Listen Server* in the Play options.

> **Before testing multiplayer, turn on two Project Settings** (see *Smooth client movement*): **Tick Physics Async** with a step of `0.016667`, and **Enable Physics Prediction**. Restart the editor afterwards. Without them, the driving player's car jitters. The demo car already uses the matching replication mode. For a realistic test, also untick *Run Under One Process* in the Play options' *Advanced Settings*.

---

## Water

The component asks a **Water** object where the surface is. It does this for each hull point, every physics step.

### Flat Water (included)

An infinite plane at a fixed height, with an optional swell.

| Setting | Meaning |
|---|---|
| Surface Height | World Z of the calm surface (cm) |
| Height From Actor Tag | If set, the surface height is taken from the top of the first actor with this tag when play starts |
| Swell Height / Period / Wavelength | A gentle sine swell, so floating does not feel static |

### Using another water system

Make a subclass of **Amphibious Water**, in Blueprint or C++, and override two functions:

- **Initialize Water** (*Vehicle*) → *bool*: called once at Begin Play. Find your water here. Return *false* if the level has no water; the vehicle then drives as a normal car.
- **Get Water Surface** (*Location*, *Time*) → *Surface Z*, *bool*: the world height of the water surface at *Location*. Return *false* where there is no water, such as outside a lake.

Then pick your subclass in the component's **Water** setting.

Rules for a good water query:

- **Keep it cheap.** It runs a few times per hull point per physics step.
- **Use the *Time* parameter for waves.** It is synchronized server time, so every machine in a multiplayer game computes the same surface.
- **Return the visible surface height.** If your ocean shader moves vertices with World Position Offset, match that lift (the visualizer helps).

#### Example: Unreal's Water plugin (Blueprint)

1. Create a Blueprint class with parent **Amphibious Water**, for example `BP_UnrealWater`. Add a variable `WaterBody` of type *Water Body Component*.
2. Override **Initialize Water**: *Get Actor Of Class (Water Body Ocean)* → *Get Water Body Component* → set `WaterBody`. Return `Is Valid (WaterBody)`.
3. Override **Get Water Surface**: call `WaterBody` → **Get Water Surface Info At Location** (*In Location* = *Location*). Set *Surface Z* = *Out Water Surface Location*.Z, and return the node's result.
4. On the Amphibious component, set **Water** to `BP_UnrealWater`.

For lakes and rivers, look up the water body under the vehicle instead of one ocean. For example, overlap the Water Body's collision, or ask the Water subsystem.

#### Example: C++

```cpp
// MyOceanWater.h
#include "AmphibiousWater.h"
#include "Kismet/GameplayStatics.h"
#include "MyOceanWater.generated.h"

UCLASS(meta=(DisplayName="My Ocean"))
class UMyOceanWater : public UAmphibiousWater
{
    GENERATED_BODY()

protected:
    virtual bool InitializeWater_Implementation(UAmphibiousComponent* Vehicle) override
    {
        Ocean = UGameplayStatics::GetActorOfClass(GetWorld(), AMyOcean::StaticClass());
        return Ocean != nullptr;
    }

    virtual bool GetWaterSurface_Implementation(const FVector& Location, double Time, double& SurfaceZ) const override
    {
        SurfaceZ = CastChecked<AMyOcean>(Ocean)->GetWaveHeight(Location, Time);
        return true;
    }

    UPROPERTY(Transient)
    TObjectPtr<AActor> Ocean;
};
```

---

## How it decides between car and boat

```
Car ──(submerged ≥ Enter Boat Submersion and few wheels touching ground)──▶ ToBoat ──(folded)──▶ Boat
 ▲                                                                                               │
 └──(unfolded)── ToCar ◀──(submerged ≤ Exit Boat Submersion and most wheels on the ground)───────┘
```

Both conditions must hold for *Switch Delay* seconds. *Boat Alpha* (0 = car, 1 = boat) blends:
- float height
- keel drag
- boat controls
- wheel folding

While the vehicle floats with its wheels off the ground, wheel drive is cut so the engine doesn't race. The wheels turn slowly, as if paddling.

Validation rejects contradictory thresholds: *Exit* must be below *Enter*, and *Min Grounded Fraction To Land* above *Max Grounded Fraction Afloat*.

---

## Settings reference

All values show units in the Details panel. Hover any setting for its tooltip.

**Hull**
- *Hull Points*: sample points in vehicle-body space. Leave empty to generate six from the body's bounds. Use at least three.

**Tuning**: either assign a **Tuning** preset asset, or edit the four groups below. When a preset is assigned, the groups are greyed out.

| Group | Key settings |
|---|---|
| Buoyancy | Rest Depth (car), Boat Rest Depth, Planing Rest Depth, Planing Speed, Max Point Depth, Damping |
| Water Drag | Forward Drag and Lateral Drag (linear, quadratic), Angular Drag, Boat Keel Drag Floor |
| Boat | Thrust Accel, Reverse Thrust Scale, Brake Accel (how hard braking stops the boat), Coast Drag (how quickly it slows with no throttle), Turn Accel, Standstill Turn Scale, Full Turn Speed, Bank Accel, Bow Lift Accel, Car Paddle Scale, Full Control Submersion, Reverse Steer Speed, Floating wheel spin |
| Transformation | Duration, Enter / Exit Boat Submersion, Max Grounded Fraction Afloat, Min Grounded Fraction To Land, Switch Delay, Fold Lift / Tuck, Turbine Spin / Spool Rate |

**Folding Wheels**: visual wheel components that fold flat in boat mode. Each one must be attached to the vehicle body (usually to a wheel bone socket), with its axle along the component's own Y axis, as Unreal's vehicle wheel meshes are. If your wheel mesh's axle points another way, attach it to a scene component and fold that instead. Leave the list empty for no wheel animation. *Fill Folding Wheels From Sockets* fills the list with every component attached to a socket whose name starts with *Folding Wheel Socket Prefix* (default `VisWheel`).

### Editor visualizer

Select the Amphibious component in the Blueprint editor or the level:

| Colour | Shows |
|---|---|
| Yellow dots | Hull points |
| Blue | Waterline at rest in car mode |
| Cyan | Waterline at rest in boat mode |
| Green | Waterline when planing at full speed |

---

## Vehicle HUD

The plugin includes a drop-in HUD: speed, gear and, on amphibious vehicles, CAR / BOAT. It works with any Chaos wheeled vehicle and any player controller.

1. In your player controller's **Begin Play**, call **Show Amphibious Vehicle HUD** with the player controller. In C++: `UAmphibiousVehicleHUD::Show(PlayerController);`
2. That's all. The HUD follows whatever vehicle the player drives, checking every frame, so it is right on multiplayer clients (where the vehicle arrives after the controller starts), after respawns and when switching vehicles.

Options: *Use Mph*, *Show Mode*. For your own look, make a Widget Blueprint from *Amphibious Vehicle HUD* with TextBlocks named `SpeedText`, `GearText` and `ModeText`, and pass it as *Widget Class*. The demo uses `AmphibiousDemoPlayerController`, which does exactly step 1.

> Finding the vehicle once in Begin Play does not work on multiplayer clients: the controller starts before its vehicle arrives over the network. Epic's Vehicle template HUD does this, so it stays at 0 on clients; use this HUD or fetch the vehicle in **On Possessed Pawn Changed**.

## Blueprint API

| Function / event | Description |
|---|---|
| Get Mode, Get Boat Alpha | Current mode and transformation progress |
| Get Submersion, Is In Water, Get Hull Depth | How deep the hull is |
| Get Water Surface Z, Query Water Surface | Water height under the vehicle, or anywhere |
| Has Water | False when no water was found |
| Set Water, Set Tuning, Set Folding Wheel Components | Change setup at runtime |
| Reset To Car | Snap back to car mode with no transformation, for respawns and resets. Place the vehicle on land first |
| Show Amphibious Vehicle HUD | Puts the drop-in vehicle HUD on a player's screen (see *Vehicle HUD*) |
| On Mode Changed | Fires on every machine when the mode changes |
| On Entered Water / On Left Water | Fire when the hull touches or leaves the water. Use them for splashes. |

### Using it with other systems

The component does not depend on any other plugin. To drive something from the water state, read *Get Boat Alpha* and *Get Submersion* each tick. Examples: a boost that works on water, a camera that pulls back in boat mode:

```cpp
const float BoatAlpha = Amphibious->GetBoatAlpha();
SpringArm->TargetArmLength = BaseArmLength + BoatAlpha * 150.0f;	// pull the camera back in boat mode
const bool bOnWater = BoatAlpha > 0.5f && Amphibious->GetSubmersion() > 0.02f;	// e.g. switch your boost to water handling
```

---

## Multiplayer

The component replicates by default. Nothing to set up.

- **The driver decides the mode, the server checks it.** The driving client detects car/boat switches itself, so the transformation starts the instant it hits the water. The server checks each switch against its own simulation and relays it to everyone with a start time, so all machines play it in sync. Requests that don't hold up are rejected; the driver is corrected, then waits half a second before trying again. An example is boat mode on dry land.
- **Vehicles without a remote driver** are decided by the server itself: AI, parked vehicles, the listen-server host and single player.
- **Multiplayer settings:**
  - *Owner Decides Mode*: on by default. Turn it off to have the server decide everything.
  - *Validate Mode Requests*.
  - *Mode Validation Window*: how recently the server must have seen the vehicle afloat or landed. Default 1 s; raise it for high-latency games.
- **Water forces run on every machine,** from the driver's replicated input. The local prediction then matches the server's.
- **Water is sampled at synchronized server time,** so waves line up across machines.
- **Supported physics replication modes:** *Default*, *Predictive Interpolation* and *Resimulation*. Resimulation is recommended for the driving player; see below.

### Smooth client movement (recommended)

By default, Chaos vehicles in multiplayer are pulled back toward the server's position, which looks like jitter on the driving client. Unreal's built-in fix is **Physics Prediction with Resimulation**: the client simulates ahead, and when the server disagrees, the engine rewinds and replays the physics invisibly. The plugin supports it fully: its forces run on the physics thread and take part in replays.

1. *Project Settings → Physics → Framerate*: tick **Tick Physics Async**, with an *Async Fixed Time Step Size* of **0.016667** (60 Hz). Check the zeros: 0.16667 runs physics at only 6 Hz, and the car stutters.
2. *Project Settings → Physics → Replication*: tick **Enable Physics Prediction**. Restart the editor; it is read at startup.
3. **Physics Replication Mode: Resimulation** on the vehicle. The Amphibious component sets this for you when Physics Prediction is on (*Use Resimulation With Prediction*, under Multiplayer), unless you chose another mode yourself. Vehicles without the component: set it in Class Defaults or with `SetPhysicsReplicationMode(EPhysicsReplicationMode::Resimulation);`

To measure it on the demo car, enter `AmphibiousDemo.Corrections 1` in the client's console: with these settings its largest jump stays around 1 cm.

In our tests at 80 ms latency, the driving client's largest correction fell from 1–4 m to a few centimetres, as smooth as single player.

---

## Physics details

- **Forces are applied on the physics thread, every physics step.** The result does not depend on frame rate, and the forces are replayed correctly during network resimulation. Each frame the game thread samples the water around the hull (height and slope), so custom water queries stay ordinary Blueprint or C++ code.
- **The component auto-activates.** Deactivating it stops all water forces.
- **Hull points** are in the space of the vehicle body (the movement component's updated component, normally the skeletal mesh).

## Debug commands (development builds)

| Command | |
|---|---|
| `Amphibious.Debug.Log 1` | Log state once per second |
| `Amphibious.Debug.HUDLog 1` | Log what each Amphibious Vehicle HUD shows once per second, with the machine's role |
| `Amphibious.Debug.DropInWater [MinDepth] [FaceShore]` | Teleport vehicles onto nearby deep water |
| `Amphibious.Debug.Tuning <AssetPath>` | Apply a tuning preset to every vehicle |
| `Amphibious.Debug.DropOnSpawn <MinDepth>` | Server drops each vehicle into water after it spawns (negative = facing the shore) |
| `Amphibious.Debug.RequestMode <Mode>` | Force a mode switch on the driving machine without checks. Use it to test server validation. |
| `Amphibious.Debug.RequestModeOnSpawn <Mode>` | Same, 3 s after the vehicle spawns (for automated tests) |
| `AmphibiousDemo.AutoThrottle <0..1>` | Demo car only: drive hands-free with this throttle |
| `AmphibiousDemo.Log 1` | Demo car only: log position, speed and mode once per second and on every mode change |
| `AmphibiousDemo.AutoSteer 1` | Demo car only: steer with this input (-1..1) once in boat mode, to test turning hands-free |
| `AmphibiousDemo.Corrections 1` | Demo car only: log once a second how far your own car jumped from where its velocity took it. Network corrections show up here as jitter |
| `AmphibiousDemo.AutoReverse 1` | Demo car only: hold the brake once in boat mode, so the boat stops and reverses |
| `AmphibiousDemo.Debug.TouchTest [Delay]` | Demo car only: plays real touch events on the touch controls (drive, release, drive, hold STOP, RESET) and logs input, speed and mode. Needs touch controls (`-faketouches` on PC) |
| `AmphibiousDemo.WheelLog 1` | Demo car only: log how smoothly the visual wheel turns compared with the raw physics value |
| `AmphibiousDemo.CameraYaw 90` | Demo car only: turn the chase camera around the car by this many degrees, to watch the wheels fold from the side |

None of this code exists in Shipping builds.

## Packaging a Blueprint-only project

The plugin contains C++ code. A Blueprint-only project packaged for another platform (Android, iOS, consoles, Linux) skips compiling code, and staging fails with *Missing receipt '…\Binaries\<Platform>\<Project>.target'*. Make the project a C++ project once: **Tools → New C++ Class**, pick **None**, and create it. Package again; Unreal now compiles the game with the plugin. Windows packages work either way.

## Troubleshooting

| Symptom | Check |
|---|---|
| The driving player's car jitters in multiplayer | Physics Prediction and Tick Physics Async (step 0.016667) must be on; see *Smooth client movement*. Measure with `AmphibiousDemo.Corrections 1`. |
| Packaging fails with *Missing receipt …target* | Blueprint-only project; see *Packaging a Blueprint-only project* |
| The vehicle sinks | Is **Water** set? Is the surface height right? Is the hull too far below it? Look at the blue waterline in the visualizer. |
| Switches back and forth at the shore | Widen the gap between *Enter* and *Exit Boat Submersion*, or increase *Switch Delay* |
| The vehicle floats too high or too low | *Rest Depth* (car) and *Boat Rest Depth* |
| The wheels don't fold | They must be in *Folding Wheels* and attached directly to the vehicle body. Errors are listed in the Message Log. |
| The wheels fold the wrong way (end up standing or sideways) | The wheel's axle is not along its Y axis. Put the mesh under a scene component, rotate the mesh so its axle lines up with the parent's Y axis, and list the scene component in *Folding Wheels*. |
| Floats but won't move on water | *Thrust Accel*. In a custom vehicle, check that its input reaches the Chaos movement component. |

## Support

Support: [sridevipavithra64@gmail.com](mailto:sridevipavithra64@gmail.com) · Documentation: https://sridevipavithra.github.io/ue-vehicle-docs/VehicleAmphibious.html
