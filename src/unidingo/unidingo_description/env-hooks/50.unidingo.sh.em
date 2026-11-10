# Sourced automatically by devel/setup.bash (or install/setup.bash).
# Configures the official Clearpath Dingo packages for this robot:
#   DINGO_OMNI=1          Dingo-O (omni) chassis, read by dingo_description and dingo_base
#   DINGO_URDF_EXTRAS     official hook that appends the arms, pan-tilt and D455 to dingo.urdf.xacro
#   DINGO_REALSENSE_MODEL=none
#                         dingo accessories.urdf.xacro includes realsense2_description for the
#                         selected model even when no Dingo RealSense is enabled. The D455 here comes
#                         from unidingo_extras.urdf.xacro (official _d455 macro), and including
#                         realsense2_description twice defines its global materials twice, which
#                         makes the URDF fail to parse. "none" matches no model, so dingo skips it.
export DINGO_OMNI=1
export DINGO_REALSENSE_MODEL=none
@[if DEVELSPACE]@
export DINGO_URDF_EXTRAS="@(CMAKE_CURRENT_SOURCE_DIR)/urdf/unidingo_extras.urdf.xacro"
@[else]@
export DINGO_URDF_EXTRAS="$CATKIN_ENV_HOOK_WORKSPACE/share/@(PROJECT_NAME)/urdf/unidingo_extras.urdf.xacro"
@[end if]@
