#!/usr/bin/env bash

# Installed by the bbPress plugin (plugins.sh --install bbpress); __WORKSPACE__ is the workspace it was installed into.
#
# The forums of one site of this workspace, in the project's web container: say what the forums hold (their
# forums, topics and replies, the forum role of each account), add or cancel the default accounts, add the
# sample content, take away what a stopped test run left. Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="bbpress";

ARGPARSE_DESCRIPTION="The forums of a site of __WORKSPACE__: what they hold, the default accounts, the sample content, a tidy-up"
# The args file comes with the plugin: core/scripts/plugins/bbpress/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/bbpress/args/arg-bbpress-forums.sh || exit 1 ;

shift $#;

bbpress_forums_tool ;
