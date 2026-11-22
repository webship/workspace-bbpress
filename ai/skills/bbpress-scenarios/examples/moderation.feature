Feature: A round of moderation
  A moderator closes a topic, hides a reply, splits the topic and merges it again. Every topic the scenario
  makes is removed at its end. It passes on a fresh site with the sample content.

  Scenario: A moderator closes a topic and opens it again
    Given there is a topic "Webship test topic" in "General discussion" by "moderator"
    And I am a logged in user with the "moderator" user
    When I open the topic "Webship test topic"
    Then I should see the moderator tools
    When I close the topic
    Then the topic should be closed
    Given I am a logged in user with the "participant" user
    When I open the topic "Webship test topic" in "General discussion"
    Then I should not be able to reply
    And I should not see the moderator tools
    Given I am a logged in user with the "moderator" user
    When I open the topic "Webship test topic" in "General discussion"
    And I open the topic
    Then the topic should be open
    And there is no topic "Webship test topic"

  Scenario: A moderator hides a reply, splits the topic and merges it again
    Given there is no topic "Webship test split"
    And there is a topic "Webship test topic" in "General discussion" by "participant"
    And "participant" replied to the topic "Webship test topic" with "Webship test: a first reply."
    And "moderator" replied to the topic "Webship test topic" with "Webship test: a second reply."
    And I am a logged in user with the "moderator" user
    When I open the topic "Webship test topic"
    And I spam the last post
    Then the last post should be spam
    When I unspam the last post
    Then the last post should be published
    When I split the topic from post 3 into "Webship test split"
    Then I should be reading the topic "Webship test split"
    And the topic should have 1 post
    When I merge the topic into "Webship test topic"
    Then I should be reading the topic "Webship test topic"
    And the topic should have 3 posts
    And there is no topic "Webship test topic"
    And there is no topic "Webship test split"
