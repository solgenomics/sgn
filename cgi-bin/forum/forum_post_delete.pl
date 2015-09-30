#
# deletes a forum post
#
# Lukas Mueller, April 6, 2005
#

use strict;
use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Login;
use CXGN::People::Forum;
use CXGN::People;

#
# create a page object
#
my $page = CXGN::Page -> new( "Delete Post", "Lukas");
my $dbh = CXGN::DB::Connection->new();
#
# check if there is a valid login going on
#
my $user_id = CXGN::Login->new($dbh)->verify_session();
#
# get the page arguments
#
=head2 Page Arguments

topic_id: The id of the topic the post to be deleted belongs to.
post_id: The id of the post to be deleted.
confirm: a boolean that will ask for confirmation before deleting.
refering page: The page that called this script, so that we can 
  provide a link back to that page. This will no always be equal to the REFERER that
  one can obtain from the Apache object! 

=cut
#
my ($post_id, $confirm, $refering_page, $topic_id) = $page -> get_arguments("post_id", "confirm", "refering_page", "topic_id");

my $sp_person_id = "";

my $post_person_id = undef;
my $post_text = undef;
my $post; 
if ($post_id) { 

    $post = CXGN::People::Forum::Post -> new($dbh, $post_id);
    my $user = CXGN::People::Person->new($dbh, $user_id);

    $post_person_id = $post -> get_person_id();
    
    $post_text = $post -> get_post_text();

    my $post_person = CXGN::People::Person -> new($dbh, $post_person_id);
    my $sp_person_id = $post_person -> get_sp_person_id();
    my $post_person_last_name = $post_person -> get_last_name();
    my $post_person_first_name = $post_person -> get_first_name();

    if (!$post) { 
	$page->header();
	print "<h4>No such post</h4>\n<br />
               The post you are trying to delete does not exist. 
               It may have been deleted previously or never existed.
               <br /><br /><br /><br />\n";
	$page->footer();
	
    }
    elsif (($sp_person_id && ($user_id == $sp_person_id)) || $user->get_user_type() eq "curator") { 
	if (!$confirm) { 
	    $page->header();
	    
	    print <<HTML;
	    <div class="container-fluid">
	    <h4>Confirm user comment delete</h4>
		Comment \# $post_id from user <b>$post_person_first_name $post_person_last_name</b><br /><br />
	      Are you sure you want to delete this post? <br /><br />

	      <div class="panel panel-primary"><div class="panel-body">$post_text</div></div>
	      
	      <br />
	      <form action="forum_post_delete.pl">
	      <input type="hidden" name="confirm" value="1" />
	      <input type="hidden" name="post_id" value="$post_id" />
	      <input type="hidden" name="refering_page" value="$refering_page" />
	      <input type="hidden" name="topic_id" value="$topic_id" />
	      <input class="btn btn-primary" type="submit" value="Delete" /><br /><br />
	      <a href="$refering_page">Go back</a>
	      </form>
	     </div> 
HTML

;	      
	    $page->footer();
	}
	else { 
	    my $rows = $post->delete();
	    
	    if ($rows == 1) { 
		$page->header();
		print "<h4>Your post has been deleted.</h4>\n<br /><br /><br />";

		print "<a href=\"$refering_page\">Go back to user comments on the detail page.</a><br /><br />\n";
		$page->footer();
	    }
	    else { 
		$page->header();
		print "<h4>ERROR</h4><h4>An error occurred during deletion. The post_id supplied may be invalid.</h4>";
		$page->footer();
		
	    }
	    
	}
    }
    else { 
	$page ->header();
	print "<h4>POST CAN'T BE DELETED!</h4>\n";
	print "<h4>Either this post_id does not exist anymore or you are not the owner of post $post_id. Only the posters can delete their own posts. Sorry!</h4>\n";
	print "<br /><br /><a href=\"$refering_page\">Return to user comments.</a><br /><br />\n";


	$page->footer();
    }
    
}
else {
    $page->header();
    print "<h4>No post id was supplied. Nothing was deleted.</h4>\n";
    $page->footer();
}

