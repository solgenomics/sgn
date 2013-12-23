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
use SGN::Test::WWW::Mechanize skip_cgi => 1;

my $mech = SGN::Test::WWW::Mechanize->new;

my $residue = 'AATTCCGG' x 3;
my $poly_cvterm     = create_test('Cv::Cvterm', { name  => 'polyfonebone' });
my $poly_feature    = create_test('Sequence::Feature', {
        type     => $poly_cvterm,
        residues => $residue,
});
my $poly_featureloc = create_test('Sequence::Featureloc', { feature => $poly_feature });
my $poly_feature_2   = create_test('Sequence::Feature', {
        type     => $poly_cvterm,
        residues => reverse( $residue ),
});

for my $base ( '/api/v1/sequence/download/single/', '/gmodrpc/v1.1/fetch/seq/' ) {
    # 3 = > + 2 newlines
    my $length = length($poly_feature->name . $residue) + 3;
    $mech->get_ok( $base . $poly_feature->name . '.fasta');
    $mech->content_contains( '>' . $poly_feature->name );
    $mech->content_contains( $residue );
    is( $mech->content_type, 'application/x-fasta', 'right content type');
    is( $length, length($mech->content), 'got the expected content length');
}
{
    # 6 = 10 - 5 + 1 = # of chars in requested sequence
    my $length = length($poly_feature->name.':5..10' ) + 3 + 6;
    $mech->get_ok('/api/v1/sequence/download/single/' . $poly_feature->name . '.fasta?5..10');
    $mech->content_contains( '>' . $poly_feature->name . ':5..10' );
    $mech->content_like( qr/^CCGGAA$/m );
    is( $mech->content_type, 'application/x-fasta', 'right content type');
    is( $length, length($mech->content), 'got the expected content length');
}
{
    # 6 = 10 - 5 + 1 = # of chars in requested sequence
    my $length = length($poly_feature->name.':5..10' ) + 3 + 6;
    $mech->get_ok('/api/v1/sequence/download/single/' . $poly_feature->feature_id . '.fasta?5..10');
    $mech->content_contains( '>' . $poly_feature->name . ':5..10' );
    $mech->content_like( qr/^CCGGAA$/m );
    is( $mech->content_type, 'application/x-fasta', 'right content type');
    is( $length, length($mech->content), 'got the expected content length');
}
{
    $mech->get_ok('/api/v1/sequence/download/single/' . $poly_feature->name . '.ace?10..5', 'fetched in ace format');
    $mech->content_contains( '"'. $poly_feature->name . ':10..5"' );
    $mech->content_like( qr/^TTCCGG$/m );
    is( $mech->content_type, 'text/plain', 'right content type');
}
{
    # 6 = 10 - 5 + 1 = # of chars in requested sequence
    my $length = length($poly_feature->name.':5..10' ) + 3 + 6;
    $mech->get_ok('/api/v1/sequence/download/single/' . $poly_feature->feature_id . '.fasta?5..10');
    $mech->content_contains( '>' . $poly_feature->name . ':5..10' );
    $mech->content_like( qr/^CCGGAA$/m );
    is( $mech->content_type, 'application/x-fasta', 'right content type');
    is( $length, length($mech->content), 'got the expected content length')
      or diag $mech->content;
}
{
    $mech->get_ok('/api/v1/sequence/download/multi?s=' . $poly_feature->feature_id . '&s=' . $poly_feature_2->name .'&format=tab' );
    is $mech->content, sprintf(<<'EOT',$poly_feature->name,$poly_feature_2->name), 'right content for tab-delimited fetch';
%s	AATTCCGGAATTCCGGAATTCCGG
%s	AATTCCGGAATTCCGGAATTCCGG
EOT
}
{
    $mech->get("/api/v1/sequence/download/single/JUNK.fasta");
    is( $mech->status, 404, 'feature not found' );

    $mech->get("/api/v1/sequence/download/multi?s=" . $poly_feature->feature_id . '&s=JUNK');
    is( $mech->status, 200, 'multi api query succeeds if any identifiers are valid');

    $mech->get("/api/v1/sequence/download/multi?s=" . $poly_feature->feature_id);
    is( $mech->status, 200, 'multi api query succeeds if given single id');

    $mech->get("/api/v1/sequence/download/multi?s=JUNK");
    is( $mech->status, 404, 'multi api query with only a single invalid id = 404');

}

done_testing;
