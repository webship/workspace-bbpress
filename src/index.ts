/**
 * bbPress for Webship Workspace: a platform plugin, on top of the WordPress plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the forums' tool in the
 * sites folders, their functions and argparse under core/scripts/plugins/bbpress/, the forums' first feature and
 * the script that writes the forums' settings, roles and sample content beside them, and its AI items (ai/ in
 * this package) in the folder of their kind: the agents in AI Agents, the skill in AI Skills, the command in AI
 * Commands, the prompts in AI Prompts. The plugin needs the WordPress plugin (the manifest's `needs`): its builder
 * starts from that plugin's, and the site's WP-CLI is that plugin's tool. The dashboard needs nothing drawn for
 * it: the builder is in the Build list because it is a cmd-*-project.sh, the row menus are the core's, the AI
 * items are listed like any other. What register() adds is what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the
 * dashboard's own files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/**
 * The plugin's name: the folder of its scripts and the name its functions carry. A site with forums is a
 * WordPress project of the container tool: the plugin claims it with .ddev/config.bbpress.yaml, and the core's
 * tools call its functions under bbpress.
 */
export const PLATFORM = 'bbpress';

/** The plugin it builds on (a need of the manifest): its builder makes the site, its CLI tool runs WP-CLI. */
export const BASE = 'wordpress';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-bbpress-project.sh', 'cmd-tools-bbpress-forums.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['bbpress-site-builder', 'bbpress-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['bbpress-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['bbpress-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['bbpress-build-and-test', 'bbpress-moderation-round'];

/** What the assistant is told about bbPress in this workspace. */
export function assistantContext(): string {
  return [
    'bbPress (a plugin, @webship.co/workspace-bbpress, on top of the WordPress plugin): a site with forums is built with',
    '`bash cmd-bbpress-project.sh <name> --install --add-users --sample-content` from a sites folder (dev, test, sandboxes, demos):',
    'the WordPress plugin\'s builder makes the site, then the free bbPress plugin is added from the plugin directory and the forums are set up for testing',
    '(pretty addresses, no wait between two posts, no time limit on editing a post),',
    'in a container like every other project, at https://<name>.ddev.site/forums/; `--sample-content` adds the forums and topics the step pack\'s features name,',
    '`--add-users` the default accounts, one per forum role (administrator, keymaster, moderator, participant, spectator, blocked).',
    '`bash cmd-tools-bbpress-forums.sh <name>` says what the forums hold; with `--add-users`, `--cancel-users`, `--sample-content` or `--tidy` it changes them.',
    'WP-CLI is the WordPress plugin\'s tool: `bash cmd-tools-wordpress-cli.sh <name> --run "plugin list"`.',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the bbPress step pack and the WordPress pack it extends; `--run` runs the suite.',
    `For bbPress work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <site>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run php, wp or composer on the host for a project; never install a paid add-on or connect the site to an account anywhere.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
