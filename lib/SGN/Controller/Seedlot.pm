
package SGN::Controller::Seedlot;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

use CXGN::Stock::Seedlot;

sub seedlots :Path('/breeders/seedlots') :Args(0) { 
    my $self = shift;
    my $c = shift;

    $c->stash->{timestamp} = localtime();
    $c->stash->{template} = '/breeders_toolbox/seedlots.mas';

}

sub seedlot_detail :Path('/breeders/seedlot') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $seedlot_id = shift;

    my $sl = CXGN::Stock::Seedlot->new(
        schema => $c->dbic_schema("Bio::Chado::Schema"),
        seedlot_id => $seedlot_id
    );
    my $accessions = $sl->accessions();
    my $accessions_html = '';
    foreach (@$accessions){
        $accessions_html .= '<a href="/stock/'.$_->[0].'/view">'.$_->[1].'</a> ';
    }
    $c->stash->{seedlot_id} = $seedlot_id;
    $c->stash->{uniquename} = $sl->uniquename();
    $c->stash->{location_code} = $sl->location_code();
    $c->stash->{organization_name} = $sl->organization_name();
    $c->stash->{population_name} = $sl->population_name();
    $c->stash->{accessions} = $accessions_html;
    $c->stash->{current_count} = $sl->current_count();
    $c->stash->{timestamp} = localtime();
    $c->stash->{breeding_program_name} = $sl->breeding_program_name();
    $c->stash->{template} = '/breeders_toolbox/seedlot_details.mas';
}

1;
