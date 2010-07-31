
=head1 NAME

qtl.t - tests for cgi-bin/qtl.pl

=head1 DESCRIPTION

Tests for cgi-bin/phenome/locus_display.pl

=head1 AUTHORS

Naama Menda  <nm249@cornell.edu>

=cut

use strict;
use Test::More qw /no_plan/ ; #tests => 2;
use Test::WWW::Mechanize;
use CXGN::Phenome::Schema;
use CXGN::DB::Connection;

use SGN::Context;

BAIL_OUT "Need to set the SGN_TEST_SERVER environment variable" unless $ENV{SGN_TEST_SERVER};

my $base_url = $ENV{SGN_TEST_SERVER};

{
    my $mech = Test::WWW::Mechanize->new;

    $mech->get_ok("$base_url/cgi-bin/phenome/locus_display.pl");
    my $schema = SGN::Context->new->dbic_schema('CXGN::Phenome::Schema');

    #find a test locus that has no dbxrefs linked
    my $sql = "IS NULL";
    my $test_locus = $schema->resultset("Locus")->search( 
	{ 'me.obsolete' => 'f',
	  dbxref_id => \$sql },
	{ join => 'locus_dbxrefs' }
	)->first();
    my $test_id;
    $test_id = $test_locus->locus_id() if $test_locus;
    $mech->get_ok("$base_url/cgi-bin/phenome/locus_display.pl?locus_id=$test_id");

    $mech->content_contains("Locus editor");
}
