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


SKIP: {
    my $release_link = $mech->find_link( url_regex => qr!^/itag/release/\d! );

    skip 'no ITAG release link found', 1 unless $release_link;

    $mech->get_ok( $release_link->url, 'click on file listing for the first available ITAG release' );

    my @all_links  = $mech->find_all_links( url => '' );

    skip 'no ITAG bulk file releases found, skipping remaining tests', 2 unless @all_links;

    ok(@all_links, 'found some links on ' . $release_link->text);

    diag(Dumper(@all_links));

    my @file_links = grep $_->attrs->{onclick} =~ /show_download_form/, @all_links;

    cmp_ok( @file_links, '>', 5, 'got at least 5 file links for itag release '. $release_link->text );

}

done_testing;
