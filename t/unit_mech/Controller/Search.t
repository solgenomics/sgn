use Modern::Perl;
use lib 't/lib';

use SGN::Test::WWW::Mechanize skip_cgi => 1;
use Test::Most;

my @urls = qw{
            /search
            /search/
            /search/organisms
            /search/loci
            /search/phenotypes/qtl
            /search/phenotypes
            /search/family
            /search/markers
            /search/images
            /search/directory

            /search/qtl
            /search/trait
            /search/phenotype
            /search/unigene
            /search/platform
            /search/template_experiment_platform
            /search/est
            /search/est_library
            /search/bacs

            /search/phenotypes/qtl
            /search/phenotypes/traits
            /search/phenotypes/stock
            /search/transcripts/unigene
            /search/expression/platform
            /search/expression/template
            /search/transcripts/est
            /search/transcripts/est_library
            /search/genomic/clones

};

my $mech = SGN::Test::WWW::Mechanize->new;
for my $url ( @urls ) {
    $mech->get_ok( $url );
    #$mech->html_lint_ok;
}

done_testing();
