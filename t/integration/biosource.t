#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 6;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

use CXGN::Biosource::Schema;

my $mech = SGN::Test::WWW::Mechanize->new;

## First take variables for the test from the database ##

my @schema_list = ('biosource', 'metadata', 'public');
my $schema_list = join(',', @schema_list);
my $set_path = "SET search_path TO $schema_list";

my $dbh = $mech->context()->dbc()->dbh();

my $bs_schema = CXGN::Biosource::Schema->connect( sub { $dbh }, 
						  {on_connect_do => $set_path} );


## WWW.SAMPLE TEST ###

my ($first_sample_row) = $bs_schema->resultset('BsSample')
                                   ->search( undef, 
                                             { 
					       order_by => {-asc => 'sample_id'}, 
					       rows     => 1, 
					     }
                                           );

## Now it will test the expected sample web-page if there is at least one row 
## in the database. If not, it will test the error page

if (defined $first_sample_row) {

    my $first_sample_id = $first_sample_row->get_column('sample_id');
    my $first_sample_name = $first_sample_row->get_column('sample_name');

    $mech->get_ok("/biosource/sample.pl?id=$first_sample_id");
    $mech->content_like(qr/Sample: $first_sample_name/);
    $mech->content_unlike(qr/ERROR PAGE/);

    $mech->get_ok("/biosource/sample.pl?name=$first_sample_name");
    $mech->content_like(qr/Sample: $first_sample_name/);
    $mech->content_unlike(qr/ERROR PAGE/);

}


