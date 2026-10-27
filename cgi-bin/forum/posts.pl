use strict;
use SGN::I18N ();
use CatalystX::GlobalContext '$c';
my SGN::I18N $ui_forum_i18n = SGN::I18N::translate($c);
my %ui_forum = (
    'community.forum.add_post_link' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.add_post_link', 'Add post', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.main_title' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.main_title', 'Main', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.no_topic_specified' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.no_topic_specified', 'No topic was specified. Please go back and try another topic.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.no_user_comments' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.no_user_comments', 'No user comments.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.posted_by' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.posted_by', 'Posted by', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_description_not_available' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_description_not_available', '(topic description not available)', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topic_started_by' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topic_started_by', 'This topic was started by', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.view_topics_list' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.view_topics_list', 'View topics list', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'lists.render.action.delete' => SGN::I18N::translate($ui_forum_i18n, 'lists.render.action.delete', 'Delete', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 })
);
use warnings;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::People;
use CXGN::Login;
use CXGN::People::Forum;
use CXGN::Page::FormattingHelpers qw(page_title_html blue_section_html);

use URI::Escape;

=head1 NAME

posts.pl - a web script that displays posts for a given topic. 

=head1 DESCRIPTION

Parameters:
topic_id        - the id of the topic to be displayed. Required. Omitting it will display an error message.
post_text       - if a post text is being supplied, the post_text is added to the topic.
post_parent_id  - the id of the post that is the parent of this post. Currently not used in this interface.

Note: people have to be logged in to add posts. Users can browse posts without being logged in.

=head1 AUTHOR

Lukas Mueller (lam87@cornell.edu)

=cut



my $page = CXGN::Page->new( "SGN Forum " . $ui_forum{'community.forum.main_title'}, "Lukas");

my $dbh = CXGN::DB::Connection->new();
my $sp_person_id = CXGN::Login->new($dbh)->has_session();

my ($topic_id, $post_text, $post_parent_id) = $page -> get_encoded_arguments("topic_id", "post_text", "post_parent_id");

my $person;
if ($sp_person_id) { 
    $person = CXGN::People::Person->new($dbh, $sp_person_id);
    $sp_person_id = $person -> get_sp_person_id();
}
#
# do some sanity checking
#
if (!$topic_id) { 
    $page->header();
    print "<p>@{[$ui_forum{'community.forum.no_topic_specified'}]}\n</p>";
    $page->footer();
    exit(0);
}
#
# get some information about the topic
#
my $topic = CXGN::People::Forum::Topic->new($dbh, $topic_id);
if ($topic->get_topic_name() eq "") { 
    $page->header();
    print "<p>The topic you are refering to does not exist or no longer exists. Please <a href=\"topics.pl\">go back</a> and try again!<br /><br />\n"; 
    $page->footer();
    exit(0);
}
my $topic_start_person_id = $topic -> get_person_id();
my $topic_start_person = CXGN::People::Person->new($dbh, $topic_start_person_id);
#
# generate the post list 
#
my $s = posts_list($dbh, $sp_person_id, $topic_id, $page);
# 
# render the page
#
$page->header();

print page_title_html(SGN::I18N::translate($ui_forum_i18n, 'community.forum.forum_topic_title', 'Forum Topic: %{topic_name}
', { 'topic_name' => $topic->get_topic_name() }, { entities => '' }));
my $topic_started_by = "<br />@{[$ui_forum{'community.forum.topic_started_by'}]} <b><a href=\"/solpeople/personal-info.pl?sp_person_id=".
    ($topic_start_person->get_sp_person_id)."\">".
    ($topic_start_person->get_first_name()." ".$topic_start_person->get_last_name())."</a></b>.\n";

my $topic_name = $topic->get_topic_name();
my $topic_description = $topic->get_topic_description();
my $forum_toolbar = forum_toolbar($topic_id, $sp_person_id);
if (!$topic_description) { $topic_description = $ui_forum{'community.forum.topic_description_not_available'}; }


print qq { <div class="container-fluid"><div class="row">$forum_toolbar<br/><br/>  };
print qq { <div class="panel panel-primary"><div class="panel-body"><b>$topic_name</b><br /><br />$topic_description<br />$topic_started_by</div></div> }; 
#print blue_section_html("Topic Description", $topic_description." ".$topic_started_by);
print $s;

print "<br/>$forum_toolbar</div></div>\n";

$page->footer();


sub posts_list { 
    my ($dbh,$sp_person_id,$topic_id,$page) = @_;
    my $topic = CXGN::People::Forum::Topic -> new($dbh, $topic_id);
    my $user = CXGN::People::Person->new($dbh, $sp_person_id);
    
    my @posts = $topic -> get_all_posts($topic_id);
    
    my $s = "";
    $s .= qq { };
    
    if (!@posts) { 
	$s .= "<br/>@{[$ui_forum{'community.forum.no_user_comments'}]}<br/>";
    }
    
    foreach my $p (@posts) { 
	my $post_subject = $p->get_subject();
	my $post_person_id = $p -> get_person_id();
	my $post_person = CXGN::People::Person -> new($dbh, $post_person_id);
	my $post_sp_person_id = $post_person -> get_sp_person_id();
	my $post_name = $post_person->get_first_name()." ".$post_person->get_last_name();
        my $user_type = $post_person->get_user_type();
        if($user_type and $user_type ne 'user')
        {
            $user_type=" ($user_type)";
        }
        else
        {
            $user_type='';
        }
	my $post_text = $p -> get_post_text();
	my $post_date = $p -> get_formatted_post_time();
	my $remove_link = "&nbsp;";
	
	my $refering_url = $page->{request}->uri()."?".$page->{request}->args();
	my $encoded_url = URI::Escape::uri_escape($refering_url);
	if (($sp_person_id && ($post_person_id == $sp_person_id)) || $user->get_user_type() eq "curator") { 
	    $remove_link = "<a href=\"forum_post_delete.pl?post_id=".($p->get_forum_post_id())."&amp;refering_page=$encoded_url\">@{[$ui_forum{'lists.render.action.delete'}]}</a>\n";
	}
	
	$s .= qq { <div class="panel panel-default"><div class="panel-heading"><div class="row"><div class="col-sm-10">@{[$ui_forum{'community.forum.posted_by'}]} <b><a href="/solpeople/personal-info.pl?sp_person_id=$post_sp_person_id">$post_name</a>$user_type</b> on $post_date </div><div class="col-sm-2">$remove_link</div></div></div> };
	$s .= qq { <div class="panel-body">$post_text</div></div> };
    }
    $s .= "";
}

sub old_posts_list {

    my $topic_id = shift;
    my $topic = Topic -> new($topic_id);
    
    my @posts = $topic -> get_all_posts($topic_id);

    my $previous_parent_id = -1;
    my $previous_id = -1;
    my $indent = 0;
    my $indent_size = 20;

    my @parent_ids = ();

    unless( @posts ) {
        return "Currently there are no posts under this topic. Please use the Add Posting link to add a post. Please note that you have to be logged in to post. [<a href=\"login.pl\">Login</a>]<br /><br />";
    }

    my $s = "<table border=\"0\" cellpadding=\"2\" cellspacing=\"2\">";

    foreach my $p (@posts) { 
	my $subject   = $p->get_subject();
	if (!$subject) { $subject = "[No subject]"; }
	my $post_text = $p->get_post_text();

	my $person_id = $p->get_person_id();
	my $post_time = $p->get_post_time();
	my $parent_id = $p->get_parent_post_id();
	my $forum_post_id = $p -> get_forum_post_id();
	
	my $person = CXGN::People::Person->new($person_id);
	my $name = $person->get_first_name()." ".$person->get_last_name();

	#$indent = $p->get_post_level() * $indent_size;
	my $has_parent = 0;
	for ( my $i=0; $i<@parent_ids; $i++) { 
	    if ($parent_id == $parent_ids[$i]) { 
		$indent=$i;
		$parent_ids[$i+1]=$forum_post_id;
		$has_parent=1;
	    }
	}

	if (!$has_parent) { 
	    push @parent_ids, $parent_id; 
	    $indent = @parent_ids;
	}

	$post_time =~ s/(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/$2\-$3\-$1 $4\:$5\:$6/;
	my $indent_pixels = $indent * $indent_size;
	my $indent_chars = "";
	for (my $i=0; $i<$indent; $i++) { 
	    $indent_chars .="&rarr;";
	}

	my $respond_link = "Respond";
	if ($person_id) {
	    $respond_link = "<a href=\"add_post.pl?parent_post_id=$forum_post_id&amp;topic_id=$topic_id\">Respond</a>"; 
	}
        #my $post_level = $p -> get_post_level();
	$s .= "<tr><td colspan=\"4\" class=\"bgcolorselected\">From: <b>$name</b> </td><td colspan=3 class=\"bgcolorselected\" align=\"right\">Posted: $post_time</td></tr>\n";
	$s .= "<tr><td><table cellpadding=\"5\"><tr><td width=\"$indent_pixels\">$indent_chars</td><td><b>$subject</b></td></tr></table></td><td colspan=\"4\" wrap=\"wrap\">$post_text</td></tr>";
	$s .="<tr><td colspan=\"7\" align=\"right\">$respond_link</td></tr>";
	$s .= "<tr><td><img src=\"/img/dot_clear.png\" height=\"2\" /></td><td colspan=\"5\"><img src=\"/img/dot_clear.png\" height=\"2\" /></td></tr>";
    }
    $s.="</table>\n<br /><br />";

    return $s;
}

sub forum_toolbar {
    my $topic_id=shift;
    my $person_id = shift; # not used... always display link, will go to login page if not logged in
    my $s = "<a href=\"topics.pl\">@{[$ui_forum{'community.forum.view_topics_list'}]}</a> | \n";

    $s .= "<a href=\"add_post.pl?topic_id=$topic_id\">@{[$ui_forum{'community.forum.add_post_link'}]}</a>";
    $s .= "\n";
    return $s;
}
