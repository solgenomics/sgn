=head1 NAME

t/integration/search.t - integration tests for generic search URLs

=head1 DESCRIPTION

Tests for search URLs

=head1 SYNOPSIS


=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use Modern::Perl;
use Test::Most;

BEGIN { $ENV{SGN_SKIP_CGI} = 1 }
use lib 't/lib';
use SGN::Test::Data qw/ create_test /;
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;

my @search_types = qw/locus unigene feature family marker bac est insitu directory images glossary/;

$mech->get_ok("/search");
$mech->content_like(qr/Search/);

for my $type (@search_types) {
    $mech->get_ok("/search/$type");
    $mech->content_like(qr/Search SGN/);
}

done_testing;
