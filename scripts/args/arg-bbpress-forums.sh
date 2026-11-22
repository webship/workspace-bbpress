#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: a site of this folder that has the forums plugin.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Add the default accounts, one per forum role: administrator, keymaster, moderator, participant, spectator and blocked. An account that is there keeps its password and gets its forum role.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts, and the topics and replies they wrote.')
parser.add_argument('-s', '--sample-content',
                    action='store_true',
                    default=False,
                    help='Add the forums and topics the test scenarios name. What is there already is kept.')
parser.add_argument('-t', '--tidy',
                    action='store_true',
                    default=False,
                    help='Take away what a stopped test run left: the topics and replies that are not the sample content, the favorites and subscriptions of the default accounts; the sample content gets its marks back.')
ARGEOF
