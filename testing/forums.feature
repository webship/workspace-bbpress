Feature: The forums answer, and each default account has its forum role
  As the keymaster of the forums
  I want the forum index, the profiles and the administration to work, each account in its forum role
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-add-users.sh <site> bbpress); a scenario logs in by a handle of
  # the users registry in cucumber.js, so no password is written here. It passes on a site built with --install
  # --add-users, with or without --sample-content: it reads only what the build and the accounts make.

  @critical
  Scenario: A visitor reaches the forum index
    Given I am an anonymous user
    And I am on the forum index
    Then the forum breadcrumbs should be "Home" and "Forums"

  Scenario Outline: The <account> account has the forum role <role>
    Given I am an anonymous user
    Then the forum role of "<account>" should be "<role>"

    Examples:
      | account     | role        |
      | admin       | Keymaster   |
      | keymaster   | Keymaster   |
      | moderator   | Moderator   |
      | participant | Participant |
      | spectator   | Spectator   |
      | blocked     | Blocked     |

  Scenario: An account reads its own forum profile
    Given I am a logged in user with the "participant" user
    When I open my forum profile
    Then the forum profile should show "Forum Role: Participant"
    And the forum profile should offer the page "Subscriptions"
    And the forum profile should offer the page "Edit"

  Scenario: The keymaster runs the forums in the administration
    Given I am a logged in user with the "keymaster" user
    When I go to the "Forums" admin screen
    Then I should be on the "Forums" admin screen
    And the admin menu should list "Topics"
    And the admin menu should list "Replies"
    When I go to the "Forums settings" admin screen
    Then the forum feature "Subscriptions" should be on
    And the forum feature "Favorites" should be on

  Scenario: A moderator gets the topics and the replies of the administration, not the forums
    Given I am a logged in user with the "moderator" user
    When I go to the "Topics" admin screen
    Then I should be on the "Topics" admin screen
    And the admin menu should list "Replies"
    But the admin menu should not list "Forums"

  @js-off
  Scenario: A participant has no administration of the forums, a blocked account no forum at all
    Given I am a logged in user with the "participant" user
    Then I should not be allowed to open "/wp-admin/edit.php?post_type=topic"
    Given I am a logged in user with the "blocked" user
    Then I should not be allowed to open "/forums/"
    And I should be logged in
