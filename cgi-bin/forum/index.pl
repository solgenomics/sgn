use strict;
use SGN::I18N ();
use CatalystX::GlobalContext '$c';
my SGN::I18N $ui_forum_i18n = SGN::I18N::translate($c);
my %ui_forum = (
    'community.forum.about_intro' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.about_intro', 'The SOL Forum is an interactive message board for', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.about_registered_users' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.about_registered_users', 'registered users. Registered users can be found in the', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.about_title' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.about_title', 'About The', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.already_in_database' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.already_in_database', 'already in the database', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.before_register' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.before_register', 'Before you', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.board_by_topic' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.board_by_topic', 'the message board by topic. If you want to create new discussion topics or post messages, you need to', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.browse' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.browse', 'browse', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.browse_intro' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.browse_intro', 'You can', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.check_directory' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.check_directory', 'please check if you are', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.complete_topic_list' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.complete_topic_list', 'Complete list of topics', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.courtesy_notice' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.courtesy_notice', 'This service is provided by SGN as a courtesy. SGN reserves the right to remove topics and posts for any reason at any time.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.experimental_notice' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.experimental_notice', 'This service is experimental and may be modified or removed at any time without notice.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.forum_topics_label' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.forum_topics_label', 'Forum topics:', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.how_to_use' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.how_to_use', 'How to use it', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.log_in' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.log_in', 'log in', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.mail_list_explanation' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.mail_list_explanation', 'for communication between mailing list subscribers. Messages posted on the mailing list do not appear on the message boards and are only received by subscribers of the mailing list. Only list members can post to the list to prevent spam from appearing on the list.', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.mail_list_intro' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.mail_list_intro', 'In addition to the messageboard, there is also a', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.people_directory' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.people_directory', 'SGN people directory database', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.please_note' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.please_note', 'Please note', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.register' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.register', 'register', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.topics_heading' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.topics_heading', 'Topics', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 }),
    'community.forum.what_it_is' => SGN::I18N::translate($ui_forum_i18n, 'community.forum.what_it_is', 'What it is', undef, { entities => '<>&\x{0080}-\x{10FFFF}', decode => 0 })
);
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header($ui_forum{'community.forum.about_title'} . " SOL Forum");
print<<END_HEREDOC;

<center>
    

  <table summary="" width="720" cellpadding="0" cellspacing="0"
  border="0">
    <tr>
      <td>
        <center>
          <h3>SOL Forum</h3>
        </center>
     
      <h4>@{[$ui_forum{'community.forum.what_it_is'}]}</h4>
      <p>@{[$ui_forum{'community.forum.about_intro'}]} <a href="/">Sol Genomics Network</a> @{[$ui_forum{'community.forum.about_registered_users'}]} <a href="/search/direct_search.pl?search=directory">@{[$ui_forum{'community.forum.people_directory'}]}</a>. @{[$ui_forum{'community.forum.before_register'}]} <a href="/solpeople/new-account.pl">@{[$ui_forum{'community.forum.register'}]}</a>, @{[$ui_forum{'community.forum.check_directory'}]} <a href="/search/direct_search.pl?search=directory">@{[$ui_forum{'community.forum.already_in_database'}]}</a>.\x20
      </p>
      <p>
      @{[$ui_forum{'community.forum.mail_list_intro'}]} <a href="http://rubisco.sgn.cornell.edu/mailman/listinfo/sol-forum">SOL Forum mailing list</a> @{[$ui_forum{'community.forum.mail_list_explanation'}]}
      </p>
      <h4>@{[$ui_forum{'community.forum.how_to_use'}]}</h4>
      <p>
      @{[$ui_forum{'community.forum.browse_intro'}]} <a href="topics.pl">@{[$ui_forum{'community.forum.browse'}]}</a> @{[$ui_forum{'community.forum.board_by_topic'}]} <a href="/user/login">@{[$ui_forum{'community.forum.log_in'}]}</a>.
      </p>
      
      <h4>@{[$ui_forum{'community.forum.topics_heading'}]}</h4>
      <div class="boxbgcolor5"><b>@{[$ui_forum{'community.forum.please_note'}]}</b> <ul><li>@{[$ui_forum{'community.forum.courtesy_notice'}]}</li>
      <li>@{[$ui_forum{'community.forum.experimental_notice'}]}</li>
      </ul>
      </div>
      
<br />
      @{[$ui_forum{'community.forum.forum_topics_label'}]}\x20
      <ul>
      <li><a href="posts.pl?topic_id=2">Job Postings</a></li>

      <li><a href="topics.pl">@{[$ui_forum{'community.forum.complete_topic_list'}]}</a></li>
      </ul>

      </td>
    </tr>
  </table><!-- begin footer include -->
  
  <!-- end footer include -->
</center>
END_HEREDOC
$page->footer();
