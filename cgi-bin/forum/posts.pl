use strict;
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



my $page = CXGN::Page->new( "SGN Forum Main", "Lukas");

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
    print "<p>No topic was specified. Please go back and try another topic.\n</p>";
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

print page_title_html("Forum Topic: ".$topic->get_topic_name()."\n");
my $topic_started_by = "<br />This topic was started by <b><a href=\"/solpeople/personal-info.pl?sp_person_id=".
    ($topic_start_person->get_sp_person_id)."\">".
    ($topic_start_person->get_first_name()." ".$topic_start_person->get_last_name())."</a></b>.\n";

my $topic_name = $topic->get_topic_name();
my $topic_description = $topic->get_topic_description();
my $forum_toolbar = forum_toolbar($topic_id, $sp_person_id);
if (!$topic_description) { $topic_description = "(topic description not available)"; }


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
	$s .= "<br/>No user comments.<br/>";
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
	    $remove_link = "<a href=\"forum_post_delete.pl?post_id=".($p->get_forum_post_id())."&amp;refering_page=$encoded_url\">Delete</a>\n"; 
	}
	
	$s .= qq { <div class="panel panel-default"><div class="panel-heading"><div class="row"><div class="col-sm-10">Posted by <b><a href="/solpeople/personal-info.pl?sp_person_id=$post_sp_person_id">$post_name</a>$user_type</b> on $post_date </div><div class="col-sm-2">$remove_link</div></div></div> };
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
    my $s = "<a href=\"topics.pl\">View topics list</a> | \n";

    $s .= "<a href=\"add_post.pl?topic_id=$topic_id\">Add post</a>";
    $s .= "\n";
    return $s;
}
