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
$mech->content_like(qr!Organism/Taxon Search!);

$mech->get_ok("/search");
$mech->content_like(qr/Search/);

$mech->get_ok("/search/index.pl");
# $mech->content_like(qr/A database of in-situ/);

my $type_regex = {
    bacs                         => qr/Genomic Clone Search/,
    directory                    => qr/Directory search/,
    est                          => qr/EST Search/,
    est_library                  => qr/Library search/,
    experiment                   => qr/Expression Search/,
    family                       => qr/Family search/,
    images                       => qr/Image Search/,
    library                      => qr/Library search/,
    loci                         => qr/Search Genes and Loci/,
    marker                       => qr/Map\/Marker Locations/,
    markers                      => qr/Marker Options/,
    #phenotype                    => qr/Submit New Stock/,
    #phenotype_qtl_trait          => qr/Submit New Stock/,
    platform                     => qr/Expression Search/,
    qtl                          => qr/Search QTLs/,
    template_experiment_platform => qr/Expression Search/,
    trait                        => qr/Search and browse tree of traits/,
    unigene                      => qr/Unigene Search/,
    glossary                     => qr/Glossary search/,
};

$mech->get("/search/wombats");
is($mech->status,404,'/search/wombats is a 404');

$mech->get("/search/direct_search.pl?search=wombats");
is($mech->status,404,'/search/direct_search.pl?search=wombats is a 404');

for my $type (keys %$type_regex) {
    $mech->get_ok("/search/$type");
    my $regex = $type_regex->{$type};
    diag $mech->content;
    $mech->content_like($regex); 

    # the glossary search was never accessible via direct_search
    $mech->get_ok("/search/direct_search.pl?search=$type") if ($type ne 'glossary');
}

done_testing;
