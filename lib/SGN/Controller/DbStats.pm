
package SGN::Controller::DbStats;

use Moose;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller' };

sub dbstats :Path('/breeders/dbstats') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $projects = CXGN::BreedersToolbox::Projects->new( { schema=> $schema } );
    my $breeding_programs = $projects->get_breeding_programs();
    #print STDERR Dumper $breeding_programs;

    $c->stash->{breeding_programs} = $breeding_programs;
    $c->stash->{template} = '/breeders_toolbox/db_stats.mas';
}

sub recent_activity :Path('/dbstats/recent_activity') Args(0) {
    my $self = shift;
    my $c = shift;
    
    $c->stash->{template} = '/dbstats/recent_activity.mas';
}

    

1;
