=head1 NAME

t/integration/feature_gene.t - integration tests for gene feature URLs

=head1 DESCRIPTION

Tests for gene feature URLs

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use SGN::Test::Data qw/ create_test /;
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;

my $gene_cvterm     = create_test('Cv::Cvterm', { name  => 'gene' });
my $gene_feature    = create_test('Sequence::Feature', { type => $gene_cvterm });
my $gene_featureloc = create_test('Sequence::Featureloc', { feature => $gene_feature });

$mech->get_ok("/feature/view/name/" . $gene_feature->name);
$mech->content_contains('Gene Data');
$mech->content_contains('Gene: ' . $gene_feature->name);
$mech->content_contains('Genomic Sequence');

done_testing;
