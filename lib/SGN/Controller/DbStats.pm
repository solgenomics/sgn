
package SGN::Controller::DbStats;

use Moose;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller' };

sub dbstats :Path('/breeders/dbstats') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $projects = CXGN::BreedersToolbox::Projects->new( { schema=> $schema } );
    my $breeding_programs = $projects->get_breeding_programs();
    #print STDERR Dumper $breeding_programs;

    $c->stash->{breeding_programs} = $breeding_programs;
    $c->stash->{template} = '/breeders_toolbox/db_stats.mas';
}

1;
