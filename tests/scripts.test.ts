import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-bbpress.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['ts-node/register'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

// What the WordPress plugin's testing hook (@webship.co/workspace-wordpress 1.0.11) writes into that
// scaffold: its pack after webship-js's, and its users registry at the start of worldParameters.
const WORDPRESS_PART = `function testing_configure_wordpress() {
  echo "wordpress hook" >> "\${DDEV_LOG:-/dev/null}" ;
  python3 - "$1" <<'PY'
import re, sys, json
p = sys.argv[1]
pkg = json.load(open(p + '/package.json'))
pkg.setdefault('devDependencies', {})['@webship-js/wordpress-steps'] = '^2.2.0'
open(p + '/package.json', 'w').write(json.dumps(pkg, indent=2) + '\\n')
s = open(p + '/cucumber.js').read()
if 'wordpress-steps' not in s:
    s = s.replace("'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.",
        "'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.\\n      'node_modules/@webship-js/wordpress-steps/tests/step-definitions/**/*.js',")
    s = s.replace("    worldParameters: {\\n", "    worldParameters: {\\n      users: {\\n        admin: { username: process.env.WP_ADMIN_USER || 'administrator', password: process.env.WP_ADMIN_PASSWORD || 'dD.123123ddd' },\\n        editor: { username: process.env.WP_EDITOR_USER || 'editor', password: process.env.WP_EDITOR_PASSWORD || 'dD.123123ddd' },\\n      },\\n")
    open(p + '/cucumber.js', 'w').write(s)
PY
}`;

/**
 * A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled.
 * `forums` says how the project carries its forums: 'claim' (the builder's .ddev/config.bbpress.yaml), 'plugin'
 * (the forums plugin in its plugins, at the root or in a docroot), or none.
 */
function project(forums: 'claim' | 'plugin' | 'docroot' | 'none' = 'claim') {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'bbpress-plugin-'));
  const dir = path.join(root, 'dev', 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'site1', devDependencies: { 'webship-js': '^2.0.16' } }, null, 2));
  if (forums === 'claim') fs.writeFileSync(path.join(dir, '.ddev', 'config.bbpress.yaml'), 'web_environment:\n  - WEBSHIP_WORKSPACE_PLATFORM=bbpress\n');
  if (forums === 'plugin' || forums === 'docroot') {
    const plugins = path.join(dir, forums === 'docroot' ? 'web' : '', 'wp-content', 'plugins', 'bbpress');
    fs.mkdirSync(plugins, { recursive: true });
    fs.writeFileSync(path.join(plugins, 'bbpress.php'), '<?php\n');
  }
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'bbpress'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'forums.feature'), path.join(scripts, 'plugins', 'bbpress', 'forums.feature'));
  fs.copyFileSync(path.join(PKG, 'scripts', 'forum-site.php'), path.join(scripts, 'plugins', 'bbpress', 'forum-site.php'));
  return { root, dir, scripts };
}

/** Run bash with the plugin's functions sourced and `ddev` replaced by a recorder. */
function bash(script: string, env: Record<string, string> = {}) {
  const r = spawnSync('bash', ['-c', `ddev() { echo "ddev $*" >> "\${DDEV_LOG:-/dev/null}" ; [ "$1 $2" = "wp eval" ] && echo "wp eval got $(( $# - 2 )) argument(s)" >> "\${DDEV_LOG:-/dev/null}" ; [ "$1 $2" = "wp eval-file" ] && echo "the script is there: $(ls -a | grep -c '^\\.webship-forum-site\\.php$')" >> "\${DDEV_LOG:-/dev/null}" ; return 0 ; }\nsource ${FUNCTIONS}\n${script}`],
    { encoding: 'utf8', env: { ...process.env, ...env } });
  return r;
}

test('the default accounts are one per forum role, with example addresses; the forum role is apart from the role on the site', () => {
  const r = bash('set_bbpress_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; l="user_${u}_role" ; f="user_${u}_forum_role" ; echo "${!n}|${!m}|${!p}|${!l}|${!f}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['administrator', 'keymaster', 'moderator', 'participant', 'spectator', 'blocked']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['administrator', 'subscriber', 'subscriber', 'subscriber', 'subscriber', 'subscriber']);
  assert.deepStrictEqual(rows.map((x) => x[4]), ['bbp_keymaster', 'bbp_keymaster', 'bbp_moderator', 'bbp_participant', 'bbp_spectator', 'bbp_blocked']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.ok(password.length >= 8);
  }
});

test('a site with forums carries the builder\'s claim, or the forums plugin in its plugins; a plain site is not one', () => {
  assert.strictEqual(bash(`bbpress_is_project ${project('claim').dir}`).status, 0);
  assert.strictEqual(bash(`bbpress_is_project ${project('plugin').dir}`).status, 0);
  assert.strictEqual(bash(`bbpress_is_project ${project('docroot').dir}`).status, 0, 'the plugin in a docroot counts too');
  assert.strictEqual(bash(`bbpress_is_project ${project('none').dir}`).status, 1);
});

test('the accounts are created with their role on the site, and each gets its forum role with the forums\' own function', () => {
  const p = project();
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log };
  let r = bash('set_bbpress_users ; add_bbpress_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const written = fs.readFileSync(log, 'utf8');
  // The recorder answers "wp user get" with success: each account is there already and gets its role.
  assert.match(written, /^ddev wp user set-role administrator administrator$/m);
  for (const name of ['keymaster', 'moderator', 'participant', 'spectator', 'blocked']) assert.match(written, new RegExp(`^ddev wp user set-role ${name} subscriber$`, 'm'));
  // WP-CLI's eval takes one argument, the code; the login is in it, as base64.
  for (const [name, role] of [['administrator', 'bbp_keymaster'], ['moderator', 'bbp_moderator'], ['blocked', 'bbp_blocked']]) {
    const encoded = Buffer.from(name).toString('base64');
    assert.ok(written.includes(`base64_decode( "${encoded}" ) ); if ( $u && function_exists( "bbp_set_user_role" ) ) { bbp_set_user_role( $u->ID, "${role}" ); }`), `${name} gets ${role}`);
  }
  const evals = written.match(/^wp eval got \d+ argument\(s\)$/gm) || [];
  assert.strictEqual(evals.length, 6, 'one for each account');
  for (const line of evals) assert.strictEqual(line, 'wp eval got 1 argument(s)', 'wp eval takes the code and nothing else');
  assert.match(r.stdout, /Forum role: keymaster/);
  fs.writeFileSync(log, '');
  r = bash('set_bbpress_users ; cancel_bbpress_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  for (const name of ['administrator', 'keymaster', 'moderator', 'participant', 'spectator', 'blocked']) assert.match(fs.readFileSync(log, 'utf8'), new RegExp(`^ddev wp user delete ${name} --yes$`, 'm'));
});

test('the builder makes the site with the WordPress plugin\'s builder, claims it, then sets the forums up, adds the accounts and the content', () => {
  const p = project('none');
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, account_name: 'webmaster' };
  const r = bash(`trim_project_name() { :; } ; wordpress_build() { echo "wordpress_build VERSION=$VERSION ADD_USERS=$ADD_USERS LAUNCH=$LAUNCH" >> "$DDEV_LOG" ; } ; INSTALL=yes ADD_USERS=yes SAMPLE_CONTENT=yes LAUNCH=no VERSION=2.6.22 WORDPRESS_VERSION=7.1.5 bbpress_build`, env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const written = fs.readFileSync(log, 'utf8');
  const lines = written.split('\n');
  const at = (re: RegExp) => lines.findIndex((l) => re.test(l));
  assert.match(written, /^wordpress_build VERSION=7\.1\.5 ADD_USERS=no LAUNCH=no$/m, 'the WordPress builder gets WordPress\'s version, and leaves the accounts and the browser to this builder');
  const claim = fs.readFileSync(path.join(p.dir, '.ddev', 'config.bbpress.yaml'), 'utf8');
  assert.match(claim, /^web_environment:\n  - WEBSHIP_WORKSPACE_PLATFORM=bbpress$/m, 'the claim of the plugin on the project');
  assert.ok(at(/wp rewrite structure \/%postname%\//) > at(/^wordpress_build/), 'pretty addresses after the site');
  assert.ok(at(/wp plugin install bbpress --version=2\.6\.22 --activate/) > at(/wp rewrite structure/), 'then the forums plugin');
  assert.ok(at(/wp eval-file \.webship-forum-site\.php settings/) > at(/wp plugin install bbpress/), 'then the forums\' settings');
  assert.ok(at(/wp user set-role participant subscriber/) > at(/wp eval-file \.webship-forum-site\.php settings/), 'then the accounts');
  assert.ok(at(/wp eval-file \.webship-forum-site\.php content/) > at(/wp user set-role blocked subscriber/), 'the content after the accounts, which write it');
  assert.ok(at(/wp rewrite flush/) > at(/wp eval-file \.webship-forum-site\.php content/), 'the rules written again at the end');
  assert.strictEqual((written.match(/^the script is there: 1$/gm) || []).length, 2, 'the script is in the project while it runs');
  assert.deepStrictEqual(fs.readdirSync(p.dir).filter((f) => f.startsWith('.webship-')), [], 'and gone from the project afterwards');
  assert.match(r.stdout, /forums\//, 'the address of the forums is printed');
});

test('without --install the forums plugin is put in the plugins, and the claim is written', () => {
  const p = project('none');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('trim_project_name() { :; } ; wordpress_build() { :; } ; INSTALL=no ADD_USERS=yes SAMPLE_CONTENT=yes LAUNCH=no VERSION=latest bbpress_build',
    { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  assert.match(fs.readFileSync(log, 'utf8'), /^ddev exec curl -fsSL https:\/\/downloads\.wordpress\.org\/plugin\/bbpress\.latest-stable\.zip /m);
  assert.doesNotMatch(fs.readFileSync(log, 'utf8'), /wp plugin install|wp eval-file/, 'nothing is installed on a site that is not there yet');
  assert.match(r.stdout, /--add-users needs --install/);
  assert.match(r.stdout, /--sample-content needs --install/);
  assert.ok(fs.existsSync(path.join(p.dir, '.ddev', 'config.bbpress.yaml')));
});

test('the builder says so, and stops, when the WordPress plugin is not here', () => {
  const p = project('none');
  const r = bash('trim_project_name() { :; } ; INSTALL=yes bbpress_build', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /builds on the WordPress plugin, which is not installed here/);
  assert.match(r.stdout, /plugins\.sh --install wordpress/);
});

test('the forums\' tool runs the first of its flags, and says what the forums hold without one', () => {
  const p = project();
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log };
  const run = (flags: string) => {
    fs.writeFileSync(log, '');
    const r = bash(`trim_project_name() { :; } ; ADD_USERS=no CANCEL_USERS=no SAMPLE_CONTENT=no TIDY=no ; ${flags} bbpress_forums_tool`, env);
    assert.strictEqual(r.status, 0, r.stderr + r.stdout);
    return fs.readFileSync(log, 'utf8');
  };
  assert.match(run(''), /^ddev wp eval-file \.webship-forum-site\.php status$/m);
  assert.match(run('SAMPLE_CONTENT=yes'), /^ddev wp eval-file \.webship-forum-site\.php content$/m);
  assert.match(run('TIDY=yes'), /^ddev wp eval-file \.webship-forum-site\.php reset$/m);
  assert.match(run('ADD_USERS=yes'), /^ddev wp user set-role moderator subscriber$/m);
  assert.match(run('CANCEL_USERS=yes'), /^ddev wp user delete moderator --yes$/m);
  assert.doesNotMatch(run('ADD_USERS=yes SAMPLE_CONTENT=yes'), /eval-file/, 'one thing at a time: the first flag');
});

test('the testing hook runs the WordPress plugin\'s part first, then adds the forums\' pack and handles to its registry, once', () => {
  const p = project();
  const log = path.join(p.root, 'ddev.log');
  const run = () => bash(`${WORDPRESS_PART}\ncd ${p.dir} && testing_configure_bbpress ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  assert.match(fs.readFileSync(log, 'utf8'), /^wordpress hook$/m, 'the WordPress plugin\'s hook ran');
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/bbpress-steps'], '^2.0.0');
  assert.strictEqual(pkg.devDependencies['@webship-js/wordpress-steps'], '^2.2.0', 'the base pack stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const base = lines.findIndex((l) => l.includes('node_modules/@webship-js/wordpress-steps/tests/step-definitions'));
  assert.strictEqual(lines[base + 1], "      'node_modules/@webship-js/bbpress-steps/tests/step-definitions/**/*.js',", 'the forums\' pack right after the WordPress pack, in the same profile');
  assert.doesNotMatch(cucumber, /webship-workspace profile/, 'no profile of its own: the extension goes with its base');
  assert.match(cucumber, /moderator: \{ username: process\.env\.WP_MODERATOR_USER \|\| 'moderator', password: process\.env\.WP_MODERATOR_PASSWORD \|\| '[^']+', email: 'moderator@example\.com' \},/);
  assert.match(cucumber, /blocked: \{ username: process\.env\.WP_BLOCKED_USER \|\| 'blocked'/);
  assert.strictEqual((cucumber.match(/^\s*admin: \{/gm) || []).length, 1, 'the WordPress plugin\'s admin stays the only one');
  assert.match(cucumber, /^\s*admin: \{ username: process\.env\.WP_ADMIN_USER \|\| 'administrator', password: [^\n]*, email: 'administrator@example\.com' \},$/m, 'and gets the address the notification steps read');
  assert.match(cucumber, /mailUrl: process\.env\.MAIL_URL \|\|/);
  assert.match(cucumber, /tags: process\.env\.CUCUMBER_TAGS \|\| 'not @wip and not @must-fail',/);
  // Still a module node can load, with one registry where webship-js reads it.
  const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; console.log(JSON.stringify([c.require, Object.keys(c.worldParameters.users), c.tags, typeof c.worldParameters.mailUrl, c.worldParameters.users.admin.email]))`], { encoding: 'utf8', env: { ...process.env, LAUNCH_URL: 'https://site1.ddev.site' } });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, tags, mail, adminMail] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires.length, 4);
  assert.deepStrictEqual(handles.sort(), ['admin', 'blocked', 'editor', 'keymaster', 'moderator', 'participant', 'spectator']);
  assert.match(tags, /not @must-fail/);
  assert.strictEqual(mail, 'string');
  assert.strictEqual(adminMail, 'administrator@example.com');
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'forums.feature')));
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'forums.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'forums.feature'), 'utf8'), 'Feature: mine\n');
});

test('without the WordPress plugin\'s hook, the testing hook writes the whole registry itself', () => {
  const p = project('plugin');
  const r = bash(`cd ${p.dir} && testing_configure_bbpress ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/bbpress-steps/tests/step-definitions/**/*.js',", 'after webship-js: the pack loads the WordPress pack itself');
  const loaded = spawnSync(process.execPath, ['-e', `console.log(Object.keys(require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default.worldParameters.users).join(','))`], { encoding: 'utf8' });
  assert.strictEqual(loaded.stdout.trim(), 'admin,keymaster,moderator,participant,spectator,blocked');
});

test('the testing hook leaves a project without forums alone', () => {
  const p = project('none');
  const r = bash(`cd ${p.dir} && testing_configure_bbpress ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
});

test('the user tools refuse a project without forums', () => {
  const p = project('none');
  const r = bash('set_bbpress_users ; add_bbpress_users', { WORKSPACE_ROOT: p.root, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /is not a site with forums/);
});

test('the first feature names no platform in a step, and no password; it is not named after the site\'s first feature', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'forums.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 15);
  for (const s of steps) assert.doesNotMatch(s, /bbpress|wordpress|buddypress/i, s);
  assert.doesNotMatch(feature, /password "/);
  assert.doesNotMatch(feature, /user create|I register/i, 'a suite never creates an account');
  // The WordPress plugin's hook writes tests/features/site.feature: this one goes beside it.
  assert.match(fs.readFileSync(FUNCTIONS, 'utf8'), /tests\/features\/forums\.feature/);
  assert.doesNotMatch(fs.readFileSync(FUNCTIONS, 'utf8'), /tests\/features\/site\.feature/);
});

// ---- The runtimes: DDEV as before, and Docker Compose, Podman, Kubernetes, Lando and Docksal through the core's layer ----

const ADDRESSES: Record<string, string> = {
  docker: 'http://127.0.0.1:41234', podman: 'http://127.0.0.1:41234', lando: 'http://127.0.0.1:41234',
  kubernetes: 'http://172.18.0.2:30080', docksal: 'http://site1.docksal.site',
};

/**
 * The builder in a throwaway workspace, with `ddev` replaced by a recorder, the WordPress plugin's builder by a
 * stand-in that makes the folder (as `ddev config` does), and the core's layer by stand-ins: `layer` is the runtime
 * it answers with (runtime_of, rt_url, rt_claim), or '' for a core that has no layer yet.
 */
function build(layer: string, env: Record<string, string> = {}) {
  const p = project('none');
  fs.rmSync(p.dir, { recursive: true });
  const log = path.join(p.root, 'ddev.log');
  const address = ADDRESSES[layer] || '';
  const stand = [
    'trim_project_name() { :; }',
    `wordpress_build() { echo "wordpress_build RUNTIME=$RUNTIME" >> "$DDEV_LOG" ; mkdir -p "$WORKSPACE_ROOT/$doc_name/$PROJECT_NAME" ; [ "\${RUNTIME_ANSWER:-ddev}" == ddev ] && mkdir -p "$WORKSPACE_ROOT/$doc_name/$PROJECT_NAME/.ddev" && touch "$WORKSPACE_ROOT/$doc_name/$PROJECT_NAME/.ddev/config.yaml" ; return 0 ; }`,
    layer ? `runtime_of() { echo "\${RUNTIME_ANSWER}" ; } ; rt_url() { [ "\${RUNTIME_ANSWER}" == ddev ] && echo "https://\${PROJECT_NAME}.ddev.site" || echo "${address}" ; } ; rt_claim() { echo "rt_claim $* in $(basename "$PWD")" >> "$DDEV_LOG" ; }` : '',
    'bbpress_build',
  ].join('\n');
  const r = bash(stand, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log,
    account_name: 'webmaster', INSTALL: 'yes', ADD_USERS: 'no', SAMPLE_CONTENT: 'no', LAUNCH: 'no', VERSION: 'latest',
    RUNTIME: '_none_', RUNTIME_ANSWER: layer || 'ddev', ...env });
  const calls = fs.existsSync(log) ? fs.readFileSync(log, 'utf8').trim().split('\n').filter((c) => /^(ddev|rt_claim|wordpress_build) /.test(c)) : [];
  return { r, calls, dir: path.join(p.root, 'dev', 'site1') };
}

test('on DDEV the build is what it was: the same commands with the layer and without it, the claim in .ddev/', () => {
  const without = build('');
  const withLayer = build('ddev');
  for (const b of [without, withLayer]) {
    assert.strictEqual(b.r.status, 0, b.r.stderr + b.r.stdout);
    assert.match(b.r.stdout, /Go to https:\/\/site1\.ddev\.site\/forums\/, and https:\/\/site1\.ddev\.site\/wp-admin as webmaster/);
    assert.ok(fs.existsSync(path.join(b.dir, '.ddev', 'config.bbpress.yaml')), 'the claim of the plugin, in the container tool\'s folder');
    assert.ok(!b.calls.some((c) => c.startsWith('rt_claim ')), 'nothing is claimed through the layer on DDEV');
  }
  assert.deepStrictEqual(withLayer.calls, without.calls);
});

test('on Docker Compose, Podman, Kubernetes, Lando and Docksal the plugin claims the site through the layer and prints the runtime\'s address', () => {
  for (const runtime of Object.keys(ADDRESSES)) {
    const address = ADDRESSES[runtime];
    const b = build(runtime, { RUNTIME: runtime });
    assert.strictEqual(b.r.status, 0, runtime + ': ' + b.r.stderr + b.r.stdout);
    assert.strictEqual(b.calls[0], `wordpress_build RUNTIME=${runtime}`, `${runtime}: the WordPress builder builds on the runtime asked for`);
    assert.strictEqual(b.calls[1], 'rt_claim bbpress in site1', `${runtime}: the claim, right after the site`);
    assert.ok(!fs.existsSync(path.join(b.dir, '.ddev')), `${runtime}: nothing of DDEV's is written`);
    assert.match(b.r.stdout, new RegExp(`Go to ${address.replace(/[.]/g, '\\.')}/forums/, and ${address.replace(/[.]/g, '\\.')}/wp-admin as webmaster`), runtime);
    assert.doesNotMatch(b.r.stdout, /ddev\.site/, runtime);
  }
});

test('--runtime on a workspace without the runtime layer is refused, never built on DDEV in silence', () => {
  const b = build('', { RUNTIME: 'docker' });
  assert.strictEqual(b.r.status, 1);
  assert.match(b.r.stdout, /--runtime docker needs a Webship Workspace with the container runtimes \(webship\/workspace#694\)/);
  assert.deepStrictEqual(b.calls, [], 'nothing is built');
});

test('the builder takes --runtime, with the runtimes of the core\'s own builders', () => {
  const args = fs.readFileSync(path.join(PKG, 'scripts', 'args', 'arg-bbpress.sh'), 'utf8');
  assert.match(args, /parser\.add_argument\('--runtime',\s*dest='RUNTIME',\s*default="_none_",\s*choices=\['ddev', 'docker', 'podman', 'kubernetes', 'lando', 'docksal'\]/);
});

test('a site with forums is known on every runtime: the claim in the x-webship block, through the core\'s layer', () => {
  const p = project('none');
  fs.rmSync(path.join(p.dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(p.dir, 'compose.yaml'), 'x-webship:\n  runtime: docker\n  type: wordpress\n  platform: bbpress\n');
  const layer = 'rt_is_platform() { grep -qE "^  (type|platform): $2$" "$1/compose.yaml" 2>/dev/null ; } ; ';
  assert.strictEqual(bash(`${layer} bbpress_is_project ${p.dir}`).status, 0, 'claimed: a site with forums');
  fs.writeFileSync(path.join(p.dir, 'compose.yaml'), 'x-webship:\n  runtime: docker\n  type: wordpress\n');
  assert.strictEqual(bash(`${layer} bbpress_is_project ${p.dir}`).status, 1, 'a plain WordPress site is not one');
  assert.strictEqual(bash(`bbpress_is_project ${p.dir}`).status, 1, 'and without the layer, nothing claims it');
});

test('the feature of the runtimes drives a site the plugin claims, and names no platform in a step', () => {
  const feature = fs.readFileSync(path.join(PKG, 'features', 'bbpress-runtimes.feature'), 'utf8');
  const scenarios = feature.split(/\n(?=  @needs-runtime-)/).slice(1);
  assert.strictEqual(scenarios.length, 6);
  for (const s of scenarios) assert.match(s, /^  @needs-runtime-(docker|kubernetes) @needs-platform-bbpress\n  Scenario: /);
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  for (const s of steps) assert.doesNotMatch(s, /bbpress|wordpress/i, s);
  assert.doesNotMatch(feature, /ddev\.site|127\.0\.0\.1/);
  const manifest = JSON.parse(fs.readFileSync(path.join(PKG, 'package.json'), 'utf8')).workspacePlugin;
  assert.ok(manifest.features.includes('features/bbpress-runtimes.feature'));
  // The CI site has the sample content: the feature reads a forum of it.
  assert.match(manifest.featuresSite, /^cmd-bbpress-project\.sh ci-bbpress( [A-Za-z0-9._=-]+)* --sample-content --runtime docker$/);
});
