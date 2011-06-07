use Modern::Perl;
use lib 't/lib';
use SGN::Test;
use Test::Most;

BEGIN { use_ok 'Catalyst::Test', 'SGN' }
BEGIN { use_ok 'SGN::Controller::Search' }

my @urls = qw{
            /search
            /search/
            /search/loci
            /search/qtl
            /search/unigene
            /search/family
            /search/markers
            /search/bacs
            /search/est_library
            /search/images
            /search/directory
            /search/template_experiment_platform
};

for my $url (@urls) {
    ok( request($url)->is_success, "GET $url succeeded");
}
done_testing();
