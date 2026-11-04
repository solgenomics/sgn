
=head1 NAME

add_topic.pl adds posts to topics or comments to webpages. 

=head1 DESCRIPTION

This script handles the addition, removal, and editing of topic entries to the SOL forum. Users need to be logged in to use it, otherwise they are re-directed to the login page.

The topic information is stored in the relevant tables in the sgn_people schema of the cxgn database. The back-store functionality is wrapped by the CXGN::People::Forum classes, o which this code depends.

=head1 PARAMETERS

The following html parameters are supported:

=over 5

=item action

one of: edit, delete, review, save, add.

=item topic_description

A string with a short description of what the topic is supposed to be about and what it is not about.

=item 

=item

=head1 AUTHOR

Lukas Mueller (lam87@cornell.edu)

=cut

use strict;
use SGN::I18N ();
use CatalystX::GlobalContext '$c';
my SGN::I18N $ui_forum_i18n = SGN::I18N::translate($c);
my %ui_forum = (
    'community.forum.topic_review_step' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_review_step', 'Review topic', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_store_step' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_store_step', 'Store topic', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'auth.legacy.cancel' => SGN::I18N::translate($ui_forum_i18n, 'auth.legacy.cancel', 'Cancel', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.back_to_forum' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.back_to_forum', 'Back to forum', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.back_to_topics' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.back_to_topics', 'back to topics', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.back_to_topics_capitalized' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.back_to_topics_capitalized', 'Back to topics', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.confirm_delete_topic' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.confirm_delete_topic', 'delete topic', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.delete_topic_prompt' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.delete_topic_prompt', 'Delete the following topic, including', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.delete_topic_title' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.delete_topic_title', 'Delete your topic', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.edit_topic' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.edit_topic', 'Edit Topic', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.html_links_supported' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.html_links_supported', 'HTML tags are not supported. You can add links to your post by using square brackets as follows:', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.latest_bottom' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.latest_bottom', 'Latest post shown at the bottom.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.latest_entry_bottom' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.latest_entry_bottom', 'Latest entry at the bottom', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.latest_entry_top' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.latest_entry_top', 'Latest entry at the top', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.latest_top' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.latest_top', 'Latest post shown at the top.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.new_topic_page_title' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.new_topic_page_title', 'New topic', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.other_configurations' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.other_configurations', 'Other configurations', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.post_text_label' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.post_text_label', 'Post Text:', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.posts_word' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.posts_word', 'posts?', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.return_to_topics' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.return_to_topics', 'Return to topics.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.review_topic' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.review_topic', 'Review topic', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.review_topic_title' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.review_topic_title', 'Review your topic', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.steps_label' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.steps_label', 'Steps:', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.store_topic' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.store_topic', 'store topic', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.store_topic_title' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.store_topic_title', 'Store your topic', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_add_post_title' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_add_post_title', 'Configure topic', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_courtesy_notice_lower' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_courtesy_notice_lower', 'this service is provided as a courtesy. SGN reserves the right to delete topics and posts at any time for any reason.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_deleted_notice' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_deleted_notice', 'Topic deleted.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_deleted_title' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_deleted_title', 'Topic deleted', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_description_label' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_description_label', 'Topic Description', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_name_label' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_name_label', 'Topic name', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_owner_intro' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_owner_intro', 'The owner of this topic is:', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_owner_permissions' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_owner_permissions', 'The owner can edit and delete the topic at any time when logged in.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_review_intro' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_review_intro', 'Please verify the following topic submission:', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_sort_order' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_sort_order', 'Topic sort order:', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_stored_success' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_stored_success', 'The topic has been successfully stored.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_subject' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_subject', 'Topic subject:', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 })
);
use warnings;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Login;
use CXGN::People;
use CXGN::Contact;
use CXGN::People::Forum;
use CXGN::Contact;
use CXGN::Page::FormattingHelpers qw/  page_title_html
  blue_section_html  /;

my $dbh = CXGN::DB::Connection->new();
my $page = CXGN::Page->new( "SGN Forum | " . $ui_forum{'community.forum.topic_add_post_title'}, "Lukas" );

my $sp_person_id = CXGN::Login->new($dbh)->verify_session();

my ( $subject, $topic_description, $action, $topic_id, $sort_order ) =
  $page->get_encoded_arguments( "subject", "topic_description", "action",
    "topic_id", "sort_order" );

# we define 3 actions:
# 1) input
# 2) review
# 3) save
# all other values for the action parameter will show the input as default.

#
# get information about the user
#
my $user    = CXGN::People::Person->new( $dbh, $sp_person_id );
my $name    = $user->get_first_name() . " " . $user->get_last_name();
my $user_id = $user->get_sp_person_id();

my $topic = CXGN::People::Forum::Topic->new( $dbh, $topic_id );

# check if the user has the necessary privileges to work with this
# topic. if there it is a topic to be entered, forgo the check.
#
if (   ( $topic->get_person_id() && ( $topic->get_person_id() ne $user_id ) )
    && ( $user->get_user_type() ne "curator" ) )
{
    $page->message_page(
SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_permission_error', 'Error:
You don\'t have the privileges to edit this topic, because you did not create it.


', undef, { entities => '' })
    );
}

if ( $action eq "edit" ) {
    if ($topic_description) {
        $topic->set_topic_description($topic_description);
    }
    if ($subject)    { $topic->set_topic_name($subject); }
    if ($sort_order) { $topic->set_topic_sort_order($sort_order); }
    show_form( $dbh, $topic, "review", $user, $page );
}
elsif ( $action eq "delete" ) {
    delete_topic($topic, $page);
}
elsif ( $action eq "confirm_delete" ) {
    confirm_delete_topic($topic, $page);
}
elsif ( $action eq "review" ) {
    $topic->set_topic_description($topic_description);
    $topic->set_topic_name($subject);
    $topic->set_topic_sort_order($sort_order);
    review_topic($topic, $page);
}
elsif ( $action eq "save" ) {
    if ($topic_description) {
        $topic->set_topic_description($topic_description);
    }
    if ($subject) {
        $topic->set_topic_name($subject);
    }
    if ($sort_order) {
        $topic->set_topic_sort_order($sort_order);
    }
    save_topic( $topic, $user, $page );
}
else {

    #
    # the action is "new" or anything else.
    #
    show_form( $dbh, $topic, "review", $user, $page );
}

sub save_topic {
    my ($topic,$user,$page) = @_;

    # don't clobber the old person id if this is an edit.
    #
    if ( !$topic->get_person_id() ) {
        $topic->set_person_id( $user->get_sp_person_id() );
    }

    # store the topic -- performs an update if topic_id
    # already exists, other new insert...
    #
    $topic->store();

    $page->header();

    print page_title_html($ui_forum{'community.forum.store_topic_title'});

    print <<HTML;

    @{[$ui_forum{'community.forum.steps_label'}]} @{[$ui_forum{'community.forum.topic_add_post_title'}]}</b> -\> @{[$ui_forum{'community.forum.topic_review_step'}]} -\> <b>@{[$ui_forum{'community.forum.topic_store_step'}]}</b><br /><br />\x20
	
    <b>@{[$ui_forum{'community.forum.topic_stored_success'}]}</b>
    <br /><br />
    <a href="topics.pl">@{[$ui_forum{'community.forum.return_to_topics'}]}</a>
    <br /><br />
    
HTML

    $page->footer();
}

sub delete_topic {
    my ($topic,$page) = @_;
    my $topic_id         = $topic->get_forum_topic_id();
    my $topic_name       = $topic->get_topic_name();
    my $topic_post_count = $topic->get_post_count();
    my $topic_desc       = $topic->get_topic_description();

    $page->header();

    print page_title_html($ui_forum{'community.forum.delete_topic_title'});

    print <<HTML;
    <div class="container-fluid">
    <b>SGN Forum:</b> @{[$ui_forum{'community.forum.delete_topic_prompt'}]} <b>$topic_post_count</b> @{[$ui_forum{'community.forum.posts_word'}]}</b><br /><br />\n

	<div class="panel panel-default"><div class="panel-body">
	<b>$topic_name</b><br /><br />
	$topic_desc
	</div></div>
	
	<br />
	
	<table width="100%">
	<tr><td align="left"><a href="topics.pl">@{[$ui_forum{'auth.legacy.cancel'}]}</a>
	</td><td align="right">
	<form action="add_topic.pl?action=confirm_delete&amp;topic_id=$topic_id">
	
    <input type="hidden" name="action" value="confirm_delete" />
	<input type="hidden" name="topic_id" value="$topic_id" />
	<input class="btn btn-primary"type="submit" value="@{[$ui_forum{'community.forum.confirm_delete_topic'}]}" />\n
	</form><br />\n
	</td></tr></table>
	<br /><br /><br />
    </div>

HTML

    $page->footer();
}

sub confirm_delete_topic {
    my ($topic,$page) = @_;

    my $topic_name   = $topic->get_topic_name();
    my $delete_count = ( $topic->delete() - 1 );

    my $ui_topic_deleted_message = SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_delete_success', 'The topic %{topic_name} and %{post_count} associated posts, have been successfully deleted.', { 'topic_name' => "$topic_name", 'post_count' => "$delete_count" }, { entities => '' });
    $page->header();

    print page_title_html($ui_forum{'community.forum.topic_deleted_title'});
    print <<HTML;

    <b>SOL Forum</b>: @{[$ui_forum{'community.forum.topic_deleted_notice'}]}<br /><br />
    @{[$ui_topic_deleted_message]}<br />\n
    <a href="topics.pl">@{[$ui_forum{'community.forum.back_to_topics'}]}</a>\n

HTML

    $page->footer();

}

sub review_topic {
    my ($topic,$page) = @_;

    my $topic_name = $topic->get_topic_name();
    my $topic_desc = $topic->get_topic_description();
    my $topic_id   = $topic->get_forum_topic_id();
    my $sort_order = $topic->get_topic_sort_order();

    my $display_topic_desc = $topic->format_post_text($topic_desc);

    my $sort_order_message = "";
    if ( $sort_order =~ /asc/i ) {
        $sort_order_message = $ui_forum{'community.forum.latest_bottom'};
    }
    elsif ( $sort_order =~ /desc/i ) {
        $sort_order_message = $ui_forum{'community.forum.latest_top'};
    }

    $page->header();

    print page_title_html($ui_forum{'community.forum.review_topic_title'});

    print <<HTML;
    <div class="container-fluid">
    @{[$ui_forum{'community.forum.steps_label'}]} @{[$ui_forum{'community.forum.topic_add_post_title'}]} -\> <b>@{[$ui_forum{'community.forum.topic_review_step'}]}</b> -\> @{[$ui_forum{'community.forum.topic_store_step'}]}<br /><br />\x20
    @{[$ui_forum{'community.forum.topic_review_intro'}]} <br /><br />

    <div class="panel panel-primary"><div class="panel-body">
    <b>@{[$ui_forum{'community.forum.topic_name_label'}]}</b>: $topic_name<br /><br />
    <b>@{[$ui_forum{'community.forum.topic_description_label'}]}</b>:<br />$display_topic_desc<br /><br />\n
    <b>@{[$ui_forum{'community.forum.other_configurations'}]}</b>: $sort_order_message<br /><br />\n
    </div></div>
    <br />
    
    <table width="100%"><tr><td align="left">
    <form action="add_topic.pl">
    	<input type="hidden" name="action" value="edit" />
	<input type="hidden" name="topic_id" value="$topic_id" />
	<input type="hidden" name="subject" value="$topic_name" />
	<input type="hidden" name="topic_description" value="$topic_desc" />
	<input type="hidden" name="sort_order" value="$sort_order" />
	<input class="btn btn-info" type="submit" value="@{[$ui_forum{'community.forum.edit_topic'}]}" />
	
	</form>
	</td><td align="center">
	<a href="topics.pl">@{[$ui_forum{'community.forum.back_to_topics_capitalized'}]}</a>
	</td><td align="right">

    <form action="add_topic.pl">
	<input type="hidden" name="action" value="save" />
	<input type="hidden" name="topic_id" value="$topic_id" />
	<input type="hidden" name="subject" value="$topic_name" />
	<input type="hidden" name="topic_description" value="$topic_desc" />
	<input class="btn btn-primary" type="submit" value="@{[$ui_forum{'community.forum.store_topic'}]}"  />
	
	</form>
	</td></tr></table>
     </div>
HTML

    $page->footer();

}

sub show_form {
    my ($dbh, $topic, $action, $user, $page) = @_;

    my $subject = $topic->get_topic_name();
    if ( !$subject ) { $subject = "new topic"; }
    my $topic_description = $topic->get_topic_description();
    my $topic_id          = $topic->get_forum_topic_id();
    my $topic_creator =
      CXGN::People::Person->new( $dbh, $topic->get_person_id() );
    my $topic_creator_name =
      $topic_creator->get_first_name() . " " . $topic_creator->get_last_name();

    if ( !$topic_creator->get_sp_person_id() ) {
        $topic_creator_name =
          $user->get_first_name() . " " . $user->get_last_name();
    }
    $page->header( "SGN | " . $ui_forum{'community.forum.new_topic_page_title'},
        SGN::I18N::translate($ui_forum_i18n, 'community.forum.configure_topic_header', 'SGN Forum: Configure topic "%{subject}"', { 'subject' => $subject }, { entities => '' }) );

    if ( !$action ) { $action = "review"; }

    #    print page_title_html("SGN Forum: Enter new topic");

    print <<HTML;

    <form method="post" action="add_topic.pl">
	
	Steps: <b>Configure topic</b> -> Review topic -> Store topic<br /><br /> 
	@{[$ui_forum{'community.forum.topic_owner_intro'}]} <b>$topic_creator_name</b>.
	@{[$ui_forum{'community.forum.topic_owner_permissions'}]}<br />\x20
	@{[$ui_forum{'community.forum.html_links_supported'}]}<br />
	[url]sgn.cornell.edu[/url].
	This will appear as <a href="http://sgn.cornell.edu">sgn.cornell.edu</a> in the post.<br /><br />
	<b>Note:</b> @{[$ui_forum{'community.forum.topic_courtesy_notice_lower'}]}
	<br /><br />
	<input type="hidden" name="action" value="$action" />
	<input type="hidden" name="topic_id" value="$topic_id" />
	@{[$ui_forum{'community.forum.topic_sort_order'}]} <br />
	<input type="radio" name="sort_order" value="asc"  />@{[$ui_forum{'community.forum.latest_entry_top'}]}<br />
	<input type="radio" name="sort_order" value="desc" checked="1" />@{[$ui_forum{'community.forum.latest_entry_bottom'}]}<br />
	<br />
	@{[$ui_forum{'community.forum.topic_subject'}]} <input class="form-control" name="subject" value="$subject"><br /><br />
	@{[$ui_forum{'community.forum.post_text_label'}]}<br />
	<textarea class="form-control" rows="5" cols="80" name="topic_description">$topic_description</textarea>
	<br /><br />

	<table width="100%" summary="">
	<tr><td><a href="topics.pl">@{[$ui_forum{'community.forum.back_to_forum'}]}</a></td>
	<td align="right"><input class="btn btn-primary" type=submit value="@{[$ui_forum{'community.forum.review_topic'}]}" /></td>
	</tr></table>
	</form>

	<br />
	
      
      <br />
      <br />

HTML

    $page->footer();
}

