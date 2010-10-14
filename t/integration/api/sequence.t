=head1 NAME

t/integration/api/sequence.t - integration tests for API sequence URLs

=head1 DESCRIPTION

Tests for sequence API URLs

=head1 SYNOPSIS

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

$mech->get_ok('/api/v1/sequence/' . $poly_feature->name . '.fasta');

done_testing;
