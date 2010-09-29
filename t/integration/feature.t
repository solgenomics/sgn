=head1 NAME

t/integration/feature.t - integration tests for generic feature URLs

=head1 DESCRIPTION

Tests for generic feature URLs

=head1 SYNOPSIS

These tests assume that a polypeptide does not have a specialized feature mason
component and gets rendered as a generic feature with mason/feature/dhandler
from SGN::Controller::Feature.

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

my $poly_cvterm     = create_test('Cv::Cvterm', { name  => 'polypeptide' });
my $poly_feature    = create_test('Sequence::Feature', { type => $poly_cvterm });
my $poly_featureloc = create_test('Sequence::Featureloc', { feature => $poly_feature });

$mech->get_ok("/feature/view/name/" . $poly_feature->name);
my ($name, $residues) = ($poly_feature->name, $poly_feature->residues);

like( $mech->findvalue( '/html/body//span[@class="sequence"]'), qr/>$name\s*$residues/, "Found >$name\\n$residues");
like( $mech->findvalue( '/html/body//div[@class="info_table_fieldval"]'), qr/polypeptide/, "Found the polypeptide cvterm");

ok($mech->exists(
        sprintf '/html/body//div[@class="info_table_fieldval"]/a[@href="/chado/cvterm.pl?cvterm_id=%s"]',
            $poly_cvterm->cvterm_id
    ),'the proper cvterm id link exists');

$mech->content_contains('Feature Data');
$mech->content_contains($poly_feature->name);
$mech->content_contains('Nucleotide Sequence');
$mech->content_contains('Related Features');
$mech->content_contains('Reference Feature');

done_testing;
