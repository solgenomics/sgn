
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
my $page = CXGN::Page->new( "SGN Forum | Configure topic", "Lukas" );

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
"Error:\nYou don't have the privileges to edit this topic, because you did not create it.\n\n\n"
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

    print page_title_html("Store your topic");

    print <<HTML;

    Steps: Configure topic</b> -\> Review topic -\> <b>Store topic</b><br /><br /> 
	
    <b>The topic has been successfully stored.</b>
    <br /><br />
    <a href="topics.pl">Return to topics.</a>
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

    print page_title_html("Delete your topic");

    print <<HTML;
    <div class="container-fluid">
    <b>SGN Forum:</b> Delete the following topic, including <b>$topic_post_count</b> posts?</b><br /><br />\n

	<div class="panel panel-default"><div class="panel-body">
	<b>$topic_name</b><br /><br />
	$topic_desc
	</div></div>
	
	<br />
	
	<table width="100%">
	<tr><td align="left"><a href="topics.pl">Cancel</a>
	</td><td align="right">
	<form action="add_topic.pl?action=confirm_delete&amp;topic_id=$topic_id">
	
    <input type="hidden" name="action" value="confirm_delete" />
	<input type="hidden" name="topic_id" value="$topic_id" />
	<input class="btn btn-primary"type="submit" value="delete topic" />\n
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

    $page->header();

    print page_title_html("Topic deleted");
    print <<HTML;

    <b>SOL Forum</b>: Topic deleted.<br /><br />
    The topic $topic_name and $delete_count associated posts, have been successfully deleted.<br />\n
    <a href="topics.pl">back to topics</a>\n

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
        $sort_order_message = "Latest post shown at the bottom.";
    }
    elsif ( $sort_order =~ /desc/i ) {
        $sort_order_message = "Latest post shown at the top.";
    }

    $page->header();

    print page_title_html("Review your topic");

    print <<HTML;
    <div class="container-fluid">
    Steps: Configure topic -\> <b>Review topic</b> -\> Store topic<br /><br /> 
    Please verify the following topic submission: <br /><br />

    <div class="panel panel-primary"><div class="panel-body">
    <b>Topic name</b>: $topic_name<br /><br />
    <b>Topic Description</b>:<br />$display_topic_desc<br /><br />\n
    <b>Other configurations</b>: $sort_order_message<br /><br />\n
    </div></div>
    <br />
    
    <table width="100%"><tr><td align="left">
    <form action="add_topic.pl">
    	<input type="hidden" name="action" value="edit" />
	<input type="hidden" name="topic_id" value="$topic_id" />
	<input type="hidden" name="subject" value="$topic_name" />
	<input type="hidden" name="topic_description" value="$topic_desc" />
	<input type="hidden" name="sort_order" value="$sort_order" />
	<input class="btn btn-info" type="submit" value="Edit Topic" />
	
	</form>
	</td><td align="center">
	<a href="topics.pl">Back to topics</a>
	</td><td align="right">

    <form action="add_topic.pl">
	<input type="hidden" name="action" value="save" />
	<input type="hidden" name="topic_id" value="$topic_id" />
	<input type="hidden" name="subject" value="$topic_name" />
	<input type="hidden" name="topic_description" value="$topic_desc" />
	<input class="btn btn-primary" type="submit" value="store topic"  />
	
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
    $page->header( "SGN | New topic",
        "SGN Forum: Configure topic \"" . $subject . "\"" );

    if ( !$action ) { $action = "review"; }

    #    print page_title_html("SGN Forum: Enter new topic");

    print <<HTML;

    <form method="post" action="add_topic.pl">
	
	Steps: <b>Configure topic</b> -> Review topic -> Store topic<br /><br /> 
	The owner of this topic is: <b>$topic_creator_name</b>.
	The owner can edit and delete the topic at any time when logged in.<br /> 
	HTML tags are not supported. You can add links to your post by using square brackets as follows:<br />
	[url]sgn.cornell.edu[/url].
	This will appear as <a href="http://sgn.cornell.edu">sgn.cornell.edu</a> in the post.<br /><br />
	<b>Note:</b> this service is provided as a courtesy. SGN reserves the right to delete topics and posts at any time for any reason.
	<br /><br />
	<input type="hidden" name="action" value="$action" />
	<input type="hidden" name="topic_id" value="$topic_id" />
	Topic sort order: <br />
	<input type="radio" name="sort_order" value="asc"  />Latest entry at the top<br />
	<input type="radio" name="sort_order" value="desc" checked="1" />Latest entry at the bottom<br />
	<br />
	Topic subject: <input class="form-control" name="subject" value="$subject"><br /><br />
	Post Text:<br />
	<textarea class="form-control" rows="5" cols="80" name="topic_description">$topic_description</textarea>
	<br /><br />

	<table width="100%" summary="">
	<tr><td><a href="topics.pl">Back to forum</a></td>
	<td align="right"><input class="btn btn-primary" type=submit value="Review topic" /></td>
	</tr></table>
	</form>

	<br />
	
      
      <br />
      <br />

HTML

    $page->footer();
}

