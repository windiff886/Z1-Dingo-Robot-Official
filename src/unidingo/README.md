# unidingo：整机模型与启动

本目录是工作区中唯一由本项目编写的部分，其他四个目录都是官方源码原样拷贝。这里只做两件事：

- 把官方组件拼成整机模型；
- 提供双臂和整机的启动文件。

| 包 | 内容 |
| --- | --- |
| `unidingo_description` | 整机模型附加结构、带前缀的 Z1 宏、env hook、模型查看入口、原始 CAD 导出数据（`cad/`） |
| `unidingo_bringup` | `arms.launch`（双臂）、`z1_arm.launch`（单臂，带命名空间）、`robot.launch`（整机）、`joint_state_prefixer.py` |

## 整机模型

整机模型没有另起一个顶层 URDF，而是使用 Clearpath 官方的扩展机制：

1. `source devel/setup.bash` 时，[env hook](unidingo_description/env-hooks/50.unidingo.sh.em) 设置两个变量：
   - `DINGO_OMNI=1`
   - `DINGO_URDF_EXTRAS=.../unidingo_extras.urdf.xacro`
2. 官方 `dingo-o.urdf.xacro` 在末尾 include `DINGO_URDF_EXTRAS` 指向的文件。
3. 因此，凡是加载 Dingo 官方模型的入口（`dingo_base/base.launch`、`dingo_description/description.launch`），得到的都是完整整机模型，`robot_state_publisher` 也由它们启动。

[unidingo_extras.urdf.xacro](unidingo_description/urdf/unidingo_extras.urdf.xacro) 在 Dingo 的 `base_link` 上挂了以下部件：

| 部件 | 来源 | 坐标系 |
| --- | --- | --- |
| 左右臂支撑柱 | 本包 | `leftarm_link` / `rightarm_link`（柱顶），位于 `(0.15091, ±0.11708, 0.57228)` |
| 左右 Z1 | [z1_arm.urdf.xacro](unidingo_description/urdf/z1_arm.urdf.xacro) | `left_link00…left_link06`、`left_gripperStator`、`left_gripperMover`；右臂同理，前缀为 `right_` |
| 云台 | 官方 `pan_tilt_description` 宏 | `pan_tilt_base_link`、`pan_tilt_yaw_link`、`pan_tilt_pitch_link`、`pan_tilt_surface` |
| D455 | 官方 `realsense2_description` 的 `sensor_d455` 宏 | `d455_bottom_screw_frame`、`d455_link`；各光学坐标系由相机驱动按出厂外参发布 |

安装位置都写在 `unidingo_extras.urdf.xacro` 顶部的属性里，实测后直接修改即可。

`z1_arm.urdf.xacro` 由脚本从官方 `z1_description/xacro/robot.xacro` 机械转换而来：几何、限位、惯量和网格都没有改，只做了以下几处改动：
- 给 link 和 joint 名称加前缀；
- 把根部的 `world` 换成挂载关节；
- 夹爪开关改为宏参数；
- 去掉仅用于仿真的 transmission。

**夹爪**：默认两臂都装有宇树原装夹爪。更换夹爪后，在 `~/.bashrc` 中设置：

```bash
export UNIDINGO_LEFT_GRIPPER=false    # 或 UNIDINGO_RIGHT_GRIPPER=false
```

整机模型和 `arms.launch` 读取的是同一组变量，所以两边会保持一致。

## 双臂

官方 `z1_ros` 只支持单臂：`z1_hw` 的关节名固定为 `joint1…joint6`、`jointGripper`。为了不改上游代码，两条臂各自运行一套完整的官方栈，用命名空间隔开，用不同端口区分：

```text
/left_arm   z1_ctrl ─UDP─ 左臂 MCU 192.168.123.110
            z1_hw_node + joint_state_controller + z1_joint_traj_controller
            move_group（官方 z1_moveit_config）
            joint_state_prefixer: /left_arm/joint_states → /joint_states（加 left_ 前缀）
/right_arm  同上，右臂 MCU 192.168.123.111，前缀 right_
```

| 参数 | 左臂 | 右臂 | 官方默认 |
| --- | --- | --- | --- |
| MCU IP | 192.168.123.110 | 192.168.123.111 | 192.168.123.110 |
| `z1_ctrl` ↔ MCU 本机端口 `udp/port_to_mcu` | 8881 | 8882 | 8881 |
| `z1_ctrl` SDK 端口 `udp/port_to_sdk` | 8871 | 8873 | 8871 |
| `z1_hw` 本机端口 `udp_to_controller/own_port` | 8872 | 8874 | 8872 |

左臂使用的全是官方默认值。这些参数在 [z1_arm.launch](unidingo_bringup/launch/z1_arm.launch) 中覆盖官方 `config.yaml` 对应的项，IP 也可以通过 `arms.launch` 的 `left_mcu_ip` / `right_mcu_ip` 参数修改。

### 接口（以左臂为例）

| 接口 | 类型 | 说明 |
| --- | --- | --- |
| `/left_arm/joint_states` | `sensor_msgs/JointState` | 官方关节名（`joint1…`） |
| `/left_arm/z1_joint_traj_controller/follow_joint_trajectory` | `control_msgs/FollowJointTrajectory` action | 关节轨迹 |
| `/left_arm/z1_gripper` | `control_msgs/GripperCommand` action | 夹爪 |
| `/left_arm/move_group` 等 | MoveIt | 规划组为 `manipulator`，命名状态为 `home` |

在 Python 中使用 MoveIt：

```python
import moveit_commander
left = moveit_commander.MoveGroupCommander(
    "manipulator", robot_description="left_arm/robot_description", ns="left_arm")
left.set_named_target("home")
left.go(wait=True)
```

C++ 用法参考官方 [move_group_interface.cpp](../z1_ros/z1_examples/examples/move_group_interface.cpp)。把节点放进 `left_arm` 命名空间运行（例如 `ROS_NAMESPACE=left_arm`），即可使用对应的那条臂。

### 坐标系与限制

- **坐标系**：每条臂的 MoveIt 使用官方单臂模型，规划坐标系是该臂的 `world`，它和 `link00` 重合，在整机 TF 中就是 `left_link00` / `right_link00`。如果目标位姿是在 `base_link` 等整机坐标系下给出的，先用 TF 变换到 `left_link00` 或 `right_link00`，再把坐标原样作为 `world` 下的位姿交给对应的 MoveIt。
- **限制**：两个 move_group 互相看不到对方，也看不到底盘和云台，不会检查两臂之间的碰撞，也不能做双臂协同规划。两臂工作空间可能重叠时，需要上层自行协调。
- **RViz**：`arms.launch rviz:=true` 会在每个命名空间里打开官方 `z1_rviz`，用于该臂的 MoveIt 交互。整机模型请用 `robot.launch rviz:=true` 查看。

## 整机启动

`roslaunch unidingo_bringup robot.launch` 依次启动：

| 组件 | 实际 include 的文件 | 主要话题 |
| --- | --- | --- |
| 底盘 | `dingo_base/launch/base.launch`（官方） | `/cmd_vel`（经 twist_mux）、`/odometry/filtered`、`/dingo_velocity_controller/odom`、`/imu/data` |
| 双臂 | `unidingo_bringup/launch/arms.launch` | 见上一节 |
| 云台 | `pan_tilt_bringup/launch/panTilt_bringup.launch`（官方） | `/pan_tilt_cmd_deg`、`/pan_tilt_cmd_rad`、`/pan_tilt_status` |
| 相机 | `realsense2_camera/launch/rs_camera.launch`（官方，`camera:=d455`，640×480@30，`align_depth:=true`） | `/d455/color/image_raw`、`/d455/aligned_depth_to_color/image_raw` 等 |

`/joint_states` 汇集了三路关节状态：底盘车轮、云台，以及两臂经 `joint_state_prefixer` 加前缀后的关节。整机 `robot_state_publisher` 据此发布完整 TF。

可选参数：`base`、`arms`、`pan_tilt`、`camera`（各组件开关，默认都为 `true`）、`moveit`、`rviz`、`pan_tilt_port`、`camera_serial_no`。
