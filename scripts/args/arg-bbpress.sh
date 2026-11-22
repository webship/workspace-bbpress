#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('-v', '--version',
                    default="${site_version}",
                    help='The bbPress release to add, from the plugin directory: latest, or a version number. Example: --version 2.6.22 [default %(default)s]')
parser.add_argument('-w', '--wordpress-version',
                    default="${wordpress_version}",
                    help='The WordPress release to download: latest, nightly, or a version number. Example: --wordpress-version 7.1.5 [default %(default)s]')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Install WordPress with the workspace account as the administrator, and set the forums up for testing: pretty addresses, no wait between two posts of an account, no time limit on an account editing its posts.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts, one per forum role: administrator, keymaster, moderator, participant, spectator and blocked, the ones the test scenarios log in as.')
parser.add_argument('-s', '--sample-content',
                    action='store_true',
                    default=False,
                    help='With --install, add the forums and topics the test scenarios name: a category with two forums, a forum of sixteen topics, a closed, a private and a hidden forum, sticky and closed topics, topic tags.')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the forums in a browser when they are ready.')
parser.add_argument('--locale',
                    default="en_US",
                    help='The language WordPress is downloaded in. Example: --locale ar [default %(default)s]')
parser.add_argument('--php-version',
                    default="",
                    choices=['8.5', '8.4', '8.3', '8.2'],
                    help='PHP version for the project container; empty means the default of the container tool. Example: --php-version 8.4')
ARGEOF
