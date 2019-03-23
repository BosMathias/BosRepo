#!/usr/bin/env python

from geometry_msgs.msg import Pose
from std_msgs.msg import Bool, Empty

from bebop_demo.msg import Trigger, Trajectories, Obstacle

from bebop_demo.srv import (ConfigMotionplanner, ConfigMotionplannerResponse,
                            ConfigMotionplannerRequest)

import numpy as np
import omgtools as omg
import rospy

from fabulous.color import highlight_red, magenta, green


class MotionPlanner(object):

    def __init__(self):
        """Initializes motionplanner. Subscribe to topics published by
        controller. Sets self as publisher of topics to which controller
        subscribes.
        """
        self._sample_time = rospy.get_param('controller/sample_time', 0.01)
        self._update_time = rospy.get_param('controller/update_time', 0.5)
        self.knots = rospy.get_param('motionplanner/knot_intervals', 10)
        self.horizon_time = rospy.get_param('motionplanner/horizon_time', 10.)
        self.vmax = rospy.get_param('motionplanner/vmax', 0.2)
        self.amax = rospy.get_param('motionplanner/amax', 0.3)
        self.drone_radius = rospy.get_param('motionplanner/drone_radius', 0.20)
        self.safety_margin = rospy.get_param(
                    'motionplanner/safety_margin', 0.2)

        self._result = Trajectories()
        self._obstacles = []

        self._mp_result_topic = rospy.Publisher(
            'motionplanner/result', Trajectories, queue_size=1)

        rospy.Subscriber('motionplanner/trigger', Trigger, self.update)
        rospy.Subscriber('motionplanner/interrupt', Empty, self.interrupt)

        self.configure = rospy.Service(
            "motionplanner/config_motionplanner", ConfigMotionplanner,
            self.configure)

    def configure(self, obstacles):
        """Configures the motionplanner. Creates omgtools Point2point problem
        with room, static and dynamic obstacles.

        Args:
            obstacles : contains the obstacles sent over the configure service.
        """
        mp_configured = False

        self._vehicle = omg.Holonomic3D(
            shapes=omg.Sphere(self.drone_radius),
            bounds={'vmax': self.vmax, 'vmin': -self.vmax,
                    'amax': self.amax, 'amin': -self.amax})
        self._vehicle.define_knots(knot_intervals=self.knots)
        self._vehicle.set_options({'safety_distance': self.safety_margin,
                                   'syslimit': 'norm_2'})
        self._vehicle.set_initial_conditions([0., 0., 0.])
        self._vehicle.set_terminal_conditions([0., 0., 0.])

        # Environment.
        room_origin_x = rospy.get_param('motionplanner/room_origin_x', 0.)
        room_origin_y = rospy.get_param('motionplanner/room_origin_y', 0.)
        room_origin_z = rospy.get_param('motionplanner/room_origin_z', 0.)
        room_width = rospy.get_param('motionplanner/room_width', 1.)
        room_depth = rospy.get_param('motionplanner/room_depth', 1.)
        room_height = rospy.get_param('motionplanner/room_height', 1.)

        room = {'shape': omg.Cuboid(room_width, room_depth, room_height),
                'position': [room_origin_x, room_origin_y, room_origin_z]}

        for k, obst in enumerate(obstacles.obst_list):
            if obst.type == "cylinder":
                shape = omg.RegularPrisma(obst.shape[0], obst.shape[1], 6)
            elif obst.type in {"plate", "slalom plate"}:
                shape = Plate(shape2d=Rectangle(obst.shape[0], obst.shape[1]),
                              height=obst.shape[2],
                              orientation=[0., np.pi/2, 0.])

            elif obst.type == "cuboid":
                shape = omg.Cuboid(
                    width=obst.shape[0],
                    depth=obst.shape[1],
                    height=obst.shape[2])
                    # orientation=(obst.pose[2]))
            else:
                print highlight_yellow(' Warning: invalid obstacle type ')

            self._obstacles.append(omg.Obstacle({'position': [
                    obst.pose[0], obst.pose[1], obst.pose[2]]}, shape=shape))

        environment = omg.Environment(room=room)
        environment.add_obstacle(self._obstacles)

        # Create problem.
        problem = omg.Point2point(self._vehicle, environment, freeT=False)
        problem.set_options({'solver_options': {'ipopt': {
            'ipopt.linear_solver': 'ma57',
            'ipopt.print_level': 0,
            'ipopt.tol': 1e-4,
            'ipopt.warm_start_init_point': 'yes',
            'ipopt.warm_start_bound_push': 1e-6,
            'ipopt.warm_start_mult_bound_push': 1e-6,
            'ipopt.mu_init': 1e-5,
            'ipopt.hessian_approximation': 'limited-memory'
            }}})

        problem.set_options({
            'hard_term_con': False, 'horizon_time': self.horizon_time,
            'verbose': 2.})

        problem.init()
        problem.fullstop = True

        self._deployer = omg.Deployer(
            problem, self._sample_time, self._update_time)
        self._deployer.reset()

        mp_configured = True
        print green('----   Motionplanner running   ----')

        return ConfigMotionplannerResponse(mp_configured)

    def start(self):
        """Starts the motionplanner by initializing the motionplanner ROS-node.
        """
        rospy.init_node('motionplanner')
        self._goal = Pose()
        self._goal.position.x = np.inf
        self._goal.position.y = np.inf
        self._goal.position.z = np.inf

        rospy.spin()

    def update(self, cmd):
        """Updates the motionplanner and the deployer solving the Point2point
        problem. Publishes trajectories resulting from calculations.

        Args:
            cmd : contains data sent over Trigger topic.
        """
        # In case goal has changed: set new goal.
        print '\n>>>>>>>>>>>>> MP update\n', cmd
        if cmd.goal_pos != self._goal:
            self._goal = cmd.goal_pos
            self._vehicle.set_initial_conditions(
                [cmd.pos_state.position.x,
                 cmd.pos_state.position.y,
                 cmd.pos_state.position.z],
                # [cmd.vel_state.x, cmd.vel_state.y, cmd.vel_state.z]
                )
            self._vehicle.set_terminal_conditions(
                [self._goal.position.x,
                 self._goal.position.y,
                 self._goal.position.z])
            print '>>>>>>>< MP just voor deployer reset'
            self._deployer.reset()
            print magenta('---- Motionplanner received a new goal -'
                          ' deployer resetted ----')

        state0 = [cmd.pos_state.position.x,
                  cmd.pos_state.position.y,
                  cmd.pos_state.position.z]
        input0 = [cmd.vel_state.x, cmd.vel_state.y, cmd.vel_state.z]

        trajectories = self._deployer.update(cmd.current_time, state0) #, input0)

        return_status = self._deployer.problem.problem.stats()['return_status']
        if (return_status != 'Solve_Succeeded'):
            print highlight_red(return_status, ' -- brake! ')
            self._result = Trajectories(
                u_traj=100*[0],
                v_traj=100*[0],
                w_traj=100*[0],
                x_traj=[cmd.pos_state.position.x for i in range(0, 100)],
                y_traj=[cmd.pos_state.position.y for i in range(0, 100)],
                z_traj=[cmd.pos_state.position.z for i in range(0, 100)])

        else:
            self._result = Trajectories(
                u_traj=trajectories['input'][0, :],
                v_traj=trajectories['input'][1, :],
                w_traj=trajectories['input'][2, :],
                x_traj=trajectories['state'][0, :],
                y_traj=trajectories['state'][1, :],
                z_traj=trajectories['state'][2, :])

        self._mp_result_topic.publish(self._result)
        print '>>>>>>>>>>>>>><  MP published result'

    def interrupt(self, empty):
        '''Stop calculations when goal is reached.
        '''
        print '>>>>>>>>>< MP interrupt'
        self._deployer.reset()

if __name__ == '__main__':
    motionplanner = MotionPlanner()
    motionplanner.start()
