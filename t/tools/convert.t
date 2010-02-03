#!/usr/bin/perl
use strict;
use warnings;
use English;

use Test::More tests => 21;

use Test::WWW::Mechanize;

my $urlbase = "$ENV{SGN_TEST_SERVER}/tools/convert/";
my $input_page = "$urlbase/input.pl";

my $mech = Test::WWW::Mechanize->new;

for my $id_input ('TC115712',"TC115712\n","TC115710") {
    $mech->get_ok( $input_page );

    # a few checks on the title
    $mech->title_is( "ID Converter", "Make sure we're on ID Converter input page" );

    # a few checks on the content
    $mech->content_contains( "TIGR TC", "mentions TIGR TC" );
    $mech->content_like( qr/SGN-U\d+/, "mentions unigenes" );

    $mech->submit_form_ok({ form_name => 'convform',
                            fields => {ids => $id_input},
                          },
                          'search for a single TC to convert',
                         );

    $mech->content_like( qr/SGN Unigene ID/, "mentions unigenes" );
    my ($id) = $id_input =~ /(\d+)/;
    $mech->content_contains($id, "contains TC ident (whether found or not)" );
}
#$mech->stuff_inputs;


#TODO: finish writing convert.pl tests
