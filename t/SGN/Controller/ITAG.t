use strict;
use warnings;
use Test::More;
use Data::Dumper;

use lib 't/lib';

use HTTP::Status ':constants';

BEGIN {
    $ENV{SGN_SKIP_CGI} = 1;
    use_ok 'SGN::Test::WWW::Mechanize';
    use_ok 'SGN::Controller::ITAG';
}

my $mech = SGN::Test::WWW::Mechanize->new;

# list ITAG releases
$mech->get_ok( '/itag/list_releases' );
my $release_link = $mech->find_link( url_regex => qr!^/itag/release/\d! );
SKIP: {
  skip 'no ITAG bulk file releases found, skipping remaining tests', 2 unless $release_link;

  $mech->get_ok( $release_link->url, 'click on file listing for the first available ITAG release' );

  my @file_links = grep $_->attrs->{onclick} =~ /show_download_form/, $mech->find_all_links( url => '' );

  cmp_ok( $#file_links, '>', 5, 'got at least 5 file links for itag release '.$release_link->text );

}

done_testing;
