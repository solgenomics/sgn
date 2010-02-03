use strict;
use CXGN::Page;
my $page=CXGN::Page->new("Scheduled outage","Marty");
$page->header();
print <<END_HEREDOC;

<div>
  <h1>Scheduled service downtime for SGN and related projects</h1>

  <p>
    We are moving our servers to a new room during the week of April
    3, 2006.  The following services will be unavailable from
    Wednesday April 5, 2006 to Friday, April 7, 2006:
</p>

    <ul>
      <li>ftp downloads</li>
      <li>BAC submissions</li>
      <li>website login</li>
      <li>EST uploads      </li>
      <li>mailing lists (sgn-feedback and others)</li>
    </ul>

<p>
    Additionally, our websites (sgn.cornell.edu, pgn.cornell.edu),
    may be unavailable for short periods during these days.
  </p>

  <p>
    In case our schedule should change, we will update this page to
    reflect our modified plans.  Please check here for further
    announcements.
  </p>

    <h4>Photos from the server move</h4>
    <a href="/static_content/sgn_photos/server_move_2006/P1010103.jpg"><img src="/static_content/sgn_photos/server_move_2006/thumbs/P1010103.jpg" style="margin: 2px; float: left;" alt="" /></a>

    <a href="/static_content/sgn_photos/server_move_2006/P1010112.jpg"><img src="/static_content/sgn_photos/server_move_2006/thumbs/P1010112.jpg" style="margin: 2px; float: left;" alt="" /></a>

    <a href="/static_content/sgn_photos/server_move_2006/P1010115.jpg"><img src="/static_content/sgn_photos/server_move_2006/thumbs/P1010115.jpg" style="margin: 2px; float: left;" alt="" /></a>

    <a href="/static_content/sgn_photos/server_move_2006/P1010118.jpg"><img src="/static_content/sgn_photos/server_move_2006/thumbs/P1010118.jpg" style="margin: 2px; float: left;" alt="" /></a>

    <a href="/static_content/sgn_photos/server_move_2006/P1010129.jpg"><img src="/static_content/sgn_photos/server_move_2006/thumbs/P1010129.jpg" style="margin: 2px; float: left;" alt="" /></a>

    <a href="/static_content/sgn_photos/server_move_2006/P1010131.jpg"><img src="/static_content/sgn_photos/server_move_2006/thumbs/P1010131.jpg" style="margin: 2px; float: left;" alt="" /></a>

    <a href="/static_content/sgn_photos/server_move_2006/P1010132.jpg"><img src="/static_content/sgn_photos/server_move_2006/thumbs/P1010132.jpg" style="margin: 2px; float: left;" alt="" /></a>

    <a href="/static_content/sgn_photos/server_move_2006/P1010134.jpg"><img src="/static_content/sgn_photos/server_move_2006/thumbs/P1010134.jpg" style="margin: 2px; float: left;" alt="" /></a>

    <a href="/static_content/sgn_photos/server_move_2006/P1010135.jpg"><img src="/static_content/sgn_photos/server_move_2006/thumbs/P1010135.jpg" style="margin: 2px; float: left;" alt="" /></a>


</div>

END_HEREDOC


$page->footer();
