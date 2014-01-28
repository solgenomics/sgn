use Test::Most;

use lib 't/lib';

use aliased 'SGN::Test::WWW::Mechanize';
use SGN::Test::Data qw/  CXGN::Biosource::Schema  create_test  /;

my $mech = Mechanize->new;

$mech->with_test_level( local => sub {

    my $file = create_test('MdFiles', {
        dirname  => 't/data',
        basename => 'ath_prots.seq',
    });

    ok( -f $file->path, 'made a test MdFiles object' );

    $mech->get_ok( '/metadata/file/'.$file->file_id.'/download' );
    is( $mech->content_type, 'text/plain', 'got right content type' );

});


done_testing;
