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
BEGIN { $ENV{SGN_SKIP_CGI} = 1 }
use lib 't/lib';
use SGN::Test::Data qw/ create_test /;
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;

my $residue = 'AATTCCGG' x 3;
my $poly_cvterm     = create_test('Cv::Cvterm', { name  => 'polypeptide' });
my $poly_feature    = create_test('Sequence::Feature', {
        type     => $poly_cvterm,
        residues => $residue,
});
my $poly_featureloc = create_test('Sequence::Featureloc', { feature => $poly_feature });

{
    # 3 = > + 2 newlines
    my $length = length($poly_feature->name . $residue) + 3;
    $mech->get_ok('/api/v1/sequence/' . $poly_feature->name . '.fasta');
    $mech->content_contains( '>' . $poly_feature->name );
    $mech->content_contains( $residue );
    is('text/plain', $mech->content_type, 'text/plain content type');
    is( $length, length($mech->content), 'got the expected content length');
}
{
    # 6 = 10 - 5 + 1 = # of chars in requested sequence
    my $length = length($poly_feature->name.':5..10' ) + 3 + 6;
    $mech->get_ok('/api/v1/sequence/' . $poly_feature->name . '.fasta?5..10');
    $mech->content_contains( '>' . $poly_feature->name . ':5..10' );
    $mech->content_like( qr/^CCGGAA$/m );
    is('text/plain', $mech->content_type, 'text/plain content type');
    is( $length, length($mech->content), 'got the expected content length');
}
{
    $mech->get("/api/v1/sequence/JUNK.fasta");
    is( $mech->status, 404, 'feature not found' );
}
done_testing;
