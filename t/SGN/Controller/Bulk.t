use strict;
use warnings;
use Test::More;

use lib 't/lib';
use SGN::Test::Data qw/ create_test /;

use Catalyst::Test 'SGN';

use_ok 'SGN::Controller::Bulk';
use aliased 'SGN::Test::WWW::Mechanize' => 'Mech';

my $mech = Mech->new;

my $poly_cvterm     = create_test('Cv::Cvterm',        { name => 'polypeptide' });
my $poly_feature    = create_test('Sequence::Feature', { type => $poly_cvterm  });

$mech->with_test_level( local => sub {
    $mech->get_ok('/bulk/feature');

    # download a single feature with no whitespace
    $mech->post_ok('/bulk/feature/download', { ids => $poly_feature->name }  );
});

done_testing();
