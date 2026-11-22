#!/usr/bin/env bash

# workspace-name: bbPress (forums on WordPress)

# Installed by the bbPress plugin (plugins.sh --install bbpress); __WORKSPACE__ is the workspace it was installed into.
#
# Build a site with forums in a container, at https://<name>.ddev.site: the WordPress plugin's builder makes
# the site (the latest WordPress, or the one --wordpress-version names), then the free bbPress plugin is
# added from the plugin directory. With --install the forums are set up for testing (pretty addresses, no
# wait between two posts of an account, no time limit on editing one's own post); with --add-users the
# default accounts, one per forum role; with --sample-content the forums and topics the step pack's
# features name. The forums' own tool is cmd-tools-bbpress-forums.sh; WP-CLI is the WordPress plugin's
# tool: bash cmd-tools-wordpress-cli.sh <name> --run "plugin list".

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Set the versions: of bbPress (--version) and of WordPress (--wordpress-version).
site_version="latest";
wordpress_version="latest";

# Distribution.
distribution_name="bbpress";
distribution_title="bbPress";
distribution_webroot="";

ARGPARSE_DESCRIPTION="Build a site with ${distribution_title} forums in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/bbpress/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/bbpress/args/arg-bbpress.sh || exit 1 ;

shift $#;

bbpress_build ;
