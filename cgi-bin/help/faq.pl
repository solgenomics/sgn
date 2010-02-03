use strict;
use CXGN::Page;
my $page=CXGN::Page->new('faq.html','html2pl converter');
$page->header('SGN: Frequently Asked Questions (FAQ)');
print<<END_HEREDOC;

  <center>
    
  <table summary="" width="720" cellpadding="0" cellspacing="0"
  border="0">
    <tr>
      <td>
        <center>
          <table summary="" width="720" cellpadding="0"
          cellspacing="0" border="0">
            <tr>
              <td>
                <h3>Frequently Asked Questions (FAQ)</h3>On this
                page, we collect frequently asked questions that
                are useful to a large number of users. Please
                <a href="mailto:sgn-feedback\@sgn.cornell.edu">let
                us know</a> if you have a question that you think
                should be added.

                <p><strong>Question:</strong> Where can I order clones?<br />
                <strong>Answer:</strong> This depends on the species and on
                the specific library. For tomato clones, you can
                use the clone ordering facility at the <a href=
                "http://ted.bti.cornell.edu/order/">Boyce Thompson
                Institute</a>. For potato clones that were
                sequenced as part of the U.S. potato genome
                project, the ordering is handled by the <a href=
                "http://genome.arizona.edu/orders/">Arizona Genome
                Institute</a>. For all other libraries, please
                contact the library submitters given on the library
                detail pages (use the <a href=
                "/search/direct_search.pl?search=ESTs">Library
                Search</a> page to find the library in
                question).</p>

                <p><strong>Question:</strong> The SGN pages look really
                messed up on my browser.<br />
                <strong>Answer:</strong> You are working with an old browser
                that does not support style sheets, such as the
                browsers of the Netscape 4.x series. SGN pages
                require style sheets and javascript to be turned
                on.</p>

                <p><strong>Question:</strong> Can I submit my data to
                SGN?<br />
                <strong>Answer:</strong> Please send an email to <a href=
                "mailto:sgn-feedback\@sgn.cornell.edu">sgn-feedback\@sgn.cornell.edu</a>
                with a description of the data you would like to
                submit. We will then work with you to integrate
                your data into the database and/or add it to the
                FTP server.<br />
                <br />
                <br /></p>
              </td>
            </tr>
          </table>
          
        </center>
      </td>
    </tr>
  </table>
</center>
END_HEREDOC
$page->footer();