Write and run the webship-js scenario of a round of moderation on a site with bbPress forums.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Write the scenario of a round of moderation on the forums of this site, and run it
# ~/workspace/<folder>/<site> · https://<site>.ddev.site/forums/ · container-based (DDEV by default)
# the phrases are in the bbpress-scenarios skill; the bbpress-tester agent is the one to hand this work over to
# look at the forums first: in the Playwright MCP browser, in a tab of your own, do the round by hand once before writing its scenario
# a feature to write or a run to read: the book Automated Functional Testing Recipes first (its README.md, then the matching chapter), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

The round: a participant starts a topic in <a forum of the site>, another account replies, and the moderator <closes|sticks|unapproves|spams|trashes|splits|merges|moves> it.
Then <a visitor|the participant> sees what the forums show of it afterwards, and the moderator puts it back.

Read the installed steps first:
grep -hE '^(Given|When|Then)\(' node_modules/@webship-js/bbpress-steps/tests/step-definitions/*.steps.js

Write one feature in tests/features/<name>.feature, from phrases that exist.
Log in by the handle of the users registry (admin, keymaster, moderator, participant, spectator, blocked):
no password in the feature, no account created by a scenario, no platform name in a step phrase.
What the scenario makes, it removes in the same scenario: it starts from a topic of its own (Given there is a topic ...) and ends with Given there is no topic ... for each title it made.

Then, from the sites folder (cd ..):
bash cmd-tools-testing.sh <site> --dry-run --path tests/features/<name>.feature
bash cmd-tools-testing.sh <site> --run --path tests/features/<name>.feature

A failing scenario is a result: tell me what the forums did, do not loosen the scenario.
When you are done: the scenario, the result of the run, and any step you could not find in the packs
"""
```
