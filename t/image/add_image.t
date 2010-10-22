use strict;
use warnings;

use Test::More;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $m = SGN::Test::WWW::Mechanize->new;

# test image upload
#$m->get_ok('/image/add?type=test&type_id=1');

$m->with_test_level( local => sub {
    $m->while_logged_in( { user_type => 'user' }, sub {
        my $user_info = shift;

        # test image upload
        $m->get_ok('/image/add?type=test&type_id=1');

        my %form = (
            form_name => 'upload_image_form',
            fields => {
                file => 't/image/tv_test_1.png',
                #		 type=>'locus',
                #		 type_id=>'1',
                refering_page => 'http://google.com',
            },
           );

        $m->submit_form_ok(\%form, "form submit test");

        $m->content_like( qr/image\s+uploaded/, "content test 1", "check basic content");

        $m->content_contains('http://google.com', "check referer");

        $m->content_contains( $user_info->{id}, "submitter id check");

  });
});


done_testing;
