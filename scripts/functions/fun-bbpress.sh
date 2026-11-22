#!/usr/bin/env bash

# bbPress for the Webship Workspace: build a site with forums on WordPress, add its default accounts (one
# per forum role), add the sample content, and wire its step pack into the testing setup, next to the
# WordPress step pack it extends.
#
# Placed by `plugins.sh --install bbpress` in core/scripts/plugins/bbpress/functions/, where bootstrap
# sources it with the core's own functions and the WordPress plugin's: this plugin needs
# @webship.co/workspace-wordpress, and its builder starts from that plugin's wordpress_build.
# Everything runs in the project's container (DDEV by default: `ddev wp …`), never on the host. The
# container tool writes the database settings, so nothing here writes any.
#
# The forums have no command line of their own: their settings, the forum roles and the sample content are
# written with the forums' own functions by forum-site.php (beside these functions), run with WP-CLI in the
# container. WP-CLI itself is the WordPress plugin's tool:
#   bash cmd-tools-wordpress-cli.sh <site> --run "plugin list"
#
# A site with forums is a project of the type `wordpress`. The builder leaves .ddev/config.bbpress.yaml in
# it: the claim of this plugin on the project, by which the core's tools take the test users of the forums
# for it instead of the WordPress list. Four names are the ones the core's tools look for:
#   set_bbpress_users          the default accounts        (cmd-tools-add-users.sh <project> bbpress)
#   add_bbpress_users          create them with WP-CLI     (the same tool, and --add-users of the builder)
#   cancel_bbpress_users       delete them                 (cmd-tools-cancel-users.sh <project> bbpress)
#   testing_configure_bbpress  the step pack in the testing stack (cmd-tools-testing.sh <project>)

# The step pack a site with forums is tested with, and the release line it is required at. It brings the
# WordPress step pack along; the WordPress plugin's hook adds that one too.
readonly BBPRESS_STEPS_PACKAGE='@webship-js/bbpress-steps';
readonly BBPRESS_STEPS_VERSION='^2.0.0';

# The default accounts: one per forum role, the ones a scenario logs in as. Accounts are configuration,
# created once on the site; a test suite never creates or deletes one.
#   administrator  an administrator of the site (a second one: the installer's is the workspace account), a keymaster of the forums
#   keymaster      Keymaster: everything in the forums, their settings and tools
#   moderator      Moderator: every topic and reply, the hidden forums
#   participant    Participant: topics and replies, the private forums
#   spectator      Spectator: reads the public forums
#   blocked        Blocked: no forum at all
# Each but the administrator is a subscriber of the site; the forum role is apart from the role on the site.
function set_bbpress_users() {
  users=(administrator keymaster moderator participant spectator blocked);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
    printf -v "user_${user}_role" '%s' 'subscriber' ;
    printf -v "user_${user}_forum_role" '%s' "bbp_${user}" ;
  done
  user_administrator_role='administrator' ;
  user_administrator_forum_role='bbp_keymaster' ;
}

# Is this folder a site with forums? The builder leaves its claim in it; a WordPress project that got the
# forums plugin another way has the plugin's folder, at its root or in its docroot.
function bbpress_is_project() {
  local project_path="$1" ;
  [ -f "${project_path}/.ddev/config.bbpress.yaml" ] && return 0 ;
  [ -f "${project_path}/wp-content/plugins/bbpress/bbpress.php" ] && return 0 ;
  compgen -G "${project_path}/*/wp-content/plugins/bbpress/bbpress.php" > /dev/null ;
}

# Go to the project a tool was asked about, or say why not.
function bbpress_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! bbpress_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a site with forums: a WordPress project with bbPress in its plugins." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# The claim of this plugin on a project, in the folder of the container tool: a config overlay with one key
# the web container does not use, the name of the platform the project was built as. The core's tools read
# the file's name: a project that carries config.<plugin>.yaml takes the test users of that plugin.
function bbpress_write_claim() {
  local project_path="$1" ;
  mkdir -p "${project_path}/.ddev" || return 1 ;
  cat > "${project_path}/.ddev/config.bbpress.yaml" <<'YAMLEOF'
# Written by the bbPress plugin of the Webship Workspace (cmd-bbpress-project.sh).
#
# It is the plugin's claim on this project: the workspace's tools take the test users of the forums for it
# (cmd-tools-add-users.sh <project> bbpress) instead of the WordPress list. The key below is in the
# environment of the web container from its next start; nothing of the site reads it.
web_environment:
  - WEBSHIP_WORKSPACE_PLATFORM=bbpress
YAMLEOF
}

# Run forum-site.php in the site, in the project folder: the forums' settings, the forum roles, the sample
# content, a tidy-up, a status, each written or read with the forums' own functions.
function bbpress_forum_site() {
  local script="${WORKSPACE_SCRIPTS}/plugins/bbpress/forum-site.php" status ;
  if [ ! -f "${script}" ] ; then
    echo "The bbPress plugin's forum-site.php is not at ${script}: install the plugin again (plugins.sh --install bbpress)." ;
    return 1 ;
  fi
  cp "${script}" .webship-forum-site.php || return 1 ;
  ddev wp eval-file .webship-forum-site.php "$@" < /dev/null ;
  status=$? ;
  rm -f .webship-forum-site.php ;
  return ${status} ;
}

# Build a site with forums from nothing: the WordPress plugin's builder makes the site, then bbPress is added.
function bbpress_build() {
  trim_project_name ;
  local base_url="https://${PROJECT_NAME}.ddev.site" ;
  local bbpress_version="${VERSION:-${site_version:-latest}}" ;
  local add_users="${ADD_USERS}" launch="${LAUNCH}" ;

  if ! declare -f wordpress_build > /dev/null ; then
    echo "The bbPress plugin builds on the WordPress plugin, which is not installed here:" ;
    echo "  bash core/scripts/plugins.sh --install wordpress" ;
    exit 1 ;
  fi

  # The site, by the WordPress plugin's builder: the container, WordPress, and with --install the site
  # with the workspace account as its administrator. Its --version is WordPress's; the accounts and the
  # browser come after the forums are set up.
  VERSION="${WORDPRESS_VERSION:-${wordpress_version:-latest}}" ;
  ADD_USERS='no' ; LAUNCH='no' ;
  ( wordpress_build ) || exit 1 ;
  ADD_USERS="${add_users}" ; LAUNCH="${launch}" ;

  cd "${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" || exit 1 ;
  bbpress_write_claim "${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" || { echo "The plugin's claim on the project could not be written." ; exit 1 ; } ;

  if [ "${INSTALL}" != 'yes' ] ; then
    # No site yet: bbPress goes into the plugins, to activate once WordPress is installed.
    local zip="bbpress.latest-stable.zip" ;
    [ "${bbpress_version}" != 'latest' ] && zip="bbpress.${bbpress_version}.zip" ;
    ddev exec "curl -fsSL https://downloads.wordpress.org/plugin/${zip} -o /tmp/bbpress.zip && unzip -oq /tmp/bbpress.zip -d wp-content/plugins && rm -f /tmp/bbpress.zip" < /dev/null \
      || { echo "bbPress could not be downloaded." ; exit 1 ; } ;
    [ "${ADD_USERS}" == 'yes' ] && echo "--add-users needs --install: there is no site to add accounts to yet." ;
    [ "${SAMPLE_CONTENT}" == 'yes' ] && echo "--sample-content needs --install: there are no forums to add the content to yet." ;
    echo "${doc_name} ${PROJECT_NAME} is ready to install, with bbPress in its plugins.";
    echo "Go to ${base_url}";
    cd ${WORKSPACE_ROOT}/${doc_name};
    return 0 ;
  fi

  # Pretty addresses: the forums live at /forums/, a forum at /forums/forum/<name>/, a topic at /forums/topic/<name>/.
  ddev wp rewrite structure '/%postname%/' < /dev/null > /dev/null ;
  ddev wp plugin install bbpress $( [ "${bbpress_version}" != 'latest' ] && echo "--version=${bbpress_version}" ) --activate < /dev/null \
    || { echo "bbPress could not be installed." ; exit 1 ; } ;
  # The forums' settings, as the plugin sets them but for two a test suite cannot work with: no wait
  # between two posts of an account (the flood protection), no time limit on editing one's own post.
  bbpress_forum_site settings || { echo "The forums could not be set up." ; exit 1 ; } ;

  # The accounts before the content: each sample topic is written by the account of its forum role.
  if [ "${ADD_USERS}" == 'yes' ] ; then
    set_bbpress_users ;
    add_bbpress_users ;
    cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;
  fi

  if [ "${SAMPLE_CONTENT}" == 'yes' ] ; then
    [ "${ADD_USERS}" == 'yes' ] || echo "Without --add-users the sample content is written by the administrator of the site." ;
    bbpress_forum_site content || { echo "The sample content could not be added." ; exit 1 ; } ;
  fi

  # The addresses of the forums answer once the rules are written again: a plugin activated from the
  # command line does not write them.
  ddev wp rewrite flush < /dev/null > /dev/null 2>&1 ;
  echo "${doc_name} ${PROJECT_NAME} has been installed: WordPress $(ddev wp core version 2>/dev/null < /dev/null), bbPress $(ddev wp plugin get bbpress --field=version 2>/dev/null < /dev/null).";
  echo "Go to ${base_url}/forums/, and ${base_url}/wp-admin as ${account_name}";

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch /forums/ ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Create the default accounts with WP-CLI, each with its role on the site, then give each its forum role
# with the forums' own function; an account that is already there keeps its password and gets both roles.
# The list is loaded by the caller (set_bbpress_users): the core's add_users, the builder, the forums'
# tool, the testing setup.
function add_bbpress_users() {
  bbpress_enter_project || return 1 ;
  local user user_name user_mail user_password user_role user_forum_role forum_role ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role";
    user_forum_role="user_${user}_forum_role"; forum_role="${!user_forum_role:-bbp_participant}" ;

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role}";
    echo "     Forum role: ${forum_role#bbp_}";
    echo " ================================================================= ";

    if ddev wp user get "${!user_name}" --field=ID < /dev/null > /dev/null 2>&1 ; then
      echo "   ${!user_name} is already there." ;
      ddev wp user set-role "${!user_name}" "${!user_role}" < /dev/null > /dev/null ;
    else
      ddev wp user create "${!user_name}" "${!user_mail}" --role="${!user_role}" --user_pass="${!user_password}" < /dev/null ;
    fi
    # WP-CLI's eval takes one argument, the code: the login goes in it as base64, so no character of a
    # name can break the code's quoting.
    ddev wp eval '$u = get_user_by( "login", base64_decode( "'"$(printf '%s' "${!user_name}" | base64 | tr -d '\n')"'" ) ); if ( $u && function_exists( "bbp_set_user_role" ) ) { bbp_set_user_role( $u->ID, "'"${forum_role}"'" ); }' < /dev/null > /dev/null \
      || echo "   the forum role of ${!user_name} could not be set: is bbPress active on the site?" ;
  done
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Delete the default accounts. The topics and replies they wrote stay, without an author: forum-site.php gives
# each sample topic and reply its author back once the accounts are on the site again (--sample-content, --tidy).
function cancel_bbpress_users() {
  bbpress_enter_project || return 1 ;
  local user user_name ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
    if ddev wp user get "${!user_name}" --field=ID < /dev/null > /dev/null 2>&1 ; then
      ddev wp user delete "${!user_name}" --yes < /dev/null ;
    else
      echo "   ${!user_name} is not there." ;
    fi
  done
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# What cmd-tools-bbpress-forums.sh does: the first of --add-users, --cancel-users, --sample-content,
# --tidy that was asked for; with none of them, what the forums hold.
function bbpress_forums_tool() {
  trim_project_name ;
  bbpress_enter_project || exit 1 ;

  if ! ddev wp core is-installed < /dev/null > /dev/null 2>&1 ; then
    ddev start -y < /dev/null || exit 1 ;
  fi
  if ! ddev wp plugin is-active bbpress < /dev/null > /dev/null 2>&1 ; then
    echo "${doc_name}/${PROJECT_NAME}: bbPress is not active on the site (is WordPress installed? bash cmd-tools-wordpress-cli.sh ${PROJECT_NAME})." ;
    exit 1 ;
  fi

  if [ "${ADD_USERS}" == 'yes' ] ; then
    set_bbpress_users ;
    add_bbpress_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    set_bbpress_users ;
    cancel_bbpress_users ;
  elif [ "${SAMPLE_CONTENT}" == 'yes' ] ; then
    bbpress_forum_site content || exit 1 ;
    ddev wp rewrite flush < /dev/null > /dev/null 2>&1 ;
  elif [ "${TIDY}" == 'yes' ] ; then
    bbpress_forum_site reset || exit 1 ;
    echo "The forums are back as the sample content left them." ;
  else
    echo "${doc_name}/${PROJECT_NAME}: bbPress $(ddev wp plugin get bbpress --field=version 2>/dev/null < /dev/null) on WordPress $(ddev wp core version 2>/dev/null < /dev/null), at $(ddev wp option get siteurl 2>/dev/null < /dev/null)/forums/" ;
    echo "" ;
    bbpress_forum_site status || exit 1 ;
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a site with forums. The core's testing_configure calls this in the
# project folder once webship-js is scaffolded and before the dependencies are installed; for a project
# without forums it changes nothing.
#
# The forums' pack extends the WordPress pack, and both go in the same profile: the WordPress plugin's
# hook runs first (its pack, its users registry, its first feature), whichever order the core calls the
# hooks in; then this one adds its pack to package.json and its step definitions to cucumber.js, the tags
# that keep its assertions that must fail out of a normal run, the mail catcher of the project, the
# forums' handles in the users registry (with the addresses the notification steps read), and a first
# feature for the forums when the project has none. Every part is skipped when it is already there, so a
# second run adds what the first missed and never resets a suite.
function testing_configure_bbpress() {
  local project_path="$1";
  bbpress_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  bbPress: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  if declare -f testing_configure_wordpress > /dev/null ; then
    testing_configure_wordpress "${project_path}" || return 1 ;
  fi

  echo "Adding the bbPress step pack (${BBPRESS_STEPS_PACKAGE} ${BBPRESS_STEPS_VERSION}).";
  set_bbpress_users ;
  local registry="" user user_name user_mail user_password handle ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail"; user_password="user_${user}_password";
    # The WordPress pack's features call the administrator "admin".
    handle="${user}" ; [ "${user}" == 'administrator' ] && handle="admin" ;
    registry="${registry}${handle}|${!user_name}|${!user_password}|${!user_mail}"$'\n' ;
  done

  python3 - "${project_path}" "${BBPRESS_STEPS_PACKAGE}" "${BBPRESS_STEPS_VERSION}" 'WP' "${registry}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry = sys.argv[1:6]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=2) + '\n')
    print('  package.json: %s %s' % (pack, version))

cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

# The pack's step definitions, after webship-js's own (and the WordPress pack's, which it loads itself).
if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    anchor = re.search(r"^([ \t]*)'node_modules/@webship-js/wordpress-steps/tests/step-definitions/[^']*',.*$", src, re.M) \
        or re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if anchor:
        src = src[:anchor.end()] + '\n' + anchor.group(1) + line + src[anchor.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

# The pack's assertions that must fail are no part of a normal run.
if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        src = src[:default.end()] + '\n' + pad + "// Work in progress and the assertions that must fail (@must-fail) stay out of a normal run.\n" \
            + pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail'," + src[default.end():]
        print('  cucumber.js: the tags that keep the assertions that must fail out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
pad = world.group(1) + '  '

# The mail catcher of the project: the forums' notifications are read in it (port 8026 of a DDEV project).
if not re.search(r"^[ \t]*mailUrl:", src, re.M):
    block = pad + "// The mail catcher of the project (the notification steps read it).\n" \
        + pad + "mailUrl: process.env.MAIL_URL || (process.env.LAUNCH_URL || '').replace(/\\/+$/, '') + ':8026',"
    src = src[:world.end()] + '\n' + block + src[world.end():]
    print('  cucumber.js: the mail catcher of the project')
    world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)

rows = [r.split('|') for r in registry.splitlines() if r.strip()]
entry = lambda handle, name, password, mail: "%s: { username: process.env.%s_%s_USER || '%s', password: process.env.%s_%s_PASSWORD || '%s', email: '%s' }," % (
    handle, prefix, handle.upper(), name, prefix, handle.upper(), password, mail)
users = re.search(r"^([ \t]*)users:[ \t]*\{[ \t]*$", src, re.M)
if users:
    # The registry the WordPress plugin wrote: the forums' handles it does not have go in at its start, and a
    # handle it has without an address (admin) gets the address the notification steps read.
    missing = [r for r in rows if not re.search(r"^[ \t]*%s:[ \t]*\{" % re.escape(r[0]), src, re.M)]
    if missing:
        inner = users.group(1) + '  '
        src = src[:users.end()] + '\n' + '\n'.join(inner + entry(*r) for r in missing) + src[users.end():]
        print('  cucumber.js: the forums\' accounts in the users registry (%s)' % ', '.join(r[0] for r in missing))
    for handle, name, password, mail in rows:
        line = re.search(r"^([ \t]*%s:[ \t]*\{)([^\n]*)(\},?[ \t]*)$" % re.escape(handle), src, re.M)
        if line and 'email:' not in line.group(2):
            src = src[:line.start()] + line.group(1) + line.group(2).rstrip() + ", email: '%s' " % mail + line.group(3) + src[line.end():]
else:
    block = [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of this site (the default",
        pad + "// accounts: cmd-tools-add-users.sh <project> bbpress). Override one with %s_<HANDLE>_USER and %s_<HANDLE>_PASSWORD." % (prefix, prefix),
        pad + "users: {",
    ] + [pad + '  ' + entry(*r) for r in rows] + [pad + "},"]
    src = src[:world.end()] + '\n' + '\n'.join(block) + src[world.end():]
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature for the forums, when the project has none: the forum index, a topic, each forum role
  # in its place.
  local feature="${WORKSPACE_SCRIPTS}/plugins/bbpress/forums.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/forums.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/forums.feature" \
      && echo "  tests/features/forums.feature: a first feature for the forums" ;
  fi

  # The scenarios log in as the default accounts: make sure an installed site has them.
  if ddev wp core is-installed < /dev/null > /dev/null 2>&1 ; then
    ( add_bbpress_users > /dev/null ) && echo "  the forums' default accounts are on the site (${users[*]})" ;
  fi
}
