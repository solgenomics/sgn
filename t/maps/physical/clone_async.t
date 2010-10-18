#!/usr/bin/perl
use strict;
use warnings;
use English;

use JSON;
use lib 't/lib';
use SGN::Test qw( get request );

use CXGN::Genomic::Clone;

use Test::More;

my $test_clone_id = 8978;
my $test_clone = CXGN::Genomic::Clone->retrieve($test_clone_id)
  or BAIL_OUT("can't retrieve clone $test_clone_id from db!");
my $clone_info = $test_clone->reg_info_hashref;

my $base = '/maps/physical/clone_async.pl';

## tests JSON clone query
my $qjson_url = "$base?action=qclonejson&clone_id=$test_clone_id";
my $qjson = get( $qjson_url );
like( $qjson, qr/ver_int_read/, 'got back something from from_json' )
  or diag "failing url: $qjson_url";
my $qjson_result = eval { from_json( $qjson ) };
is(ref($qjson_result),'HASH','json seems to have parsed')
  or diag "$EVAL_ERROR\n$qjson_url";
is_deeply( $clone_info, $qjson_result, "JSON return is the same as the reg_info_hashref from the clone object" );


## tests Perl-format clone query
my $qperl_url = "$base?action=qcloneperl&clone_name=".$test_clone->clone_name_with_chromosome;
my $qperl = request( $qperl_url );
is( $qperl->code, 200, 'perl clone query succeeded')
    or diag "text returned was:\n".$qperl->content;
my $qperl_result = eval $qperl->content;
ok( !$EVAL_ERROR, 'perl return evaled ok' )
  or diag "$EVAL_ERROR\n(url was $qperl_url)";
is_deeply( $clone_info, $qperl_result, "Perl return is the same as the reg_info_hashref from the clone object" );

# tests that JSON and perl data structures agree
is_deeply( $qjson_result, $qperl_result, "JSON and Perl return the same data structure" );


# test the project stats image
{ my $pi_req = request("$base?action=project_stats_img_html");
  is( $pi_req->code, 200, 'got async project stats image ok' );
  like( $pi_req->content, qr/\.png"/, 'a .png image url is somewhere in the html' );
  like( $pi_req->content, qr/<img /, 'contains an image' );
  like( $pi_req->content, qr/<map /, 'contains an image map' );
}


done_testing;
