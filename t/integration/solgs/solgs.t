=head1 NAME

solgs.t - integration tests for solgs

=head1 DESCRIPTION



=cut

use strict;
use warnings;

use Test::More;
use Test::WWW::Mechanize;



use_ok(  'solGS::Controller::Root'  ) or
BAIL_OUT( 'Couldn't load solGS::Controller::Root');   

use_ok(  'solGS::Model::solGS'  ) or
BAIL_OUT( 'Couldn't load solGS::Model::solGS');   

use_ok(  'solGS::Controller::Stock'  ) or
BAIL_OUT( 'Couldn't load solGS::Controller::Stock');   
   

my $mech = Test::WWW::Mechanize->new();

$mech->get_ok('/search', 'Got search page');
