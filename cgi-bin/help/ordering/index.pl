use strict;
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('SGN: Ordering Clones');
print<<END_HEREDOC;

  <center>
    

    <table summary="" width="720" cellpadding="0" cellspacing="0"
    border="0">
      <tr>
        <td>
          <h4>Ordering Clones</h4>

          <div class="boxcontent">
            <dl>
              <dt><strong>Tomato</strong></dt>

              <dd><a href=
              "http://ted.bti.cornell.edu/cgi-bin/TFGD/order/home.cgi">Purchase tomato
              EST or BAC clones</a> from <a href=
              "http://ted.bti.cornell.edu/">TED BTI</a> at Cornell
              University.</dd>

              <dt><br /><strong>Potato</strong></dt>

              <dd><a href=
              "http://www.genome.arizona.edu/orders/">Purchase
              potato clones</a> from <a href=
              "http://www.genome.arizona.edu/">Arizona Genome
              Initiative</a>.</dd>

              <dt><br /><strong>Pepper</strong></dt>

              <dd>For pepper clones, contact <a href=
              "/solpeople/personal-info.pl?sp_person_id=87">
              Doil Choi</a> at KRIBB Korea.</dd>
            </dl>
          </div>
        </td>
      </tr>
    </table>
    
  </center>
END_HEREDOC
$page->footer();
