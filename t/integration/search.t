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

my @search_types = qw{
    loci unigene feature family markers marker bacs est_library insitu directory
    images template_experiment_platform glossary phenotype_qtl_trait trait
    glossary qtl experiment platform
};


$mech->get_ok("/search");
$mech->content_like(qr/Search/);

my $type_regex = {
    bacs                         => qr/Genomic clone search/,
    directory                    => qr/Directory search/,
    est_library                  => qr/EST search/,
    experiment                   => qr/Expression search/,
    family                       => qr/Family search/,
    feature                      => qr/foo/,
    insitu                       => qr/foo/,
    images                       => qr/Image search/,
    library                      => qr/Library search/,
    loci                         => qr/Gene search/,
    marker                       => qr/Map locations/,
    markers                      => qr/Marker options/,
    phenotype                    => qr/Submit new stock/,
    phenotype_qtl_trait          => qr/Search QTLs by trait name/,
    phenotypes                   => qr/QTL Population/,
    platform                     => qr/Expression search/,
    qtl                          => qr/QTL search/,
    template_experiment_platform => qr/Expression search/,
    trait                        => qr/Browse trait terms/,
    unigene                      => qr/Unigene search/,
    glossary                     => qr/Glossary search/,
};

for my $type (@search_types) {
    $mech->get_ok("/search/$type");
    $mech->get_ok("/search/direct_search.pl?search=$type");
    my $regex = $type_regex->{$type};
    $mech->content_like($regex); # or diag $mech->content;
}

done_testing;
