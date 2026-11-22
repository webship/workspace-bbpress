---
name: bbpress-scenarios
description: Write and run webship-js scenarios for a site with bbPress forums of the Webship Workspace with the bbPress step pack (`@webship-js/bbpress-steps`, which brings the WordPress step pack along) — the phrases of the packs by area (the forum index and a forum, a topic and its posts, the topic and reply forms, subscriptions and favorites, the forum profile, the search and the topic tags, moderation, the forums in the administration, the notification mail), the handles of the users registry, and the workspace command that runs them in the site's container. Use when asked to "write a scenario for these forums", "test the moderation", "which step is there for a sticky topic", "add a feature for the subscriptions", or when a `.feature` file of a site with forums is being written or fixed.
argument-hint: '<site> [what to cover]'
---

# bbpress-scenarios

Scenarios for a site with bbPress forums of a Webship Workspace (`~/workspace`, container-based, DDEV by
default), written from the steps of [`@webship-js/bbpress-steps`](https://github.com/webship/bbpress-steps),
of the WordPress step pack it brings along and of [webship-js](https://github.com/webship/webship-js)
itself, and run in the site's container by the workspace's own command. It comes with the bbPress
plugin (`@webship.co/workspace-bbpress`), like the builder (`cmd-bbpress-project.sh`), the forums' tool
(`cmd-tools-bbpress-forums.sh`) and the agents `bbpress-site-builder` and `bbpress-tester`.

## Where everything is

| What | Where |
| --- | --- |
| The site | `~/workspace/<folder>/<site>`, its forums at `https://<site>.ddev.site/forums/` (`<folder>` is a sites folder: `dev`, `test`, `sandboxes`, `demos`) |
| Its mail | the mail catcher of the project, `https://<site>.ddev.site:8026` |
| The suite's configuration | `<site>/cucumber.js`: the step definitions it loads, the users registry (`worldParameters.users`), the mail catcher (`mailUrl`) |
| The features | `<site>/tests/features/*.feature` (`forums.feature` and `site.feature` are the first ones the setup wrote) |
| The forums' steps | `<site>/node_modules/@webship-js/bbpress-steps/tests/step-definitions/*.steps.js` |
| The site's steps (login, administration) | `<site>/node_modules/@webship-js/wordpress-steps/tests/step-definitions/*.steps.js` |
| webship-js's steps | `<site>/node_modules/webship-js/tests/step-definitions/*.js` |
| The reports | `<site>/tests/reports/` |

## The order of work

1. **Make sure the testing stack is there.** From the sites folder:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <site>
   ```
   It adds webship-js, both step packs (in one profile: the forums' pack extends the WordPress one),
   the users registry with the handles of the forum roles, the mail catcher,
   `tests/features/site.feature` and `tests/features/forums.feature`, and makes sure the default
   accounts are on the site, each with its forum role. It is safe to run again: it adds what is
   missing and keeps what was changed.
2. **Read the installed steps before writing a phrase.** They are the source of truth: the packs
   move, and a phrase from memory is a guess.
   ```bash
   cd ~/workspace/<folder>/<site>
   grep -hE "^(Given|When|Then)\(" node_modules/@webship-js/bbpress-steps/tests/step-definitions/*.steps.js
   ```
   Every step carries a comment block with five examples above it; open the file when a phrase
   is not obvious.
3. **Look at the page first** (the Playwright MCP browser, a tab of your own) when the scenario
   is about a page you have not seen.
4. **Write the feature** in `<site>/tests/features/`, from phrases that exist (the lists below).
5. **Match every step without a browser**, then run the feature, then the suite:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <site> --dry-run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <site> --run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <site> --run --tags "@critical"
   bash cmd-tools-testing.sh <site> --run
   ```
   A dry run says `Undefined` for a phrase no definition matches: fix the phrase, do not write a
   step for it.

## Accounts: a handle, never a password

```gherkin
Feature: Accounts
  Scenario: The moderator logs in
    Given I am a logged in user with the "moderator" user
    Then I should be logged in as the "moderator" user
    And the forum role of "moderator" should be "Moderator"
```

The handles of the default accounts: `admin` (the site's `administrator`, a keymaster of the forums),
`keymaster`, `moderator`, `participant`, `spectator` and `blocked`. A visitor is `Given I am an
anonymous user`. Never create an account in a scenario, and never log in as the workspace account.

## The phrases, by area

The forum index, a forum and a topic:

```gherkin
Feature: Reading the forums
  Scenario: The index, a forum, its pages, a topic
    Given I am an anonymous user
    And I am on the forum index
    Then the forum index should list the forum "General discussion" in the category "Community"
    And the forum "Archive" should be closed in the list
    And the forum breadcrumbs should be "Home" and "Forums"
    When I open the forum "Showcase"
    Then the forum should have 17 topics
    And the first topic of the forum should be "Forum rules"
    When I go to page 2
    Then I should be on page 2
    And the forum should list the topic "Showcase entry 01"
    When I open the topic "Welcome to the forums" in "General discussion"
    Then I should be reading the topic "Welcome to the forums"
    And the topic should have 3 posts
    And post 2 should be by "participant"
    And the last post should read "Welcome aboard."
    And the topic should be open
    And the forums should say "You must be logged in to reply to this topic."
```

A topic of one's own, its form and its edit:

```gherkin
Feature: Writing in the forums
  Scenario: A topic, a reply, an edit
    Given there is no topic "Webship test topic"
    And I am a logged in user with the "participant" user
    When I start a new topic in "General discussion"
    And I try to submit the post
    Then the editor should show the error "Your topic needs a title."
    When I write the topic title "Webship test topic"
    And I write "Webship test: the first post of the topic." in the editor
    And I add "a quoted line" to the editor with the "b-quote" button
    And I tag the topic with "webship"
    And I submit the post
    Then post 1 should show "a quoted line" as a quote
    When I reply to the topic with "Webship test reply."
    Then the topic should have 2 posts
    When I edit the last post
    Then the editor should contain "Webship test reply."
    When I add " Webship test: one more line." to the editor
    And I give the edit reason "Typo"
    And I submit the post
    Then the edit log of the last post should show "Reason: Typo"
    And there is no topic "Webship test topic"
```

Subscriptions, favorites and the profile:

```gherkin
Feature: What an account keeps
  Scenario: A favorite, a subscription, the profile
    Given I am a logged in user with the "participant" user
    And I have no favorites
    And I have no subscriptions
    When I open the topic "Forum rules" in "General discussion"
    And I favorite the topic
    And I subscribe to the topic
    Then the topic should be a favorite
    And my favorites should list "Forum rules"
    And my subscribed topics should list "Forum rules"
    When I remove "Forum rules" from my favorites
    And I remove "Forum rules" from my subscribed topics
    Then my favorites should not list "Forum rules"
    When I open my forum profile
    Then the forum profile should show "Forum Role: Participant"
    And the forum profile should offer the page "Subscriptions"
```

The search, the tags and the administration:

```gherkin
Feature: Finding and running the forums
  Scenario: The search, a tag, the lists and the settings of the administration
    Given I am an anonymous user
    When I search the forums for "marigolds"
    Then the search should find 2 matches
    And the search result "A community garden in spring" should be a topic in "General discussion"
    When I open the topic tag "spring"
    Then the forum should have 2 topics
    Given I am a logged in user with the "keymaster" user
    Then the topics list should include "Welcome to the forums"
    And the topic "The spring meetup is over" should be closed in the topics list
    When I go to the "Forums settings" admin screen
    Then the forum feature "Favorites" should be on
    And the "Forum Root" setting should be "forums"
```

Moderation, the forum roles and the notification mail: see the three example features below, which
pass on a fresh site with the sample content (`--install --add-users --sample-content`):

| Example | What it shows |
| --- | --- |
| `examples/forums-and-topics.feature` | The forum index, a forum's list, a topic's posts, and a topic a participant starts, formats, tags and edits with a reason |
| `examples/moderation.feature` | A moderator closing and opening a topic, hiding a reply, splitting a topic and merging it again |
| `examples/roles-and-notifications.feature` | What a participant, a moderator, a spectator and a blocked account reach, and the mail a subscriber gets of a reply |

Copy one into `<site>/tests/features/` and run it as it is before you change it.

## Traps found on real forums

- **A topic's own post is post 1.** Posts are counted on the page that is open, the topic's own
  first; a topic shows 15 posts a page, and `the last post` is the last of the page.
- **"Posts" counts the topic too.** A forum's row counts topics and replies together under "Posts", a
  topic's row its own post and its replies: `the topic "…" should have 2 replies in the list` reads
  the replies.
- **A super sticky topic is in every forum.** It heads each forum's list and counts in each list's
  total: a forum of sixteen topics lists seventeen.
- **A moderator does not see what is hidden either.** A pending, spammed or trashed reply or topic is
  left out of the page until the moderator follows "(+1 hidden)": `When I show the hidden posts`,
  `When I show the hidden topics`. Right after a moderation link the page shows them already.
- **The author of a closed topic still gets the reply form**, though the forums refuse what it sends
  ("Topic is closed."): check a closed topic as an account that did not start it.
- **An edit is logged when the text changes.** Changing only the type, the status or the forum of a
  topic writes no line in its edit log.
- **A reply without the "Notify me" box ends the subscription** the account had to the topic: check
  the box (`When I check "Notify me of follow-up replies via email"`) or subscribe after replying.
- **The notification goes to a no-reply address**, the subscribers in Bcc; the author of a post is
  never notified of it. The steps read Bcc: name the account, `a forum notification with the subject
  "…" should be sent to "participant"`.
- **A private or hidden forum is "not found"**, not "forbidden", for an account that may not read
  it, and so is every page of the forums for a blocked account: tag such a scenario `@js-off`, the
  browser logs the failed page.
- **What a scenario makes, it removes**: `Given there is a topic "…" in "…" by "…"` at its start (it
  removes a topic an earlier run left under that title), `Given there is no topic "…"` at its end,
  for a split and a moved reply too.

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For bbPress.** Start with `ch06-form-testing-recipes.md` (the topic and reply forms and their
  errors), `ch09-table-list-testing.md` (the lists of forums, topics and posts),
  `ch10-authentication-authorization.md` (the forum roles and what each may open) and
  `ch21-when-tests-go-bad.md` (flaky, brittle and slow scenarios).
