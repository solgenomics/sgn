=head1 NAME

t/integration/feature.t - integration tests for generic feature URLs

=head1 DESCRIPTION

Tests for generic feature URLs

=head1 SYNOPSIS

These tests assume that a polypeptide does not have a specialized feature mason
component and gets rendered as a generic feature with mason/feature/default.mas
from SGN::Controller::Feature.

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More;
BEGIN { $ENV{SGN_SKIP_CGI} = 1 }
use lib 't/lib';
use SGN::Test::Data qw/ create_test /;
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;

my $poly_cvterm     = create_test('Cv::Cvterm', { name  => 'polypeptide' });
my $poly_feature    = create_test('Sequence::Feature', { type => $poly_cvterm });
my $poly_featureloc = create_test('Sequence::Featureloc', { feature => $poly_feature });

for my $url ( "/feature/view/name/".$poly_feature->name,  "/feature/view/id/".$poly_feature->feature_id ) {

    $mech->get_ok( $url );
    $mech->dbh_leak_ok;
    $mech->html_lint_ok('valid HTML');

    my ($name, $residues) = ($poly_feature->name, $poly_feature->residues);

    like( $mech->findvalue( '/html/body//span[@class="sequence"]'), qr/>$name\s*/, "Found >$name\\n");
    like( $mech->findvalue( '/html/body//div[@class="info_table_fieldval"]'), qr/polypeptide/i, "Found the polypeptide cvterm");

    ok($mech->exists(
        sprintf '/html/body//div[@class="info_table_fieldval"]/a[@href="/chado/cvterm.pl?cvterm_id=%s"]',
        $poly_cvterm->cvterm_id
       ),'the proper cvterm id link exists');

    $mech->content_contains('Polypeptide details');
    $mech->content_contains($poly_feature->name);
}

done_testing;
