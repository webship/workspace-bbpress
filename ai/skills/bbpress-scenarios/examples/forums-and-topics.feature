Feature: The forums and a topic of a participant
  The forum index, a forum and its list, a topic with its posts, and a topic a participant starts, tags,
  edits and removes again. It passes on a fresh site with the sample content.

  Scenario: A visitor finds a topic through the forums
    Given I am an anonymous user
    And I am on the forum index
    Then the forum index should list the forum "General discussion" in the category "Community"
    And the forum "Showcase" should have 16 topics in the list
    When I open the forum "General discussion"
    Then the first topic of the forum should be "Forum rules"
    And the topic "Welcome to the forums" should be sticky in the list
    And the topic "The spring meetup is over" should be closed in the list
    When I open the topic "Welcome to the forums" in "General discussion"
    Then the topic should have 3 posts
    And post 1 should be by "keymaster"
    And the author of the last post should be a "Moderator"
    And the topic should be tagged "welcome"
    And I should not be able to reply

  Scenario: A participant starts a topic, edits it with a reason, and it is removed again
    Given there is no topic "Webship test topic"
    And there is no topic "Webship test topic, renamed"
    And I am a logged in user with the "participant" user
    When I start a new topic in "General discussion"
    And I write the topic title "Webship test topic"
    And I write "Webship test: the first post of the topic." in the editor
    And I add "bold words" to the editor with the "b" button
    And I tag the topic with "webship, test"
    And I submit the post
    Then I should be reading the topic "Webship test topic"
    And post 1 should show "bold words" in bold
    And the topic should be tagged "webship"
    When I edit post 1
    And I write the topic title "Webship test topic, renamed"
    And I give the edit reason "Clearer title"
    And I add " Webship test: one more line." to the editor
    And I submit the post
    Then I should be reading the topic "Webship test topic, renamed"
    And the edit log of post 1 should show "Reason: Clearer title"
    And there is no topic "Webship test topic, renamed"
