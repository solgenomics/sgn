use strict;
use warnings;
use Test::More tests => 6;

use lib 't/lib';
use SGN::Test::Data qw/ create_test /;
use Catalyst::Test 'SGN';
use Digest::SHA1 qw/sha1_hex/;
use Data::Dumper;

use_ok 'SGN::Controller::Bulk';
use aliased 'SGN::Test::WWW::Mechanize' => 'Mech';

my $mech = Mech->new;

$mech->with_test_level( local => sub {
    my $poly_cvterm     = create_test('Cv::Cvterm',        { name => 'gene' });
    my $poly_feature    = create_test('Sequence::Feature', { type => $poly_cvterm  });
    diag "Created gene " . $poly_feature->name;
    $mech->get('/bulk/gene');
    $mech->submit_form_ok({
        form_name => "bulk_gene",
        fields    => {
            ids => "Solyc02g081670.1",
        },
    }, "submit bulk_gene with a single valid identifier");
    my $sha1 = sha1_hex("Solyc02g081670.1");
    $mech->content_unlike(qr/Caught exception/) or diag $mech->content;
    $mech->content_unlike(qr/Your query did not contain any valid identifiers/) or diag $mech->content;
    my @flinks = $mech->find_all_links( url_regex => qr{/bulk/gene/download/$sha1\.fasta} );
    cmp_ok(@flinks, '==', 1, "found one FASTA download link for $sha1.fasta");
    $mech->links_ok( \@flinks );

});
