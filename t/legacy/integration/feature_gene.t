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
$mech->content_contains($gene_feature->name);
$mech->content_contains('Genomic sequence');
$mech->content_contains('Related features');

my $name = $gene_feature->name;

like( $mech->findvalue( '/html/body//span[@class="sequence"]'), qr/>$name\s*/, "Found >$name seq header");

ok($mech->exists(
        sprintf '/html/body//div[@class="info_table_fieldval"]/a[@href="/cvterm/%s/view"]',
            $gene_cvterm->cvterm_id
    ),'the proper cvterm id link exists');

done_testing;
