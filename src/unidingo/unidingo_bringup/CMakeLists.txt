cmake_minimum_required(VERSION 3.0.2)
project(unidingo_bringup)

find_package(catkin REQUIRED)

catkin_package()

catkin_install_python(PROGRAMS scripts/joint_state_prefixer.py
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(DIRECTORY launch
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
