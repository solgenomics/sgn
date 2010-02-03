
use strict;

use JSON;
use CXGN::DB::Connection;
use CXGN::Sunshine::Browser;

my $dbh = CXGN::DB::Connection->new();

my $b = CXGN::Sunshine::Browser->new($dbh);

#my $json = JSON->new();

my $r = $b->get_relationship_menu_info();

#print STDERR "GOT THE FOLLOWING RESPONSE: $r\n";
print "Content-Type: text/plain\n\n";
print "$r\n";




