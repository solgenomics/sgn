

use strict;
use Test::More tests => 2;
use SGN::Test::WWW::Mechanize;
use lib 't/lib';
#use SGN::Test;


my $base_url = $ENV{SGN_TEST_SERVER};

{
	my $mech = SGN::Test::WWW::Mechanize->new;
	$mech->get_ok("$base_url/phenome/correlation_download.pl?population_id=12", ); 
    	is( $mech->content_type, 'text/plain', 'got the right content type from the correlation download');
}
