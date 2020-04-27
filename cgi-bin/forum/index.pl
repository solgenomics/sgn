use strict;
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('About The SOL Forum');
print<<END_HEREDOC;

<center>
    

  <table summary="" width="720" cellpadding="0" cellspacing="0"
  border="0">
    <tr>
      <td>
        <center>
          <h3>SOL Forum</h3>
        </center>
     
      <h4>What it is</h4>
      <p>The SOL Forum is an interactive message board for <a href="/">Sol Genomics Network</a> registered users. Registered users can be found in the <a href="/search/direct_search.pl?search=directory">SGN people directory database</a>. Before you <a href="/solpeople/new-account.pl">register</a>, please check if you are <a href="/search/direct_search.pl?search=directory">already in the database</a>. 
      </p>
      <p>
      In addition to the messageboard, there is also a <a href="http://rubisco.sgn.cornell.edu/mailman/listinfo/sol-forum">SOL Forum mailing list</a> for communication between mailing list subscribers. Messages posted on the mailing list do not appear on the message boards and are only received by subscribers of the mailing list. Only list members can post to the list to prevent spam from appearing on the list.
      </p>
      <h4>How to use it</h4>
      <p>
      You can <a href="topics.pl">browse</a> the message board by topic. If you want to create new discussion topics or post messages, you need to <a href="/user/login">log in</a>.
      </p>
      
      <h4>Topics</h4>
      <div class="boxbgcolor5"><b>Please note</b> <ul><li>This service is provided by SGN as a courtesy. SGN reserves the right to remove topics and posts for any reason at any time.</li>
      <li>This service is experimental and may be modified or removed at any time without notice.</li>
      </ul>
      </div>
      
<br />
      Forum topics: 
      <ul>
      <li><a href="posts.pl?topic_id=2">Job Postings</a></li>

      <li><a href="topics.pl">Complete list of topics</a></li>
      </ul>

      </td>
    </tr>
  </table><!-- begin footer include -->
  
  <!-- end footer include -->
</center>
END_HEREDOC
$page->footer();
