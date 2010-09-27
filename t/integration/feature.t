=head1 NAME

t/integration/feature.t - integration tests for feature URLs

=head1 DESCRIPTION

Tests for feature URLs

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use SGN::Test::Data qw/
    create_test_cvterm create_test_feature
    create_test_featureloc
    /;
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;

my $gene_cvterm  = create_test_cvterm({ name => 'gene' });
my $gene_feature = create_test_feature({ type => $gene_cvterm });
my $gene_featureloc = create_test_featureloc({ feature => $gene_feature });

$mech->get_ok("/feature/view/name/" . $gene_feature->name);
$mech->content_contains('Gene Data');
$mech->content_contains('Gene: ' . $gene_feature->name);

done_testing;
