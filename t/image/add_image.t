use strict;
use warnings;

use Test::More;

use CXGN::DB::Connection;
use lib 't/lib';
use SGN::Test::WWW::Mechanize;
use File::Basename;
use CXGN::Image;

my $m = SGN::Test::WWW::Mechanize->new;

my $test_file = 't/image/tv_test_1.png';
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
                file => $test_file,
                #		 type=>'locus',
                #		 type_id=>'1',
                refering_page => 'http://google.com',
            },
           );

        $m->submit_form_ok(\%form, "form submit test");

        $m->content_like( qr/image\s+uploaded/, "content test 1", "check basic content");

        $m->content_contains('http://google.com', "check referer");

        $m->content_contains( $user_info->{id}, "submitter id check");
	
	my $store_form = { 
	    form_name => 'store_image',
	};

	$m->submit_form_ok($store_form, "Submitting the image for storage");
	
	$m->content_contains('SGN Image');

	$m->content_contains(basename($test_file));

	my $uri = $m->uri();

	my $image_id = "";
	if ($uri =~ /\/(\d+)$/) { 
	    $image_id=$1;
	}

	my $dbh = CXGN::DB::Connection->new();
	my $i = CXGN::Image->new(dbh=>$dbh, image_id=>$image_id, image_dir=>$m->context->config->{'image_dir'});
	diag "Deleting image_id $image_id\n";
	$i->hard_delete();

	$dbh->commit();
	$dbh->disconnect();
       
  });
});


done_testing;
