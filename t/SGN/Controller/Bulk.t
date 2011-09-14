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
    $mech->submit_form_ok({
        form_name => "bulk_feature",
        fields    => {
            ids => "SGN-E43",
        },
    }, "submit bulk_feature form");
    diag $mech->content;
});

$mech->with_test_level( local => sub {
    # attempt to post an empty list
    $mech->post('/bulk/feature/download/', { ids => "" }  );
    is($mech->status,400);
});

done_testing();
