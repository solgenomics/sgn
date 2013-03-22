
# test for the AJAX backend of the List interface

# Lukas, Feb 2013

use strict;

use Test::More qw/no_plan/;
use JSON::Any;
use Data::Dumper;
use SGN::Test::WWW::Mechanize;

my $m = SGN::Test::WWW::Mechanize->new();

$m->while_logged_in( 
    { user_type => 'user' }, 
    sub {
	
	$m->get_ok('/list/new?name=test');
	
	$m->get_ok('/list/available');
	
	$m->content_contains('test');
	
	$m->get_ok('/list/exists?name=test');
	
	my $json = $m->content();

	my $data = JSON::Any->decode($json);
	
	my $list_id = $data->{list_id};
			 
	$m->get_ok("/list/item/add?list_id=$list_id&element=blabla");

	$m->content_contains("SUCCESS");

	$m->get_ok("/list/get?list_id=$list_id");

	$m->content_contains("blabla");

	$json = $m->content();

	$data = JSON::Any->decode($json);

	my $item_id = $data->[0]->[0];

	#print $item_id."\n";
	#print Data::Dumper::Dumper($data);

	$m->get_ok("/list/item/remove?list_id=$list_id&item_id=$data->[0]->[0]");
	$m->get_ok("/list/get?list_id=$list_id");
	
	$m->content_lacks("blabla");

	$m->get_ok("/list/delete?list_id=$list_id");

	$m->content_contains("1");

	$m->get_ok("/list/available");

	$m->content_lacks("test");
	
	
    });




