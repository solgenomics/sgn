=head1 NAME

t/integration/ajax.t - Integration tests for AJAXy stuff

=head1 DESCRIPTION

Tests for AJAXy stuff.

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More;
use Test::JSON;
use JSON::Any;
use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;

my @ajax_urls = (
    "/image/ajax/image_ajax_form.pl?action=view",
    "/image/ajax/image_ajax_form.pl?action=",
    "/image/ajax/image_ajax_form.pl",
    "/image/ajax/image_ajax_form.pl?action=edit",
    "/image/ajax/image_ajax_form.pl?object_id=0",
);

plan( tests => 2*@ajax_urls );
my $j = JSON::Any->new;
for my $url (@ajax_urls) {
    $mech->get_ok($url);
    is_valid_json($mech->content, "$url is valid JSON");
    my $out = $j->decode( $mech->content );
}
