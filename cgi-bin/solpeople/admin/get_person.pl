use strict;
use CXGN::Page;
use CXGN::DB::Connection;

my $page = CXGN::Page->new("","johnathon");
my ($id) = $page->get_encoded_arguments("id");
print "Content-Type: text/html \n\n";
my $dbh = CXGN::DB::Connection->new("sgn_people");
my $sth = $dbh->prepare("select username, last_access_time from sp_person where sp_person_id = ?");
die "Id is not integer." unless $id > 0;
$sth->execute("$id");
my ($name, $time) = $sth->fetchrow_array();
print "<tr><td>$name</td><td>$time</tr>"
  
