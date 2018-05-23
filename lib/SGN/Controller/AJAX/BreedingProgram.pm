
=head1 NAME

SGN::Controller::AJAX::BreedingProgram  
 REST controller for viewing breeding programs and the data associated with them

=head1 DESCRIPTION


=head1 AUTHOR

Naama Menda <nm249@cornell.edu>


=cut
package SGN::Controller::AJAX::BreedingProgram;

use Moose;

use List::MoreUtils qw | any all |;
use JSON::Any;
use Data::Dumper;
use Try::Tiny;
use CXGN::BreedingProgram;

BEGIN { extends 'Catalyst::Controller::REST'; };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );


sub locations :Chained('/program/get_program') :PathPart('locations') ActionClass('REST') { } 

sub locations_GET :Args(0) {
    my ($self, $c) = @_;
    my $program = $c->stash->{program};
    
    my $locations = $program->get_locations;
    $c->stash->{rest} = { locations => $locations };
    return;
}


sub years :Chained('/program/get_program') :PathPart('years') ActionClass('REST') { }
 
sub years_GET :Args(0)  {
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};

    my $years = $program->get_years;
    $c->stash->{rest} = { years => $years };
    
    return;
}


sub traits :Chained('/program/get_program') :PathPart('years') ActionClass('REST') { }

sub traits_GET :Args(0) {
  my $self = shift;
  my $c = shift;
  my $program = $c->stash->{program};

  my $traits = $program->get_traits;
  $c->stash->{rest} = { traits => $traits };

  return;
}


sub accessions :Chained('/program/get_program') :PathPart('accessions') ActionClass('REST') { } 

sub accessions_GET :Args(0) {
    my ( $self, $c ) = @_;
    my $program = $c->stash->{program};

    my $accessions = $program->get_accessions;
    $c->stash->{rest} = { accessions => $accessions };
    
    return;
}

