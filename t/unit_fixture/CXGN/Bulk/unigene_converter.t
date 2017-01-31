use strict;
use warnings;
use Test::More;
use File::Temp;

use lib 't/lib';
use SGN::Test::WWW::Mechanize skip_cgi => 1;

# this thing is really basically a controller, so will test it like
# one
use_ok 'CXGN::Bulk::UnigeneConverter';

my $mech = SGN::Test::WWW::Mechanize->new;
$mech->with_test_level( local => sub {

    my $tempdir = File::Temp->newdir;
    my $params = {};
    $params->{idType} = "unigene_convert";
    $params->{ids} = "SGN-U243120 SGN-U243522";
    $params->{dbc} = $mech->context->dbc->dbh;
    $params->{tempdir} = "$tempdir";

    # Testing constructor.
    my $bulk = CXGN::Bulk::UnigeneConverter->new($params);

    is($bulk->{idType}, "unigene_convert", "idType ok");
    is($bulk->{ids}, "SGN-U243120 SGN-U243522", "id input string ok");

    # Testing process_parameters method.
    my $pp = $bulk->process_parameters();

    is($pp, 1, "parameters are ok (process_parameters returned 1)");

    is_deeply( $bulk->{ids}, [243120, 243522], "id list is ok" );

    # Testing process_ids method.
    $bulk->process_ids();
});

done_testing;


