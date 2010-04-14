

use strict;
use warnings;

use File::Spec;
use Test::More qw | no_plan |;
use Test::WWW::Mechanize;
use CXGN::DB::Connection;
use CXGN::Page;

my $mech = Test::WWW::Mechanize->new;
my $server = $ENV{SGN_TEST_SERVER}|| "http://sgn-devel.sgn.cornell.edu";

diag "Using server $ENV{SGN_TEST_SERVER}\n";

my $new_page = $server."/search/markers/snp.pl";
$mech->get_ok($new_page);


#$mech->content_contains("SNP database");







=head
 my $mech = Test::WWW::Mechanize->new;
           $mech->get_ok( 'http://petdance.com/' );
           $mech->base_is( 'http://petdance.com/' );
           $mech->title_is( "Invoice Status" );
           $mech->content_contains( "Andy Lester" );
           $mech->content_like( qr/(cpan|perl)\.org/ 

=cut
 

