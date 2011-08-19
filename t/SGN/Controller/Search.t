use Modern::Perl;
use lib 't/lib';
use SGN::Test;
use Test::Most;

BEGIN { use_ok 'Catalyst::Test', 'SGN' }
BEGIN { use_ok 'SGN::Controller::Search' }

my @urls = qw{
            /search
            /search/
            /search/organisms
            /search/loci
            /search/qtl
            /search/trait
            /search/phenotypes
            /search/phenotype
            /search/unigene
            /search/family
            /search/markers
            /search/bacs
            /search/est_library
            /search/images
            /search/directory
            /search/template_experiment_platform
            /search/platform
};

for my $url (@urls) {
    my ($r) = request($url);
    diag $r->content unless $r->is_success;
    cmp_ok( $r->code,'eq',200, "GET $url succeeded with 200");
}
done_testing();
