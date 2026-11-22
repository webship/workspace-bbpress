Feature: The forum roles and the notification of a reply
  What each forum role reaches, and the mail a subscriber gets. It passes on a fresh site with the sample
  content; the mail is read in the mail catcher of the project.

  Scenario: A participant reads the private forum, a moderator the hidden one
    Given I am a logged in user with the "participant" user
    And I am on the forum index
    Then the forum index should list the forum "Members lounge"
    But the forum index should not list the forum "Staff room"
    Given I am a logged in user with the "moderator" user
    And I am on the forum index
    Then the forum index should list the forum "Staff room"
    And the forum "Staff room" should be hidden in the list

  @js-off
  Scenario: A spectator writes nothing, a blocked account reads nothing
    Given I am a logged in user with the "spectator" user
    When I open the topic "Welcome to the forums" in "General discussion"
    Then I should not be able to reply
    And the forums should say "You cannot reply to this topic."
    Given I am a logged in user with the "blocked" user
    Then I should not be allowed to open "/forums/"

  Scenario: A subscriber of a topic gets the mail of a reply
    Given there is a topic "Webship test topic" in "General discussion" by "participant"
    And I am a logged in user with the "participant" user
    And I have no subscriptions
    When I open the topic "Webship test topic"
    And I subscribe to the topic
    Then the topic should be subscribed to
    Given "moderator" replied to the topic "Webship test topic" with "Webship test reply of the moderator."
    Then a forum notification with the subject "Webship test topic" should be sent to "participant"
    And the forum notification with the subject "Webship test topic" to "participant" should contain "moderator wrote:"
    But no forum notification should be sent to "moderator"
    And there is no topic "Webship test topic"
