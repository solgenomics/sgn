=head1 NAME

t/integration/qtl_form.t - tests for qtl data submision web interface URLs

=head1 DESCRIPTION

Tests for qtl web form URLs

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More;
use Test::JSON;
use lib 't/lib';
use SGN::Test;
use SGN::Test::WWW::Mechanize;

my $base_url = $ENV{SGN_TEST_SERVER};
my $mech = SGN::Test::WWW::Mechanize->new;

$mech->while_logged_in( { user_type => 'submitter' }, sub {
 
    $mech->get_ok('/phenome/qtl_form.pl');
    $mech->content_contains('Introduction');
    
   # $mech->submit_form_ok( {
   #     form_number => 2,
   #     fields => {
   #     },
   # },
   # );

    $mech->get_ok('/phenome/qtl_form.pl?type=pop_form');    
    $mech->content_contains('Select Organism');
    $mech->content_contains('Population Details');
 
    $mech->get_ok('/phenome/qtl_form.pl?type=trait_form');
    $mech->content_contains('Traits');

    $mech->get_ok('/phenome/qtl_form.pl?type=pheno_form');
    $mech->content_contains('Phenotype');

    $mech->get_ok('/phenome/qtl_form.pl?type=geno_form');
    $mech->content_contains('Genotype');

    $mech->get_ok('/phenome/qtl_form.pl?type=stat_form');
    $mech->content_contains('Statistical');

    $mech->get_ok('/phenome/qtl_form.pl?type=confirm');
    $mech->content_contains('Confirmation');
   
});

done_testing;
