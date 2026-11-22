# @webship.co/workspace-bbpress

bbPress for the [Webship Workspace](https://github.com/webship/workspace) dashboard, on top of its
WordPress plugin ([`@webship.co/workspace-wordpress`](https://github.com/webship/workspace-wordpress)):
a builder that makes a real site with forums in a container — WordPress with the free bbPress plugin,
its forums set up for testing — the default accounts (one per forum role), the sample forums and
topics, the forums' own tool, the [bbPress step pack](https://github.com/webship/bbpress-steps) wired
into the workspace's testing setup next to the WordPress one it extends, and its AI items — two
agents, a skill, a command and two prompts — each listed in the workspace folder of its kind.

The workspace is container-based (DDEV by default): a site with forums is a WordPress project like
any other, so the row menus the core draws (start, stop, launch, backup, clone, remove, tests) work
on it unchanged. The plugin claims its sites with a file of its own (`.ddev/config.bbpress.yaml`), so
the Tests menu of the row offers the forums' test users (Workspace core 1.0.27 and later).

It is made from the reference platform plugin, `@webship.co/workspace-wordpress`, and builds on it:
the site is made by that plugin's builder, and WP-CLI is that plugin's tool
(`cmd-tools-wordpress-cli.sh`).

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require @webship.co/workspace-bbpress --with-needs   # npm install into the dashboard, with the WordPress plugin
bash core/scripts/plugins.sh --activate bbpress --with-needs                         # plugins.bbpress in settings.yml, and what it needs
bash core/scripts/plugins.sh --install bbpress                                       # the builder, the tool, functions, args, AI items
bash core/scripts/plugins.sh --configure bbpress                                     # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is
idempotent. `--uninstall` removes what it placed; an AI item you edited stays. The WordPress plugin
cannot be deactivated or uninstalled while this one is in use: take this one off first.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active
workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-bbpress-project.sh`, `cmd-tools-bbpress-forums.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The forums' first feature, and the script that writes the forums' settings, roles and sample content | `core/scripts/plugins/bbpress/`, beside its functions |
| The agents `bbpress-site-builder`, `bbpress-tester` | `ai-agents/` |
| The skill `bbpress-scenarios` | `ai-skills/` |
| The command `/bbpress-test` | `ai-commands/` |
| The prompts `bbpress-build-and-test`, `bbpress-moderation-round` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `wordpress`, the WordPress plugin: the site is made by its builder (`wordpress_build`), its testing hook runs first on a site with forums (the WordPress step pack, its users registry), and WP-CLI goes through its tool. `--with-needs` requires it from npm (`@webship.co/workspace-wordpress`), or from the folder beside this package when it was required from a path.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate bbpress --with-needs   # dev, wordpress and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install bbpress
```

Everything the builder runs for a site runs in the site's own container, through the container tool the workspace already needs: WP-CLI is in the web container. The plugin asks for no command of its own on the machine.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-bbpress-project.sh` | The builder, in the Build list as **bbPress (forums on WordPress)**, installed into every sites folder |
| `commands/cmd-tools-bbpress-forums.sh` | The forums' tool: what the forums hold, the default accounts, the sample content, a tidy-up |
| `scripts/functions/fun-bbpress.sh` | The bash functions behind them, sourced by bootstrap once installed; the names the core's tools look for (`set_bbpress_users`, `add_bbpress_users`, `cancel_bbpress_users`, `testing_configure_bbpress`) |
| `scripts/args/arg-bbpress.sh`, `arg-bbpress-forums.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `scripts/forum-site.php` | The script the functions run in the site with WP-CLI: the forums' settings, the forum roles, the sample content, a tidy-up and a status, each through the forums' own functions |
| `testing/forums.feature` | The first feature a site with forums gets when testing is set up |
| `ai/agents/bbpress-site-builder.md` | The agent that builds and maintains sites with forums with these commands |
| `ai/agents/bbpress-tester.md` | The agent that writes and runs scenarios with the forums' step pack |
| `ai/skills/bbpress-scenarios/` | The skill: the step pack's phrases by area, the traps found on real forums, three example features |
| `ai/commands/bbpress-test.md` | The slash command `/bbpress-test <site>`: set up, match every step, run, report |
| `ai/prompts/bbpress-build-and-test.md`, `bbpress-moderation-round.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about bbPress here |
| `features/bbpress.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## The builder

Run it from a sites folder. `--help` is safe.

```bash
cd ~/workspace/dev
bash cmd-bbpress-project.sh myforums --install --add-users --sample-content
```

| Flag | What it does |
| --- | --- |
| `--install` | Install WordPress with the workspace account as the administrator, then add bbPress from the plugin directory and set the forums up for testing: pretty addresses (the forums live at `/forums/`), no wait between two posts of an account (the flood protection), no time limit on an account editing its posts. Every other setting stays as the plugin sets it. Without it, WordPress is downloaded and bbPress put in its plugins, to activate once the site is installed |
| `--add-users` | With `--install`: add the default accounts, one per forum role, each with its role on the site and its forum role |
| `--sample-content` | With `--install`: add the forums and topics the step pack's features name: a category with two forums, a forum of sixteen topics, a closed, a private and a hidden forum, sticky and closed topics, a topic of two pages, topic tags. With `--add-users` each topic is written by the account of its forum role; without, by the administrator of the site |
| `--version <x>` | The bbPress release (`latest` by default) |
| `--wordpress-version <x>` | The WordPress release (`latest` by default) |
| `--locale <x>` | The language WordPress is downloaded in |
| `--php-version <x>` | The PHP of the project container |
| `--launch` | Open the forums when they are ready |

The forums answer at `https://myforums.ddev.site/forums/`, the administration at `/wp-admin`, the mail
catcher at `https://myforums.ddev.site:8026`. The WordPress plugin's builder makes the project (of the
type `wordpress`, with the Node.js of the workspace, 24) and installs the site; the container tool
writes the database settings, the builder writes none. A project of the same name is deleted first.

Nothing paid and no account anywhere: the free plugin from the plugin directory, the theme WordPress
installs with, and content written by the forums' own functions.

### The plugin's claim on the project

A site with forums is a project of the type `wordpress`, which is the WordPress plugin's. The builder
leaves `.ddev/config.bbpress.yaml` in the project: a config overlay of the container tool with one key
(`web_environment: WEBSHIP_WORKSPACE_PLATFORM=bbpress`, in the web container's environment from its
next start; nothing of the site reads it). The file's name is what the workspace reads: a project that
carries `config.<plugin>.yaml` takes the test users of that plugin, so the row's Tests menu offers the
forums' list (`bbpress`) instead of the WordPress one. A WordPress project that got the forums plugin
another way has no claim: the plugin's tools still know it by the plugin's folder in its plugins.

### The forums' tool

The forums have no command line of their own. The tool runs the plugin's `forum-site.php` with WP-CLI
in the site's container, which reads and writes with the forums' own functions, so the counters of
every forum and topic are the ones the forums keep.

```bash
bash cmd-tools-bbpress-forums.sh myforums                    # the forums, their topics and replies, the forum role of each account
bash cmd-tools-bbpress-forums.sh myforums --add-users        # the default accounts, each with its forum role
bash cmd-tools-bbpress-forums.sh myforums --cancel-users     # delete them, and the topics and replies they wrote
bash cmd-tools-bbpress-forums.sh myforums --sample-content   # the sample forums and topics; what is there is kept
bash cmd-tools-bbpress-forums.sh myforums --tidy             # take away what a stopped test run left
```

WP-CLI itself is the WordPress plugin's tool:

```bash
bash cmd-tools-wordpress-cli.sh myforums                                             # WordPress, plugins, themes, accounts
bash cmd-tools-wordpress-cli.sh myforums --run "plugin get bbpress --field=version"
bash cmd-tools-wordpress-cli.sh myforums --update                                    # WordPress, its plugins (the forums' too), themes
```

### The default accounts

| Account | Address | Role on the site | Forum role | Handle in the tests |
| --- | --- | --- | --- | --- |
| `administrator` | `administrator@example.com` | administrator | Keymaster | `admin` |
| `keymaster` | `keymaster@example.com` | subscriber | Keymaster: everything in the forums, their settings and tools | `keymaster` |
| `moderator` | `moderator@example.com` | subscriber | Moderator: every topic and reply, the hidden forums | `moderator` |
| `participant` | `participant@example.com` | subscriber | Participant: topics and replies, the private forums | `participant` |
| `spectator` | `spectator@example.com` | subscriber | Spectator: reads the public forums | `spectator` |
| `blocked` | `blocked@example.com` | subscriber | Blocked: no forum at all | `blocked` |

One account per forum role, each named after it, with the password of the workspace's other default
lists. The forum role is apart from the role on the site: the accounts are made with WP-CLI, and each
gets its forum role through the forums' own function. They are for local sites and for tests; the
site's first account is the workspace account and is never written into a test.

The row's Tests menu offers **Add the test users** and **Cancel the test users** for a site this
plugin claims (Workspace core 1.0.27 and later): they run the same list as

```bash
bash cmd-tools-add-users.sh myforums bbpress       # the core's tool, with the plugin's list
bash cmd-tools-cancel-users.sh myforums bbpress
```

Adding them again gives each its roles back. Cancelling deletes them with the topics and replies they
wrote: add the sample content again afterwards (`cmd-tools-bbpress-forums.sh myforums --sample-content`).

### Test a site with forums

```bash
bash cmd-tools-testing.sh myforums                 # webship-js, both step packs, the users registry, the first features
bash cmd-tools-testing.sh myforums --run           # run the suite in the container
bash cmd-tools-testing.sh myforums --run --path tests/features/forums.feature
bash cmd-tools-testing.sh myforums --list-steps    # the step packs the project has, in one profile
```

`cmd-tools-testing.sh` is the workspace's own. For a site with forums, this plugin's hook first runs
the WordPress plugin's (the WordPress step pack, its users registry and `tests/features/site.feature`),
whichever order the core calls the hooks in, then adds `@webship-js/bbpress-steps` to `package.json`,
lists its step definitions in `cucumber.js` right after the WordPress pack's, in the same profile (the
forums' pack is an extension of the WordPress one and loads it itself), adds the tags that keep the
pack's assertions that must fail out of a normal run, the mail catcher of the project (`mailUrl`), the
handles of the forum roles (with the addresses the notification steps read; overridable with
`WP_<HANDLE>_USER` and `WP_<HANDLE>_PASSWORD`) in the users registry, places
`tests/features/forums.feature` when the project has none, and makes sure the default accounts are on
the site. Run it again and it adds what is missing and keeps what you changed.

`forums.feature` passes on a site built with `--install --add-users`, with or without
`--sample-content`: it reads only what the build and the accounts make. The features of the step pack
name the sample forums and topics, so they need `--sample-content`.

## The AI items

`ai/` in the package holds one folder per kind, the manifest's `ai` block names each item, and
`--install` places it in the workspace folder of that kind.

| Kind | Item | Use it to |
| --- | --- | --- |
| Agent | `bbpress-site-builder` | Build, update, maintain or remove a site with forums with the builder, the forums' tool and the WP-CLI tool, in containers only, with nothing paid and no account anywhere |
| Agent | `bbpress-tester` | Set the testing stack up, look at the forums in the Playwright MCP browser first, write scenarios from the packs' steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |
| Skill | `bbpress-scenarios` | Write a scenario from phrases that exist: the packs' steps by area, the handles of the users registry, the traps found on real forums, and three features that pass on a fresh site with the sample content |
| Command | `/bbpress-test <site> [feature or @tag]` | Run the suite of a site from inside a session: set up when missing, match every step, run, report what failed and why |
| Prompt | `bbpress-build-and-test` | Start a session that builds a site with forums, says what it holds, sets the testing stack up and runs the first feature |
| Prompt | `bbpress-moderation-round` | Start a session that writes and runs the scenario of a round of moderation |

After `--install` each is in its folder on the dashboard. **Install** there puts an agent, a skill
or a command into Claude Code (`~/.claude/agents`, `~/.claude/skills`, `~/.claude/commands`), or
from the command line:

```bash
cd ~/workspace/ai-agents   && bash cmd-tools-ai-items.sh bbpress-tester --install
cd ~/workspace/ai-skills   && bash cmd-tools-ai-items.sh bbpress-scenarios --install
cd ~/workspace/ai-commands && bash cmd-tools-ai-items.sh bbpress-test --install
```

A prompt is not installed: it is the whole `claude …` launch command of a new session, and the
dashboard's **New screen** form lists it as a template. By hand, fill the placeholders in and run
the command of the file from the folder it names.

The items are written for any AI CLI, with Claude Code as the default shape: the frontmatter and
the file layout are Claude Code's, the body of each item is plain Markdown that names no tool or
feature of one CLI, a command says in words what its arguments are, and the text between the
triple quotes of a prompt can be given to another AI CLI as it is.

Every step phrase the items show is checked against the definitions of the forums' step pack, of the
WordPress pack it brings and of webship-js (`tests/fixtures/step-definitions.txt`), and every command
and flag against the plugin's own, the WordPress plugin's and the workspace's.

## What is tied to the container tool

The builder and the tools call the container tool with plain verbs only (`ddev wp …`, `ddev exec`,
`ddev start`, `ddev launch`): no container is reached by its name, and the tool's own project file is
not read. Two things are DDEV's by name: the claim file lives in the tool's folder
(`.ddev/config.bbpress.yaml`, the place the workspace looks for it), and the addresses the builder
prints (`https://<name>.ddev.site`, the mail catcher at port 8026) are the ones DDEV's router gives a
project.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the builder, the AI items, the functions against a scaffolded project
```

CI runs the same on Node.js 20 and 24, parses every shell script, and runs the plugin's
`features/bbpress.feature` against a dashboard with this plugin (and the WordPress plugin it needs)
installed (`webship/workspace/.github/workflows/plugin-browser-suite.yml`).

When the step pack's release line changes, refresh the fixture from a project whose testing stack is
set up: `node <this plugin>/tests/fixtures/refresh-step-definitions.js > <this plugin>/tests/fixtures/step-definitions.txt`.
