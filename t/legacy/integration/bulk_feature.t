use strict;
use warnings;
use Test::More tests => 34;

use Digest::SHA qw/sha1_hex/;
use Data::Dumper;

use lib 't/lib';
use SGN::Test::Data qw/ create_test /;
use aliased 'SGN::Test::WWW::Mechanize' => 'Mech', skip_cgi => 1;

use_ok 'SGN::Controller::Bulk';

my $mech = Mech->new;

my $poly_cvterm     = create_test('Cv::Cvterm',        { name => 'polypeptide' });
my $poly_feature    = create_test('Sequence::Feature', { type => $poly_cvterm  });

# TODO: these tests depend on live data.
$mech->with_test_level( local => sub {
    # do it twice to test for bugs relating to the cache directory getting removed
    submit_bulk_form();
    submit_bulk_form();
    #diag $mech->content;
});

$mech->with_test_level( local => sub {
    $mech->get('/tools/bulk/tabs/feature_tab');
    $mech->submit_form_ok({
        form_name => "bulk_feature",
        fields    => {
            ids => "BAR",
        },
    }, "submit bulk_feature with a single invalid identifier");
    $mech->content_unlike(qr/Caught exception/);
    $mech->content_contains('Your query did not contain any valid identifiers. Please try again.');
});

$mech->with_test_level( local => sub {
    $mech->get('/tools/bulk/tabs/feature_tab');
    $mech->submit_form_ok({
        form_name => "bulk_feature",
        fields    => {
            ids => "FOO\nBAR",
        },
    }, "submit bulk_feature with no valid identifiers");
    $mech->content_unlike(qr/Caught exception/);
    $mech->content_contains('Your query did not contain any valid identifiers. Please try again.');
});

$mech->with_test_level( local => sub {
    $mech->get('/tools/bulk/tabs/feature_tab');
    $mech->submit_form_ok({
        form_name => "bulk_feature",
        fields    => {
            ids => "\nSGN-E398616  ",
        },
    }, "submit bulk_feature form with leading+trailing whitespace");
    $mech->content_unlike(qr/Caught exception/);

    $mech->get('/tools/bulk/tabs/feature_tab');
    $mech->submit_form_ok({
        form_name => "bulk_feature",
        fields    => {
            ids => "\nSGN-E398616 BLARG",
        },
    }, "submit bulk_feature form with invalid identifiers");
    $mech->content_contains('Your query was successful.');
    $mech->content_contains('A total of 1 matching features were found for 2 identifiers provided');
});

$mech->with_test_level( local => sub {
    $mech->get('/tools/bulk/tabs/feature_tab');
    $mech->submit_form_ok({
        form_name => "bulk_feature",
        fields    => {
            # NOTE: no trailing whitespace, to test for colliding identifiers
            ids => "SGN-E398616",
            feature_file => [ [ undef, 'ids.txt', Content => "AP009263\n" ] ],
        },
    }, "submit bulk_feature form with file upload and textarea");
    my $sha1  = sha1_hex(<<ID_LIST);
SGN-E398616
AP009263
ID_LIST

    my @flinks = $mech->find_all_links( url_regex => qr{/bulk/feature/download/$sha1\.fasta} );

    cmp_ok(@flinks, '==', 1, "found one FASTA download link for $sha1.fasta");
    $mech->links_ok( \@flinks );

    for my $url (map { $_->url } (@flinks)) {
        $mech->get( $url );
        my $length = length($mech->content);
        cmp_ok($length, '>', 0,"$url has a content length $length > 0");
        $mech->content_unlike(qr/Caught exception/);
    }

});

$mech->with_test_level( local => sub {
    # attempt to post an empty list
    $mech->post('/bulk/feature/submit/', { ids => "" }  );
    $mech->content_like(qr/At least one identifier must be given/);
});

done_testing();

sub submit_bulk_form {
    my $ids =<<IDS;
SGN-E398616
SGN-E540202
SGN-E541638
C06HBa0222J18.1
C06HBa0229B01.1
AP009263
AP009262
SGN-E200027
SGN-E201684
SGN-E587346
SGN-E443637
SGN-E403108
IDS
    $mech->get_ok('/tools/bulk/tabs/feature_tab');
    $mech->submit_form_ok({
        form_name => "bulk_feature",
        fields    => {
            ids => $ids,
        },
    }, "submit bulk_feature form");
    $mech->content_like(qr/Download as/);

    my $sha1  = sha1_hex($ids);
    my @flinks = $mech->find_all_links( url_regex => qr{/bulk/feature/download/$sha1\.fasta} );

    cmp_ok(@flinks, '==', 1, "found one FASTA download link for $sha1.fasta");
    $mech->links_ok( \@flinks );

    for my $url (map { $_->url } (@flinks)) {
        $mech->get( $url );
        my $length = length($mech->content);
        cmp_ok($length, '>', 0,"$url has a content length $length > 0");
        $mech->content_unlike(qr/Caught exception/);
    }

    @flinks =  grep { $_ =~ qr{$sha1} } $mech->find_all_links(url_regex => qr{/bulk/feature/download/.*\.fasta} );

    cmp_ok(@flinks, '==', 0, "found no other fasta download links") or diag("Unexpected fasta download links" . Dumper [ map {$_->url} @flinks ]);

}
