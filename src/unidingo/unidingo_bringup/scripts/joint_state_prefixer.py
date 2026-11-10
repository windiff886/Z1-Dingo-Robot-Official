#!/usr/bin/env python3
"""Relay one arm's joint_states into the whole-robot /joint_states.

The official z1_hw names its joints joint1..joint6 and jointGripper. In the
whole-robot model the two arms are prefixed (left_joint1, right_joint1, ...),
so this node subscribes to the namespaced ``joint_states`` and republishes
each message on ``/joint_states`` with ``~prefix`` prepended to every name.
"""
import rospy
from sensor_msgs.msg import JointState


def main():
    rospy.init_node("joint_state_prefixer")
    prefix = rospy.get_param("~prefix")
    pub = rospy.Publisher("/joint_states", JointState, queue_size=10)

    def relay(msg):
        msg.name = [prefix + name for name in msg.name]
        pub.publish(msg)

    rospy.Subscriber("joint_states", JointState, relay, queue_size=10)
    rospy.spin()


if __name__ == "__main__":
    main()
