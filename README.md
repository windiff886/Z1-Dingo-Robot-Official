# Z1-Dingo 双臂机器人

Clearpath Dingo-O 全向底盘 + 两台宇树 Z1 机械臂 + IQR 二轴云台 + Intel RealSense D455，ROS 1 Noetic（Ubuntu 20.04）工作区。

四个组件全部使用官方源码，按上游提交原样拷入、未做修改，来源与提交号见 [UPSTREAM.md](UPSTREAM.md)。本机的整机模型和启动配置只放在 `src/unidingo`。

```text
src/
├── dingo/            底盘：dingo、dingo_robot、puma_motor_driver（Clearpath 官方）
├── z1_ros/           机械臂：z1_ros（宇树官方 ROS 驱动）+ unitree_ros 中的 z1_description、unitree_legged_msgs
├── pan_tilt_ros/     云台：IQR 官方驱动
├── realsense-ros/    相机：Intel realsense2_camera / realsense2_description 2.3.2
└── unidingo/         整机：unidingo_description（整机模型）、unidingo_bringup（双臂与整机启动）
```

## 1. 安装依赖

```bash
sudo apt install python3-rosdep python3-catkin-tools
cd <仓库根目录>
rosdep install --from-paths src --ignore-src -r -y
```

rosdep 会从 apt 安装 MoveIt、ros_control、robot_localization、librealsense2 等依赖。下面几步按[宇树官方步骤](src/z1_ros/doc/setup.md)手动完成。

**Eigen 软链接**：官方 SDK 和 pybind11 用 `#include <Eigen/Core>` 引用 Eigen，需要先建立软链接：

```bash
sudo ln -s /usr/include/eigen3/Eigen /usr/local/include/Eigen
sudo ln -s /usr/include/eigen3/unsupported /usr/local/include/unsupported
```

另有两个库要从源码安装到 `/usr/local`：

**pinocchio 2.7.0**：`z1_controller` 依赖 pinocchio，官方说明它不兼容 3.x，而 apt 中的 `ros-noetic-pinocchio` 是 3.x：

```bash
git clone --recursive -b v2.7.0 https://github.com/stack-of-tasks/pinocchio
cd pinocchio && mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DBUILD_PYTHON_INTERFACE=OFF -DBUILD_TESTING=OFF
make -j4 && sudo make install
```

**pybind11 v2.13.6**：`z1_ros/z1_sdk` 只要检测到 pybind11，就会编译 Python 接口。MoveIt 依赖的 `ros-noetic-pybind11-catkin` 自带一份 pybind11 的 CMake 配置，它给出的头文件路径不对，会导致编译失败，所以必须安装官方 pybind11，并让它排在前面。官方文档没有固定版本，但 pybind11 3.x 要求 Python ≥ 3.9，Ubuntu 20.04 的 Python 3.8 只能用 2.13 系列：

```bash
git clone -b v2.13.6 https://github.com/pybind/pybind11.git
cd pybind11 && mkdir build && cd build
cmake .. -DPYBIND11_TEST=OFF
sudo make install
```

然后把以下几行加入 `~/.bashrc`，`/usr/local` 要排在 `/opt/ros/noetic` 前面：

```bash
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export CMAKE_PREFIX_PATH=/usr/local:$CMAKE_PREFIX_PATH
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
```

## 2. 构建

```bash
source /opt/ros/noetic/setup.bash
catkin_make --pkg unitree_legged_msgs -DCMAKE_BUILD_TYPE=Release   # 官方要求先单独编译消息包
catkin_make -DCMAKE_BUILD_TYPE=Release
source devel/setup.bash
```

第一次编译时，要先单独编译 `unitree_legged_msgs`。这是宇树官方文档里规定的顺序：`z1_controller` 没有声明对消息生成的依赖，直接全量编译会报找不到 `unitree_legged_msgs/MotorCmd.h`。之后增量编译不需要再分两步。

`source devel/setup.bash` 时，`unidingo_description` 的 env hook 会自动设置 `DINGO_OMNI=1` 和 `DINGO_URDF_EXTRAS`。前者让官方 Dingo 包按 Dingo-O 工作，后者把双臂、云台和相机并入底盘官方模型。

## 3. 一次性硬件准备

| 组件 | 准备工作 |
| --- | --- |
| 底盘 | 底盘 MCU 经 UDP 转 CAN（`vcan0`）通信。可用官方安装脚本 `rosrun dingo_bringup install`（需 `ROBOT_SETUP` 与 robot_upstart，会注册 `can-udp-bridge` 服务）；也可只部署 [can-udp-bridge.sh](src/dingo/dingo_robot/dingo_bringup/scripts/can-udp-bridge.sh) 与 [can-udp-bridge.conf](src/dingo/dingo_robot/dingo_bringup/scripts/can-udp-bridge.conf) 两个文件 |
| 机械臂 | 两臂 MCU 分别为 `192.168.123.110`（左）和 `192.168.123.111`（右），主机网卡设在 `192.168.123.x` 网段 |
| 云台 | `sudo cp src/pan_tilt_ros/pan_tilt_bringup/config/56-pan-tilt.rules /etc/udev/rules.d/`，重新插拔后生成 `/dev/pan_tilt` |
| 相机 | 安装 librealsense 的 udev 规则（随 `ros-noetic-librealsense2` 安装，或见 Intel 文档） |

## 4. 启动

### 单独启动各组件

| 组件 | 命令 | 说明 |
| --- | --- | --- |
| 底盘 | `roslaunch dingo_base base.launch` | 官方入口：驱动、控制器、EKF、twist_mux、手柄与交互遥控。速度指令发到 `/cmd_vel` |
| 双臂 | `roslaunch unidingo_bringup arms.launch` | 左右臂分别位于 `/left_arm`、`/right_arm`。只启动一臂时加 `right:=false` 或 `left:=false` |
| 单臂（官方原样） | `roslaunch z1_bringup real_arm.launch` | 宇树官方入口，默认 IP 为 `192.168.123.110`，不带命名空间 |
| 云台 | `roslaunch pan_tilt_bringup panTilt_bringup.launch` | 官方入口，串口默认 `/dev/pan_tilt` |
| 相机 | `roslaunch realsense2_camera rs_camera.launch camera:=d455 align_depth:=true` | 官方入口 |

### 启动整机

```bash
roslaunch unidingo_bringup robot.launch            # 全部
roslaunch unidingo_bringup robot.launch rviz:=true # 同时打开整机模型
roslaunch unidingo_bringup robot.launch base:=false pan_tilt:=false   # 按需关闭部分组件
```

不接硬件、只查看整机模型：`roslaunch unidingo_description view_model.launch`。

整机启动的组成、话题、坐标系和双臂的使用方法见 [src/unidingo/README.md](src/unidingo/README.md)。

## 5. 已知的上游问题

以下问题来自官方源码。按照“不修改上游”的原则保留原样，这里只记录规避方法：

- `pan_tilt_bringup/panTilt_view.launch`（以及 `pub_urdf:=true`）调用了 Noetic 已移除的 `xacro.py`，会启动失败。请改用 `panTilt_bringup.launch`；如需查看模型，用 `roslaunch pan_tilt_description view_model.launch`。
- `z1_bringup/sim_*.launch`（Gazebo 仿真）依赖 `unitree_gazebo`。本工作区只取了 `unitree_ros` 中真机需要的两个包，所以仿真入口不可用。
