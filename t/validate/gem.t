use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (
        "gem search page for templates"            => "/search/direct_search.pl?search=template",
        "gem search page for experiments"          => "/search/direct_search.pl?search=experiment",
        "gem search page for platforms"            => "/search/direct_search.pl?search=platform",
        "gem results page for templates"           => "/search/gem_template_search.pl?w616_template_parameters=AB",
        "gem results page for experiments"         => "/search/gem_experiment_search.pl?w932_experiment_parameters=leaf",
        "gem results page for platforms"           => "/search/gem_platform_search.pl?w4b9_template_parameters=affy",
        "gem detail page for template"             => "/gem/template.pl?id=65",
        "gem detail page for platform"             => "/gem/platform.pl?id=1",
        "gem detail page for experimental design"  => "/gem/experimental_design.pl?id=1",
        "gem detail page for experiment"           => "/gem/experiment.pl?id=1",
        "gem detail page for target"               => "/gem/target.pl?id=49",
);

my $iteration_count;

plan( tests => scalar(keys %urls)*4*($iteration_count = $ENV{ITERATIONS} || 1));

validate_urls(\%urls, $iteration_count);

