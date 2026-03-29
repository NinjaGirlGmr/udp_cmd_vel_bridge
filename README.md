# Swift Xbox Controller to ROS 2 `cmd_vel`

This workspace contains only the pieces needed to drive a ROS 2 robot from a Mac with an Xbox controller, without requiring ROS 2 discovery on the Mac.

## Components

Mac:

- [`tools/mac_udp_gamepad_sender.swift`](/Users/hailey/ros2_ws/tools/mac_udp_gamepad_sender.swift)
- Native Swift sender using Apple's `GameController` framework
- Sends UDP packets directly to the robot

Robot:

- [`src/udp_cmd_vel_bridge`](/Users/hailey/ros2_ws/src/udp_cmd_vel_bridge)
- ROS 2 package that receives UDP packets and republishes them as `geometry_msgs/msg/Twist`

## Architecture

- The Mac reads the Xbox controller locally.
- The Mac sends JSON UDP packets to the robot at `10.0.0.163:8765`.
- The robot bridge publishes those commands to `/cmd_vel`.
- If packets stop arriving for `0.5` seconds, the robot publishes a zero `Twist`.

This avoids ROS 2 DDS discovery on macOS.

## Packet Format

Each UDP packet is UTF-8 JSON:

```json
{"linear_x": 0.25, "angular_z": -0.4}
```

## Robot Setup

Copy this package into the robot's ROS 2 workspace and run:

```bash
colcon build --symlink-install
source install/setup.bash
ros2 launch udp_cmd_vel_bridge udp_cmd_vel_bridge.launch.py
```

If the robot uses a different command topic:

```bash
ros2 launch udp_cmd_vel_bridge udp_cmd_vel_bridge.launch.py cmd_vel_topic:=/your_robot/cmd_vel
```

Optional launch arguments:

```bash
ros2 launch udp_cmd_vel_bridge udp_cmd_vel_bridge.launch.py \
  listen_host:=0.0.0.0 \
  listen_port:=8765 \
  timeout_s:=0.5
```

## Mac Setup

No ROS 2 is required on the Mac for teleop.

Run:

```bash
cd /Users/hailey/ros2_ws
swift tools/mac_udp_gamepad_sender.swift --host 10.0.0.163 --port 8765
```

Optional sender arguments:

```bash
swift tools/mac_udp_gamepad_sender.swift \
  --host 10.0.0.163 \
  --port 8765 \
  --linear-scale 0.5 \
  --angular-scale 1.2 \
  --turbo-linear-scale 1.0 \
  --turbo-angular-scale 2.0 \
  --rate 20
```

## Controls

- Hold `LB` to enable drive
- Hold `RB` for turbo
- Left stick up/down controls linear velocity
- Left stick left/right controls angular velocity

If neither shoulder button is held, the sender transmits zero motion.

## Verification

On the robot:

```bash
ros2 topic echo /cmd_vel
```

Then move the controller on the Mac.

## Files

- [`README.md`](/Users/hailey/ros2_ws/README.md)
- [`tools/mac_udp_gamepad_sender.swift`](/Users/hailey/ros2_ws/tools/mac_udp_gamepad_sender.swift)
- [`src/udp_cmd_vel_bridge/launch/udp_cmd_vel_bridge.launch.py`](/Users/hailey/ros2_ws/src/udp_cmd_vel_bridge/launch/udp_cmd_vel_bridge.launch.py)
- [`src/udp_cmd_vel_bridge/udp_cmd_vel_bridge/udp_cmd_vel_bridge_node.py`](/Users/hailey/ros2_ws/src/udp_cmd_vel_bridge/udp_cmd_vel_bridge/udp_cmd_vel_bridge_node.py)
