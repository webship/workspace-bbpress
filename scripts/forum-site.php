<?php
/**
 * The forums of the test site: its settings, the accounts' forum roles and the test content.
 *
 * Run inside the site with WP-CLI, once the forum plugin is active:
 *
 *   wp eval-file forum-site.php              settings, roles and content (what is there already is kept)
 *   wp eval-file forum-site.php settings     only the settings, and the forum roles of the accounts that exist
 *   wp eval-file forum-site.php roles        only the forum roles of the accounts that exist
 *   wp eval-file forum-site.php content      only the content (what is there already is kept)
 *   wp eval-file forum-site.php reset        put the content back as the build left it: what a stopped run left
 *                                            behind goes, the favorites and subscriptions of the accounts too
 *   wp eval-file forum-site.php status       say what the forums hold, and the forum role of each account
 *
 * Everything is made with the plugin's own functions (bbp_insert_forum, bbp_insert_topic, bbp_insert_reply,
 * bbp_set_user_role), so the counters and the "last activity" of every forum and topic are the ones the plugin
 * keeps. No account is created here: the build creates them, this gives each its forum role.
 */

if ( ! function_exists( 'bbp_insert_forum' ) ) {
	fwrite( STDERR, "The forum plugin is not active on this site.\n" );
	exit( 1 );
}

$webship_mode = isset( $args[0] ) ? $args[0] : 'all';

// The command line runs as nobody, and the forums show nobody their private and hidden forums: the script works
// as the first administrator of the site, a keymaster of its forums.
$webship_admins = get_users( array( 'role' => 'administrator', 'orderby' => 'ID', 'order' => 'ASC', 'number' => 1, 'fields' => 'ID' ) );
if ( ! $webship_admins ) {
	fwrite( STDERR, "The site has no administrator to write the forums as.\n" );
	exit( 1 );
}
wp_set_current_user( (int) $webship_admins[0] );

/** The accounts by login => forum role. An account that is not on the site is skipped. */
function webship_forum_roles() {
	return array(
		'keymaster'   => bbp_get_keymaster_role(),
		'moderator'   => bbp_get_moderator_role(),
		'participant' => bbp_get_participant_role(),
		'spectator'   => bbp_get_spectator_role(),
		'blocked'     => bbp_get_blocked_role(),
	);
}

function webship_user_id( $login ) {
	$user = get_user_by( 'login', $login );
	if ( $user ) {
		return (int) $user->ID;
	}
	// A site without the forum accounts: its first administrator writes the content.
	$admins = get_users( array( 'role' => 'administrator', 'orderby' => 'ID', 'order' => 'ASC', 'number' => 1, 'fields' => 'ID' ) );
	return $admins ? (int) $admins[0] : 1;
}

function webship_set_roles() {
	foreach ( webship_forum_roles() as $login => $role ) {
		$user = get_user_by( 'login', $login );
		if ( $user && bbp_get_user_role( $user->ID ) !== $role ) {
			bbp_set_user_role( $user->ID, $role );
			echo "  {$login}: the forum role {$role}\n";
		}
	}
	// Every administrator of the site keeps the gate of its forums.
	foreach ( get_users( array( 'role' => 'administrator', 'fields' => 'ID' ) ) as $id ) {
		if ( bbp_get_user_role( $id ) !== bbp_get_keymaster_role() ) {
			bbp_set_user_role( $id, bbp_get_keymaster_role() );
		}
	}
}

function webship_settings() {
	$settings = array(
		// A suite posts faster than a person: no wait between two posts, and no time limit on editing one's own.
		'_bbp_throttle_time'        => 0,
		'_bbp_allow_content_edit'   => 1,
		'_bbp_edit_lock'            => 0,
		'_bbp_allow_anonymous'      => 0,
		'_bbp_enable_favorites'     => 1,
		'_bbp_enable_subscriptions' => 1,
		'_bbp_allow_topic_tags'     => 1,
		'_bbp_allow_search'         => 1,
		'_bbp_allow_revisions'      => 1,
		'_bbp_use_wp_editor'        => 1,
		'_bbp_thread_replies_depth' => 2,
		'_bbp_allow_threaded_replies' => 0,
		'_bbp_topics_per_page'      => 15,
		'_bbp_replies_per_page'     => 15,
		'_bbp_default_role'         => bbp_get_participant_role(),
		'_bbp_allow_global_access'  => 1,
	);
	foreach ( $settings as $name => $value ) {
		update_option( $name, $value );
	}
}

/** Every status a forum, a topic or a reply can have: "any" leaves out the private and hidden forums and the closed topics. */
function webship_statuses() {
	return array_values( array_diff( get_post_stati(), array( 'auto-draft', 'inherit' ) ) );
}

function webship_find( $type, $title, $parent = null ) {
	$query = array(
		'post_type'      => $type,
		'title'          => $title,
		'post_status'    => webship_statuses(),
		'posts_per_page' => 1,
		'fields'         => 'ids',
		'orderby'        => 'ID',
		'order'          => 'ASC',
		'suppress_filters' => true,
	);
	if ( null !== $parent ) {
		$query['post_parent'] = $parent;
	}
	$found = get_posts( $query );
	return $found ? (int) $found[0] : 0;
}

/** The moment of the n-th item of the content: one minute apart, a week ago, so the order on every list is fixed. */
function webship_date( $n ) {
	return gmdate( 'Y-m-d H:i:s', strtotime( '2026-01-05 09:00:00 UTC' ) + 60 * $n );
}

function webship_forum( $title, $content, $parent = 0, $order = 0 ) {
	$id = webship_find( bbp_get_forum_post_type(), $title );
	if ( ! $id ) {
		$id = bbp_insert_forum(
			array(
				'post_title'   => $title,
				'post_content' => $content,
				'post_parent'  => $parent,
				'post_author'  => webship_user_id( 'keymaster' ),
				'menu_order'   => $order,
				'post_date'    => webship_date( 0 ),
				'post_date_gmt' => webship_date( 0 ),
			),
			array( 'forum_id' => $parent )
		);
		echo "  forum: {$title}\n";
	}
	return (int) $id;
}

function webship_topic( $forum, $title, $content, $author, $n, $tags = array() ) {
	$id = webship_find( bbp_get_topic_post_type(), $title );
	if ( ! $id ) {
		$id = bbp_insert_topic(
			array(
				'post_parent'   => $forum,
				'post_title'    => $title,
				'post_content'  => $content,
				'post_author'   => webship_user_id( $author ),
				'post_date'     => webship_date( $n ),
				'post_date_gmt' => webship_date( $n ),
			),
			array( 'forum_id' => $forum, 'last_active_time' => webship_date( $n ) )
		);
		if ( $tags ) {
			wp_set_object_terms( $id, $tags, bbp_get_topic_tag_tax_id() );
		}
	}
	return (int) $id;
}

function webship_reply( $forum, $topic, $content, $author, $n ) {
	$existing = get_posts(
		array(
			'post_type'      => bbp_get_reply_post_type(),
			'post_parent'    => $topic,
			'post_status'    => webship_statuses(),
			'posts_per_page' => -1,
		)
	);
	foreach ( $existing as $reply ) {
		if ( $reply->post_content === $content ) {
			return (int) $reply->ID;
		}
	}
	return (int) bbp_insert_reply(
		array(
			'post_parent'   => $topic,
			'post_content'  => $content,
			'post_author'   => webship_user_id( $author ),
			'post_date'     => webship_date( $n ),
			'post_date_gmt' => webship_date( $n ),
		),
		array( 'forum_id' => $forum, 'topic_id' => $topic )
	);
}

/** The content, as one list: the reset reads it too, to tell the build's topics from a run's leftovers. */
function webship_content() {
	$community = webship_forum( 'Community', 'Where the members meet.', 0, 1 );
	if ( ! bbp_is_forum_category( $community ) ) {
		bbp_categorize_forum( $community );
	}
	$general  = webship_forum( 'General discussion', 'Anything about the site and its community.', $community, 1 );
	$help     = webship_forum( 'Help and support', 'Questions and their answers.', $community, 2 );
	$showcase = webship_forum( 'Showcase', 'What the members made.', 0, 2 );
	$archive  = webship_forum( 'Archive', 'Old topics, kept to read.', 0, 3 );
	$lounge   = webship_forum( 'Members lounge', 'For the members of the forums only.', 0, 4 );
	$staff    = webship_forum( 'Staff room', 'For the moderators and the keymasters only.', 0, 5 );

	$n      = 1;
	$topics = array();

	$topics[] = $rules = webship_topic( $general, 'Forum rules', 'Be kind, stay on topic, and search before you ask.', 'keymaster', $n++, array( 'rules' ) );
	$topics[] = $welcome = webship_topic( $general, 'Welcome to the forums', 'Say hello and tell us what you are working on.', 'keymaster', $n++, array( 'welcome' ) );
	webship_reply( $general, $welcome, 'Hello everyone, glad to be here.', 'participant', $n++ );
	webship_reply( $general, $welcome, 'Welcome aboard. Ask in Help and support when you are stuck.', 'moderator', $n++ );
	$topics[] = $garden = webship_topic( $general, 'A community garden in spring', 'We planted tomatoes, basil and marigolds this year.', 'participant', $n++, array( 'garden', 'spring' ) );
	webship_reply( $general, $garden, 'Marigolds keep the aphids away from the tomatoes.', 'moderator', $n++ );
	$topics[] = $closed = webship_topic( $general, 'The spring meetup is over', 'Thank you all for coming. See you next year.', 'moderator', $n++, array( 'meetup', 'spring' ) );
	webship_reply( $general, $closed, 'It was a great day.', 'participant', $n++ );

	$topics[] = $password = webship_topic( $help, 'How do I change my password?', 'I cannot find where to change my password.', 'participant', $n++, array( 'account', 'howto' ) );
	webship_reply( $help, $password, 'Open your profile, choose Edit, and type a new password at the bottom.', 'moderator', $n++ );
	webship_reply( $help, $password, 'That worked, thank you.', 'participant', $n++ );
	$topics[] = $avatar = webship_topic( $help, 'Where do the avatars come from?', 'My picture is a grey figure. How do I set my own?', 'participant', $n++, array( 'account' ) );
	$topics[] = $long = webship_topic( $help, 'A long conversation', 'This topic has more replies than one page shows.', 'moderator', $n++, array( 'howto' ) );
	for ( $i = 1; $i <= 17; $i++ ) {
		webship_reply( $help, $long, sprintf( 'Reply number %02d of the long conversation.', $i ), ( $i % 2 ) ? 'participant' : 'moderator', $n++ );
	}

	for ( $i = 1; $i <= 16; $i++ ) {
		$topics[] = webship_topic( $showcase, sprintf( 'Showcase entry %02d', $i ), sprintf( 'The entry number %02d of the showcase.', $i ), ( $i % 2 ) ? 'participant' : 'moderator', $n++, array( 'showcase' ) );
	}

	$topics[] = $old = webship_topic( $archive, 'The forums opened', 'The first topic of these forums, kept in the archive.', 'keymaster', $n++ );
	webship_reply( $archive, $old, 'A good start.', 'moderator', $n++ );

	$topics[] = webship_topic( $lounge, 'Members only: the next meetup', 'The members plan the next meetup here.', 'participant', $n++ );
	$topics[] = webship_topic( $staff, 'Staff only: the moderation notes', 'Notes for the moderators.', 'moderator', $n++ );

	// The states the plugin keeps beside a post: sticky, super sticky, closed; a closed, a private and a hidden forum.
	if ( ! bbp_is_topic_super_sticky( $rules ) ) {
		bbp_stick_topic( $rules, true );
	}
	if ( ! bbp_is_topic_sticky( $welcome, false ) ) {
		bbp_stick_topic( $welcome );
	}
	if ( ! bbp_is_topic_closed( $closed ) ) {
		bbp_close_topic( $closed );
	}
	if ( ! bbp_is_forum_closed( $archive, false ) ) {
		bbp_close_forum( $archive );
	}
	if ( ! bbp_is_forum_private( $lounge, false ) ) {
		bbp_privatize_forum( $lounge );
	}
	if ( ! bbp_is_forum_hidden( $staff, false ) ) {
		bbp_hide_forum( $staff );
	}

	return array(
		'forums' => array( $community, $general, $help, $showcase, $archive, $lounge, $staff ),
		'topics' => $topics,
	);
}

/** Count again what the plugin counts: the topics and replies of every forum and topic, their last activity. */
function webship_recount() {
	foreach ( get_posts( array( 'post_type' => bbp_get_topic_post_type(), 'post_status' => webship_statuses(), 'posts_per_page' => -1, 'fields' => 'ids' ) ) as $topic ) {
		bbp_update_topic_reply_count( $topic );
		bbp_update_topic_reply_count_hidden( $topic );
		bbp_update_topic_voice_count( $topic );
		bbp_update_topic_last_reply_id( $topic );
		bbp_update_topic_last_active_id( $topic );
		bbp_update_topic_last_active_time( $topic );
	}
	$forums = get_posts( array( 'post_type' => bbp_get_forum_post_type(), 'post_status' => webship_statuses(), 'posts_per_page' => -1, 'fields' => 'ids', 'orderby' => 'post_parent', 'order' => 'DESC' ) );
	foreach ( $forums as $forum ) {
		bbp_update_forum( array( 'forum_id' => $forum ) );
	}
	foreach ( get_users( array( 'fields' => 'ID' ) ) as $user ) {
		bbp_update_user_topic_count( $user, bbp_get_user_topic_count_raw( $user ) );
		bbp_update_user_reply_count( $user, bbp_get_user_reply_count_raw( $user ) );
	}
	delete_option( '_bbp_private_forums' );
	delete_option( '_bbp_hidden_forums' );
	bbp_repair_forum_visibility();
	wp_cache_flush();
}

/** Take away what a stopped run left: every topic and reply that is not the build's, and what the accounts marked. */
function webship_reset() {
	// What a run may have left on the build's own topics and forums: a topic stuck or closed, a forum closed. The
	// content below puts the marks of the build back.
	foreach ( get_posts( array( 'post_type' => array( bbp_get_topic_post_type(), bbp_get_reply_post_type() ), 'post_status' => array( 'trash', 'spam', 'pending' ), 'posts_per_page' => -1, 'fields' => 'ids' ) ) as $post ) {
		wp_untrash_post( $post );
		wp_update_post( array( 'ID' => $post, 'post_status' => 'publish' ) );
	}
	foreach ( get_posts( array( 'post_type' => bbp_get_topic_post_type(), 'post_status' => webship_statuses(), 'posts_per_page' => -1, 'fields' => 'ids' ) ) as $topic ) {
		bbp_unstick_topic( $topic );
		if ( bbp_is_topic_closed( $topic ) ) {
			bbp_open_topic( $topic );
		}
	}
	foreach ( get_posts( array( 'post_type' => bbp_get_forum_post_type(), 'post_status' => webship_statuses(), 'posts_per_page' => -1, 'fields' => 'ids' ) ) as $forum ) {
		if ( bbp_is_forum_closed( $forum, false ) ) {
			bbp_open_forum( $forum );
		}
	}
	$content = webship_content();
	$kept    = array();
	foreach ( $content['topics'] as $topic ) {
		$kept[ $topic ] = true;
	}
	$gone = 0;
	$all  = get_posts( array( 'post_type' => bbp_get_topic_post_type(), 'post_status' => webship_statuses(), 'posts_per_page' => -1, 'fields' => 'ids' ) );
	foreach ( $all as $topic ) {
		if ( empty( $kept[ $topic ] ) ) {
			foreach ( get_posts( array( 'post_type' => bbp_get_reply_post_type(), 'post_parent' => $topic, 'post_status' => webship_statuses(), 'posts_per_page' => -1, 'fields' => 'ids' ) ) as $reply ) {
				wp_delete_post( $reply, true );
			}
			wp_delete_post( $topic, true );
			$gone++;
		}
	}
	// The replies a run added to the build's topics: the ones written after the content's own dates.
	$limit = webship_date( 500 );
	foreach ( get_posts( array( 'post_type' => bbp_get_reply_post_type(), 'post_status' => webship_statuses(), 'posts_per_page' => -1, 'date_query' => array( array( 'after' => $limit ) ), 'fields' => 'ids' ) ) as $reply ) {
		wp_delete_post( $reply, true );
		$gone++;
	}
	foreach ( array_keys( webship_forum_roles() ) as $login ) {
		$user = get_user_by( 'login', $login );
		if ( ! $user ) {
			continue;
		}
		foreach ( array( '_bbp_favorite', '_bbp_subscription' ) as $key ) {
			delete_metadata( 'post', 0, $key, $user->ID, true );
		}
	}
	echo "  {$gone} leftover(s) removed\n";
}

/** Say what the forums hold: each forum with its marks and counters, and the forum role of each account. */
function webship_status() {
	$forums = get_posts( array( 'post_type' => bbp_get_forum_post_type(), 'post_status' => webship_statuses(), 'posts_per_page' => -1, 'orderby' => 'menu_order ID', 'order' => 'ASC' ) );
	echo sprintf( "Forums (%d):\n", count( $forums ) );
	foreach ( $forums as $forum ) {
		$marks = array();
		if ( bbp_is_forum_category( $forum->ID ) ) {
			$marks[] = 'category';
		}
		if ( bbp_is_forum_closed( $forum->ID, false ) ) {
			$marks[] = 'closed';
		}
		if ( bbp_is_forum_private( $forum->ID, false ) ) {
			$marks[] = 'private';
		}
		if ( bbp_is_forum_hidden( $forum->ID, false ) ) {
			$marks[] = 'hidden';
		}
		echo sprintf( "  %s%s: %d topics, %d replies%s\n", $forum->post_parent ? '  ' : '', $forum->post_title, bbp_get_forum_topic_count( $forum->ID, true, true ), bbp_get_forum_reply_count( $forum->ID, true, true ), $marks ? ' (' . implode( ', ', $marks ) . ')' : '' );
	}
	$topics  = wp_count_posts( bbp_get_topic_post_type() );
	$replies = wp_count_posts( bbp_get_reply_post_type() );
	echo sprintf( "Topics: %d open, %d closed, %d pending, %d spam, %d in the trash.\n", (int) $topics->publish, isset( $topics->closed ) ? (int) $topics->closed : 0, (int) $topics->pending, isset( $topics->spam ) ? (int) $topics->spam : 0, (int) $topics->trash );
	echo sprintf( "Replies: %d published, %d pending, %d spam, %d in the trash.\n", (int) $replies->publish, (int) $replies->pending, isset( $replies->spam ) ? (int) $replies->spam : 0, (int) $replies->trash );
	echo "Accounts:\n";
	foreach ( get_users( array( 'orderby' => 'ID', 'order' => 'ASC' ) ) as $user ) {
		$role = bbp_get_user_role( $user->ID );
		echo sprintf( "  %s: %s\n", $user->user_login, $role ? bbp_get_dynamic_role_name( $role ) : '(no forum role yet)' );
	}
}

if ( 'roles' === $webship_mode ) {
	webship_set_roles();
} elseif ( 'settings' === $webship_mode ) {
	webship_settings();
	webship_set_roles();
} elseif ( 'status' === $webship_mode ) {
	webship_status();
} elseif ( 'reset' === $webship_mode ) {
	webship_settings();
	webship_set_roles();
	webship_reset();
	webship_recount();
} else {
	if ( 'content' !== $webship_mode ) {
		webship_settings();
	}
	webship_set_roles();
	$content = webship_content();
	webship_recount();
	echo sprintf( "The forums: %d forums, %d topics, %d replies.\n", count( $content['forums'] ), count( $content['topics'] ), (int) wp_count_posts( bbp_get_reply_post_type() )->publish );
}
