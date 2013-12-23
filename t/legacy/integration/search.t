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

use lib 't/lib';
use SGN::Test::Data qw/ create_test /;
use SGN::Test::WWW::Mechanize skip_cgi => 1;

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get_ok("/search/organisms");
$mech->content_like(qr!Organism/Taxon search!);

$mech->get_ok("/search");
$mech->content_like(qr/Search/);

$mech->get_ok("/search/index.pl");
$mech->content_like(qr/A database of in-situ/);

my $type_regex = {
    bacs                         => qr/Genomic clone search/,
    directory                    => qr/Directory search/,
    est                          => qr/EST search/,
    est_library                  => qr/Library search/,
    experiment                   => qr/Expression search/,
    family                       => qr/Family search/,
    images                       => qr/Image search/,
    library                      => qr/Library search/,
    loci                         => qr/Gene search/,
    marker                       => qr/Map locations/,
    markers                      => qr/Marker options/,
    phenotype                    => qr/Submit new stock/,
    phenotype_qtl_trait          => qr/Submit new stock/,
    platform                     => qr/Expression search/,
    qtl                          => qr/Search QTLs/,
    template_experiment_platform => qr/Expression search/,
    trait                        => qr/Browse trait terms/,
    unigene                      => qr/Unigene search/,
    glossary                     => qr/Glossary search/,
};

$mech->get("/search/wombats");
is($mech->status,404,'/search/wombats is a 404');

$mech->get("/search/direct_search.pl?search=wombats");
is($mech->status,404,'/search/direct_search.pl?search=wombats is a 404');

for my $type (keys %$type_regex) {
    $mech->get_ok("/search/$type");
    my $regex = $type_regex->{$type};
    $mech->content_like($regex); # or diag $mech->content;

    # the glossary search was never accessible via direct_search
    $mech->get_ok("/search/direct_search.pl?search=$type") if ($type ne 'glossary');
}

done_testing;
