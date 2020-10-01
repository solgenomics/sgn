
use strict;
use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::People;
use CXGN::People::Person;
use CXGN::Login;
use CXGN::People::Forum;
use CXGN::Contact;
use CXGN::Page::FormattingHelpers qw /page_title_html blue_section_html/;

my $page = CXGN::Page->new("Forum Main", "Lukas");
	
my $dbh = CXGN::DB::Connection->new();
my $sp_person_id = CXGN::Login->new($dbh)->has_session();

my ($topic_name, $topic_description) = $page -> get_encoded_arguments("topic_name", "topic_description", "topic_id", "post_text", "post_parent_id");

# create a user object, representing the user who is logged in,
# or a dummy user object if not logged in.
#
my $user = undef;

my $name="";
if ($sp_person_id) { 
    $user = CXGN::People::Person->new($dbh, $sp_person_id);
    $sp_person_id = $user -> get_sp_person_id();
    $name = $user->get_first_name()." ".$user->get_last_name();
}
else { $user = CXGN::People::Person->new($dbh); }

if ($topic_name) { 
    my $sp_person_id = CXGN::Login->new($dbh)->verify_session();

    my $topic = CXGN::People::Forum::Topic -> new($dbh);
    $topic->set_topic_name($topic_name);
    $topic->set_topic_description($topic_description);
    $topic->set_person_id($sp_person_id);
    $topic->store();

    CXGN::Contact::email_us("New topic submitted: $topic_name","Description: $topic_description",'email');

}



$page -> header();

print page_title_html("Forum Topics");

my $login_string="";

if ($name) { $login_string = qq { <div class="row"><div class="panel panel-primary"><div class="panel-body"><div class="row"><div class="col-sm-10">You are logged in as <b>$name</b>.</div><div class="col-sm-2"><button class="btn btn-primary" onclick='location.href="add_topic.pl?action=new";'>Add topic</button>.</div></div></div></div></div> }; }
else { $login_string="<div class=\"row\"><div class=\"panel panel-primary\"><div class=\"panel-body\"><div class=\"row\"><div class=\"col-sm-10\"><b>Note:</b> <ul><li>You are not logged in.</li><li>You have to be logged in to add new topics and posts. </li><li>You don't need to be logged in for browsing.</li></ul></div><div class=\"col-sm-2\"><button class=\"btn btn-primary\" onclick='location.href=\"/user/login?goto_url=/forum/topics.pl\";'>Login</button></div></div></div></div></div>"; }

print $login_string;

my $s = "";
$s = topics_list($dbh, $name, $user);
print $s;

$page -> footer();




sub topics_list {
    my $dbh = shift;
    my $login = shift;
    my $user = shift;

    my @topics = CXGN::People::Forum::Topic::all_topics($dbh);

    my $s = "";

    foreach my $t (@topics) { 
	my $topic_name = $t->get_topic_name();
	my $topic_description = $t->get_topic_description();
	
	my $topic_id = $t -> get_forum_topic_id();
	my $submitter = CXGN::People::Person->new($dbh, $t->get_person_id());
	my $submitter_name = $submitter->get_first_name()." ".$submitter->get_last_name();
	my $submitter_id = $submitter->get_sp_person_id();
	my $post_count = $t -> get_post_count();
	my $most_recent_post_date = $t -> get_most_recent_post_date();
	my $topic_person_id = $t->get_person_id();
	my $user_id = $user->get_sp_person_id();
	my $append = "";

	my $display_topic_desc = $t->format_post_text($topic_description);
	if (
	    ($user_id && $topic_person_id == $user_id) 
	    || $user->get_user_type() eq "curator"
	    ) {   
	    $append = qq {
		<a href="add_topic.pl?action=edit&amp;topic_id=$topic_id">Edit</a> | 
		    <a href="add_topic.pl?action=delete&amp;topic_id=$topic_id">Delete</a> 
		    
		}
	}
	else { 
	    $append = "&nbsp;";
	}
	$s .= qq {
            <div class="row">
              <div class="panel panel-default">
                <div class="panel-heading">
                  <div class="row">
                    <div class="col-sm-6">
                      <a href="posts.pl?topic_id=$topic_id"><b>$topic_name</b></a>
                    </div>
                    <div class="col-sm-2">
                      Started by:<br/><b><a href="/solpeople/personal-info.pl?sp_person_id=$submitter_id">$submitter_name</a></b>
                    </div>
                    <div class="col-sm-2">
                      <a href="posts.pl?topic_id=$topic_id"><b>$post_count</b> Posts</a>
                    </div>
                    <div class="col-sm-2">
                      $most_recent_post_date
                      <br/>
                      $append
                    </div>
                  </div>
                </div>
                <div class="panel-body">
                  $display_topic_desc
                  
                </div>
              </div>
            </div>

	    }

    }	
    return $s;    
}
