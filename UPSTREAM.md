# 上游源码

导入日期：2026-11-10。下列目录是用 `git archive` 从上游仓库指定提交原样导出的文件（只包含上游跟踪的文件），没有做任何修改。更新时，按同样方式从新的提交重新导出并整体覆盖即可。

| 工作区路径 | 上游仓库 | 分支 / 标签 | 提交 |
| --- | --- | --- | --- |
| `src/dingo/dingo` | https://github.com/dingo-cpr/dingo | `noetic-devel`（0.3.1 之后 1 个提交） | `68806fdffabfd612a3414b7e8d6cb19c496f8a0e` |
| `src/dingo/dingo_robot` | https://github.com/dingo-cpr/dingo_robot | `noetic-devel`（0.3.2 之后 2 个提交） | `43bc202f3e7c1bf7d1562a5ec6e00179afb65607` |
| `src/dingo/puma_motor_driver` | https://github.com/clearpathrobotics/puma_motor_driver | 标签 `0.3.1`（Noetic 发布版本，`melodic-devel` 分支） | `e4ca4ce5d0d9c031ae0c676e59be1cabaab87387` |
| `src/z1_ros`（不含 `unitree_ros/`） | https://github.com/unitreerobotics/z1_ros | `noetic` | `d3bafd38fb48e805096da7abb0c19a15b636975d` |
| `src/z1_ros/unitree_ros/robots/z1_description`、`src/z1_ros/unitree_ros/LICENSE` | https://github.com/unitreerobotics/unitree_ros | z1_ros 子模块固定的提交 | `8ebecd883a842a4631fcfa98933fae586aeb6709` |
| `src/z1_ros/unitree_ros/unitree_ros_to_real/unitree_legged_msgs` | https://github.com/unitreerobotics/unitree_ros_to_real | unitree_ros 子模块固定的提交 | `b989870124913091fbe75e0dcfb047eb4ca00a09` |
| `src/pan_tilt_ros` | https://github.com/I-Quotient-Robotics/pan_tilt_ros | `master` | `01b26f3fe3030e76560feede68558b3429cf89e4` |
| `src/realsense-ros` | https://github.com/IntelRealSense/realsense-ros | 标签 `2.3.2`（ROS 1 版本，对应 `ros-noetic-realsense2-camera`） | `f400d682beee6c216052a419f419e95b797255ad` |

关于 `z1_ros` 的子模块：上游通过 git 子模块引用整个 `unitree_ros`（其中包含多款四足机器人模型和 Gazebo 仿真包），`unitree_ros` 又通过子模块引用 `unitree_ros_to_real`。这里只取了真机运行需要的两个包：
- `z1_description`：机械臂模型，`z1_bringup`、`z1_rviz` 用到；
- `unitree_legged_msgs`：`z1_controller` 编译时依赖。

两个包都放在与子模块路径一致的位置。

未以源码形式包含、需要另行安装的依赖：

- **pinocchio v2.7.0**：`z1_controller` 依赖它。按 `src/z1_ros/doc/setup.md` 的官方步骤从源码安装（apt 中的 3.x 版本不兼容）。
- **pybind11 v2.13.6**：z1_ros 的 `z1_sdk` 检测到 pybind11 时会编译 Python 接口，需要从源码安装到 `/usr/local`（原因见 README）。
- **librealsense2**：由 rosdep 安装 `ros-noetic-librealsense2`。
- 其余 ROS 依赖（MoveIt、ros_control、robot_localization、socketcan_interface 等）：由 rosdep 从 apt 安装。

`src/unidingo` 是本项目自己的代码，不属于上游。
