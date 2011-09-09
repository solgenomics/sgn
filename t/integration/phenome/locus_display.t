
=head1 NAME

qtl.t - tests for cgi-bin/qtl.pl

=head1 DESCRIPTION

Tests for cgi-bin/phenome/locus_display.pl

=head1 AUTHORS

Naama Menda  <nm249@cornell.edu>

=cut

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use SGN::Test;
use SGN::Test::WWW::Mechanize;

use CXGN::Phenome::Schema;
use CXGN::DB::Connection;

{
    my $mech = SGN::Test::WWW::Mechanize->new;

    $mech->with_test_level( local => sub {
       my $schema = $mech->context->dbic_schema('CXGN::Phenome::Schema');

       #find a test locus that has no dbxrefs linked
       my $sql = "IS NULL";
       my $test_locus = $schema->resultset("Locus")->search( 
           { 'me.obsolete' => 'f',
             dbxref_id => \$sql },
           {
               join => 'locus_dbxrefs' }
          )->first();
       my $test_id;
       $test_id = $test_locus->locus_id() if $test_locus;
       $mech->get_ok("/cgi-bin/phenome/locus_display.pl?locus_id=$test_id");

       $mech->content_contains("Locus editor");
   }, 2 );
}

done_testing;
