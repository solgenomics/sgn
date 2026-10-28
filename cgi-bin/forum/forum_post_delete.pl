#
# deletes a forum post
#
# Lukas Mueller, April 6, 2005
#

use strict;
use SGN::I18N ();
use CatalystX::GlobalContext '$c';
my SGN::I18N $ui_forum_i18n = SGN::I18N::translate($c);
my %ui_forum = (
    'community.forum.delete_error_suffix' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.delete_error_suffix', 'supplied may be invalid.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.back_to_user_comments' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.back_to_user_comments', 'Go back to user comments on the detail page.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.comment_label' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.comment_label', 'Comment', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.confirm_comment_delete' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.confirm_comment_delete', 'Confirm user comment delete', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.confirm_delete_post' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.confirm_delete_post', 'Are you sure you want to delete this post?', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.delete_error_prefix' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.delete_error_prefix', 'An error occurred during deletion. The', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.delete_post_title' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.delete_post_title', 'Delete Post', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.error_heading' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.error_heading', 'ERROR', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.from_user' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.from_user', 'from user', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.go_back' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.go_back', 'Go back', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.no_post_supplied' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.no_post_supplied', 'No post id was supplied. Nothing was deleted.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.no_such_post' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.no_such_post', 'No such post', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.post_cannot_be_deleted' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.post_cannot_be_deleted', 'POST CAN\'T BE DELETED!', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.post_deleted' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.post_deleted', 'Your post has been deleted.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.post_deleted_previously' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.post_deleted_previously', 'It may have been deleted previously or never existed.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.post_does_not_exist_short' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.post_does_not_exist_short', 'The post you are trying to delete does not exist.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.return_to_user_comments' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.return_to_user_comments', 'Return to user comments.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'lists.render.action.delete' => SGN::I18N::translate($ui_forum_i18n, 'lists.render.action.delete', 'Delete', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 })
);
use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Login;
use CXGN::People::Forum;
use CXGN::People;

#
# create a page object
#
my $page = CXGN::Page -> new( $ui_forum{'community.forum.delete_post_title'}, "Lukas");
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
referring page: The page that called this script, so that we can
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
	print "<h4>@{[$ui_forum{'community.forum.no_such_post'}]}</h4>\n<br />
               @{[$ui_forum{'community.forum.post_does_not_exist_short'}]}
               @{[$ui_forum{'community.forum.post_deleted_previously'}]}
               <br /><br /><br /><br />\n";
	$page->footer();
	
    }
    elsif (($sp_person_id && ($user_id == $sp_person_id)) || $user->get_user_type() eq "curator") { 
	if (!$confirm) { 
	    $page->header();
	    
	    print <<HTML;
	    <div class="container-fluid">
	    <h4>@{[$ui_forum{'community.forum.confirm_comment_delete'}]}</h4>
		@{[$ui_forum{'community.forum.comment_label'}]} \# $post_id @{[$ui_forum{'community.forum.from_user'}]} <b>$post_person_first_name $post_person_last_name</b><br /><br />
	      @{[$ui_forum{'community.forum.confirm_delete_post'}]} <br /><br />

	      <div class="panel panel-primary"><div class="panel-body">$post_text</div></div>
	      
	      <br />
	      <form action="forum_post_delete.pl">
	      <input type="hidden" name="confirm" value="1" />
	      <input type="hidden" name="post_id" value="$post_id" />
	      <input type="hidden" name="refering_page" value="$refering_page" />
	      <input type="hidden" name="topic_id" value="$topic_id" />
	      <input class="btn btn-primary" type="submit" value="@{[$ui_forum{'lists.render.action.delete'}]}" /><br /><br />
	      <a href="$refering_page">@{[$ui_forum{'community.forum.go_back'}]}</a>
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
		print "<h4>@{[$ui_forum{'community.forum.post_deleted'}]}</h4>\n<br /><br /><br />";

		print "<a href=\"$refering_page\">@{[$ui_forum{'community.forum.back_to_user_comments'}]}</a><br /><br />\n";
		$page->footer();
	    }
	    else { 
		$page->header();
		print "<h4>@{[$ui_forum{'community.forum.error_heading'}]}</h4><h4>@{[$ui_forum{'community.forum.delete_error_prefix'}]} post_id @{[$ui_forum{'community.forum.delete_error_suffix'}]}</h4>";
		$page->footer();
		
	    }
	    
	}
    }
    else { 
	$page ->header();
	print "<h4>@{[$ui_forum{'community.forum.post_cannot_be_deleted'}]}</h4>\n";
	print "<h4>" . SGN::I18N::translate($ui_forum_i18n, 'community.forum.post_not_found_or_not_owner', 'Either this post_id does not exist anymore or you are not the owner of post %{post_id}. Only the posters can delete their own posts. Sorry!', { 'post_id' => "$post_id" }, { entities => '' }) . "</h4>\n";
	print "<br /><br /><a href=\"$refering_page\">@{[$ui_forum{'community.forum.return_to_user_comments'}]}</a><br /><br />\n";


	$page->footer();
    }
    
}
else {
    $page->header();
    print "<h4>@{[$ui_forum{'community.forum.no_post_supplied'}]}</h4>\n";
    $page->footer();
}

