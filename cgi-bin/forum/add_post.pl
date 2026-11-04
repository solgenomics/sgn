
=head1 add_post.pl

add_post.pl adds posts to topics or comments to webpages. 

For the former, add_post.pl takes a topic_id parameter. For the latter, add_post takes two parameters, page_type and page_object_id. If not parameter is specified, add_post.pl shows an error message. If all three parameters are specified, the topic_id overrides the other two.

If no post_text is supplied, add_post.pl displays an input mask. Otherwise it processes the entry and tries to add post_text to the database, with the logged in user as the submitter and the topic id as specified above.

A refering_page parameter can be used to generate a link back to the calling page.

=cut
    
use strict;
use SGN::I18N ();
use CatalystX::GlobalContext '$c';
my SGN::I18N $ui_forum_i18n = SGN::I18N::translate($c);
my %ui_forum = (
    'community.forum.post_truncated_edit_hint' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.post_truncated_edit_hint', 'Please use the \'go back\' button to edit your post, or submit to accept the', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.store_post' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.store_post', 'Store post', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.truncated_version' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.truncated_version', 'truncated version.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'global.safe_caption.note' => SGN::I18N::translate($ui_forum_i18n, 'global.safe_caption.note', 'Note:', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.add_post' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.add_post', 'Add Post', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.back_to_posts' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.back_to_posts', 'Back to posts', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.courtesy_notice_lower' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.courtesy_notice_lower', 'this service is provided as a courtesy. SGN reserves the right to delete posts at any time for any reason.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.enter_comment_help' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.enter_comment_help', 'Please enter your comment below. You can delete the post later if you are logged in.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.enter_post' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.enter_post', 'Enter post', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.example_link_explanation' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.example_link_explanation', 'will appear as', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.insufficient_post_data' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.insufficient_post_data', 'Sorry, but there was insufficient data to add this post.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.modify_post' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.modify_post', 'modify post', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.parent_message_prefix' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.parent_message_prefix', 'Your message will be attached to the following message:', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.post_html_links_help' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.post_html_links_help', 'HTML tags are not supported. You can add links to your post by using square brackets.  For example:', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.post_review_explanation' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.post_review_explanation', 'This is how the text of your post will appear. Please use the \'store post\' button for permanently adding the post
    or the \'modify post\' button to go back and revise the post. To cancel, click on \'back to posts\'.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.post_stored_title' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.post_stored_title', 'Your post was successfully stored', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.post_text_label' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.post_text_label', 'Post Text:', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.review_post' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.review_post', 'Review post', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.review_post_title' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.review_post_title', 'Review your post', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.steps_label' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.steps_label', 'Steps:', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.store_post_lower' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.store_post_lower', 'store post', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 })
);

use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::People;
use CXGN::People::Forum;
use CXGN::People::Person;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                     blue_section_html  /;

my $SIZELIMIT = 10000; # the maximal number of bytes in a post.

my $page = CXGN::Page->new( "SGN Forum | " . $ui_forum{'community.forum.add_post'}, "Lukas");
my $dbh = CXGN::DB::Connection->new();

#
# get information about the poster
#
my ( $person, $name, $sp_person_id ) = do {
    # to enable anonymous comments, change the verify_session to has_session
    if( my $sp_person_id = CXGN::Login->new($dbh)->verify_session ) {
        my $person = CXGN::People::Person -> new($dbh, $sp_person_id);
        my $name = $person->get_first_name()." ".$person->get_last_name();
        $sp_person_id = $person -> get_sp_person_id();
        ( $person, $name, $sp_person_id )
    } else {
        ( (undef) x 3 )
    }
};


my ($subject, $post_text, $parent_post_id, $topic_id, $page_type, $page_object_id, $refering_page, $action) = $page -> get_encoded_arguments("subject", "post_text", "parent_post_id", "topic_id", "page_type", "page_object_id", "refering_page", "action");

# we define 3 actions: 
# 1) input
# 2) review
# 3) save
# all other values for the action parameter will show the input as default.


my $parent_post = "";
my $parent_subject = "";
my $display_subject = "";
my $parent_post_text = "";
my $parent_post_explain = "";
my $topic;
my $topic_name = "";
my $subject_input = ""; 
#
# if a topic_id is supplied, simply add the post to the given topic id.
#
if ($topic_id) { 
    $parent_post = CXGN::People::Forum::Post -> new($dbh, $parent_post_id);
    $parent_subject = $parent_post->get_subject();
    $parent_post_text = $parent_post->get_post_text();
    $parent_post_explain = "";
    $display_subject = "RE: $parent_subject";
    if ($parent_post_text) { 
	$parent_post_explain = $ui_forum{'community.forum.parent_message_prefix'} . " \n\t<table summary=\"\" class=\"sgnblue\"><tr><td><pre>$parent_post_text</pre></td></tr></table>\n\t<br />";
	$subject_input = "<input type=\"text\" name=\"subject\" value=\"$display_subject\" /><br /><br /> ";
    }

    $topic = CXGN::People::Forum::Topic -> new($dbh, $topic_id);
    if (!$topic) { 
	$page->error_page(SGN::I18N::translate($ui_forum_i18n, 'community.forum.invalid_topic_id', 'No legal topic id was supplied. [topic_id=%{topic_id}]', { 'topic_id' => "$topic_id" }, { entities => '' }));
    }
    $topic_name =  $topic -> get_topic_name();
}
#
# if the page_type and page_object_id are supplied, it is a page comment. Get the 
# topic id for that page and id.
#
elsif ($page_type && $page_object_id) { 
    $topic = CXGN::People::Forum::Topic->new_page_comment($dbh, $page_type, $page_object_id);
    if (!$topic->get_topic_name()) { 
	$topic->set_topic_name($page_type." ".$page_object_id); 
	$topic->set_person_id($sp_person_id);

    }
    $topic_name = "$page_type id: $page_object_id";
}
else
{
    $page->error_page($ui_forum{'community.forum.insufficient_post_data'});
}

#
# create a post object to work from
#
my $post = CXGN::People::Forum::Post->new($dbh);
$post->set_subject($subject);
$post->set_person_id($sp_person_id);
$post->set_parent_post_id($parent_post_id);
$post->set_forum_topic_id($topic_id);
my $formatted_post_text = $post->format_post_text($post_text);

# 
# create $link with a link back to the original posting page
# (this can be a detail page or it can be a topic_id specific posts.pl page
#
my $link;
if ($refering_page) { 
    $link = "<a href=\"$refering_page\">@{[$ui_forum{'community.forum.back_to_posts'}]}</a>";
}
else { 
    $link = "<a href=\"posts.pl?topic_id=$topic_id\">@{[$ui_forum{'community.forum.back_to_posts'}]}</a>";
}
#
# perform the appropriate action, depending on the
# action parameter
#
if ($action eq "review") {    

    my $truncated = 0;
    my $display_post_text = "";
    if (length($post_text)>$SIZELIMIT) { 
	$display_post_text = substr($post_text, 0, $SIZELIMIT);
	$truncated = 1;
    }
    else { 
	$display_post_text = $post_text; 
    }
    
    my $truncated_warning = "";
    if ($truncated) { 
	$truncated_warning = "<b>" . $ui_forum{'global.safe_caption.note'} . "</b> " . SGN::I18N::translate($ui_forum_i18n, 'community.forum.post_exceeds_limit', 'Your post exceeds %{limit} characters and has been truncated.', { 'limit' => "$SIZELIMIT" }, { entities => '' }) . "\n                " . $ui_forum{'community.forum.post_truncated_edit_hint'} . " \n                " . $ui_forum{'community.forum.truncated_version'} . "<br /><br />\n";
    }


    $page -> header();

    print page_title_html($ui_forum{'community.forum.review_post_title'});
    
    print <<HTML;
    <div class="container-fluid">
    @{[$ui_forum{'community.forum.enter_post'}]} -> <b>@{[$ui_forum{'community.forum.review_post'}]}</b> -> @{[$ui_forum{'community.forum.store_post'}]}<br /><br />
    @{[$ui_forum{'community.forum.post_review_explanation'}]}<br /><br />
 
    $truncated_warning

    <div class="panel panel-primary"><div class="panel-body">$formatted_post_text</div></div>

    <br /><br />

    <table width="100%"><tr><td align="left">
    <form action="add_post.pl" method="post">
    <input type="hidden" name="post_text" value="$post_text" />
    <input type="hidden" name="page_type" value="$page_type" />
    <input type="hidden" name="page_object_id" value="$page_object_id" />
    <input type="hidden" name="refering_page" value="$refering_page" />
    <input type="hidden" name="action" value="input" />
    <input type="hidden" name="topic_id" value="$topic_id" />
    <input class="btn btn-info" type="submit" value="@{[$ui_forum{'community.forum.modify_post'}]}" />
    </form>
    <td><td>
    $link
    </td><td align="right">
    <form action="add_post.pl" method="post">
    <input type="hidden" name="post_text" value="$post_text" />
    <input type="hidden" name="page_type" value="$page_type" />
    <input type="hidden" name="page_object_id" value="$page_object_id" />
    <input type="hidden" name="refering_page" value="$refering_page" />
    <input type="hidden" name="action" value="save" />
    <input type="hidden" name="topic_id" value="$topic_id" />
    <input class="btn btn-primary" type="submit" value="@{[$ui_forum{'community.forum.store_post_lower'}]}" />
    </form>
    </td></tr></table>
    </div>
HTML

    $page -> footer();
}

elsif ($action eq "save") {
    #
    # save the object if action is "save"
    #
    $topic->set_page_type($page_type);
    $topic->set_page_object_id($page_object_id);
    $topic->store();

    $topic_id = $topic->get_forum_topic_id();
    $post->set_forum_topic_id($topic_id);

    my $truncated = 0;
    if (length($post_text)>$SIZELIMIT) { 
	$post_text = substr($post_text, 0, $SIZELIMIT);
	$truncated = 1;
    }

    $post->set_post_text($post_text);
    $post->store();

    $page->header();

    print page_title_html($ui_forum{'community.forum.post_stored_title'});
    print "@{[$ui_forum{'community.forum.enter_post'}]} -> @{[$ui_forum{'community.forum.review_post'}]} -> <b>@{[$ui_forum{'community.forum.store_post'}]}</b></a><br /><br />\n";

    if ($truncated) { 
	print "<b>" . $ui_forum{'global.safe_caption.note'} . "</b>" . SGN::I18N::translate($ui_forum_i18n, 'community.forum.post_truncated_notice', 'Your post has been truncated to %{limit} characters.', { 'limit' => "$SIZELIMIT" }, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }) . "<br />\n";
    }

    my $display_post_text = $post->format_post_text($post_text);
    #print "submitter: $sp_person_id topic: $topic_id, $page_type, $page_object_id. text:<br /><br />";
    print "<div class=\"panel panel-primary\" ><div class=\"panel-body\">$display_post_text</div></div>";
    print "<br /><br /><br />\n";
    
 
    print "$link<br /><br /><br />\n";

    $page->footer();

}

else { 
    #
    # the action is "input" or anything else. 
    #
    $page -> header();

    print page_title_html(SGN::I18N::translate($ui_forum_i18n, 'community.forum.enter_post_for_topic', 'Enter Post for topic "%{topic_name}"', { 'topic_name' => "$topic_name" }, { entities => '' }));

    my $ui_post_size_limit = SGN::I18N::translate($ui_forum_i18n, 'community.forum.post_size_limit', 'Size limit per post is %{limit} characters, including spaces and punctuation.', { 'limit' => "$SIZELIMIT" }, { entities => '' });

print <<HTML;

    <form method="post" action="add_post.pl">
	
	@{[$ui_forum{'community.forum.steps_label'}]} <b>@{[$ui_forum{'community.forum.enter_post'}]}</b> -> @{[$ui_forum{'community.forum.review_post'}]} -> @{[$ui_forum{'community.forum.store_post'}]}<br /><br />\x20
	$parent_post_explain<br />
	
	@{[$ui_forum{'community.forum.enter_comment_help'}]}<br />
	@{[$ui_forum{'community.forum.post_html_links_help'}]}<br />
	<tt>[url]sgn.cornell.edu[/url]</tt> @{[$ui_forum{'community.forum.example_link_explanation'}]} <a href="http://sgn.cornell.edu">sgn.cornell.edu</a> in the post.<br /><br />

	$ui_post_size_limit<br /><br />
	<b>Note:</b> @{[$ui_forum{'community.forum.courtesy_notice_lower'}]}
	<br /><br />
	<input type="hidden" name="parent_post_id" value="$parent_post_id" />
	<input type="hidden" name="topic_id" value="$topic_id" />
	<input type="hidden" name="page_type" value="$page_type" />
	<input type="hidden" name="page_object_id" value="$page_object_id" />
	<input type="hidden" name="refering_page" value="$refering_page" />
	<input type="hidden" name="action" value="review" />
	$subject_input

	@{[$ui_forum{'community.forum.post_text_label'}]}<br />
	<textarea class="form-control" rows="12" cols="80" name="post_text">$post_text</textarea>
	<br /><br />

	<table width="100%"><tr><td align="left">
	$link 
	</td><td align="right">
	<input class="btn btn-primary" type=submit value="@{[$ui_forum{'community.forum.review_post'}]}" />
	</form>
	</td></tr></table>

	<br />
	
      
      <br />
      <br />

HTML

      $page->footer();

}





