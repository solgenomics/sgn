use strict;
use warnings;
use Test::More;
use Data::Dumper;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

use CXGN::TomatoGenome::BACPublish qw/  publisher  aggregate_filename /;

my $mech = SGN::Test::WWW::Mechanize->new;

# test clone annotation download
$mech->get_ok('/maps/physical/clone_info.pl?id=11803');

$mech->with_test_level( local => sub {
    my $c = $mech->context;

  SKIP:
    {   skip 'bac annotation files not available', 4
            unless -e File::Spec->catfile( $c->config->{ftpsite_root}, 'tomato_genome', 'bacs' );


        my $form = $mech->form_name('clone_annot_download');
        skip 'clone_annot_download form is not present', 4 unless $form;

        $mech->submit_form_ok({
            form_name => 'clone_annot_download',
            fields => {
                set => 'AUGUSTUS_ab_initio',
                format => 'gff3',
            },
        });

        is( $mech->content_type, 'text/plain', 'text/plain content type' );
        cmp_ok( length( $mech->content ), '>=', 1000, 'got some content' );
        like( $mech->content, qr/^##gff-version 3/, 'content looks like gff3' );
    }
});

# keep the code from thinking the error is our fault
$mech->add_header( Referer => undef );

$mech->get( '/genomic/clone/0/annotation/download?set=AUGUSTUS_ab_initio&format=gff3' );
is( $mech->status, 404, 'got a 404 for a nonexistent set' );

done_testing;
