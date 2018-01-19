
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
        $accessions_html .= '<a href="/stock/'.$_->[0].'/view">'.$_->[1].'</a> (accession)';
    }
    my $crosses = $sl->crosses();
    my $crosses_html = '';
    foreach (@$crosses){
        $crosses_html .= '<a href="/cross/'.$_->[0].'">'.$_->[1].'</a> (cross)';
    }
    my $populations = $sl->populations();
    my $populations_html = '';
    foreach (@$populations){
        $populations_html .= '<a href="/stock/'.$_->[0].'/view">'.$_->[1].'</a> ';
    }
    $c->stash->{seedlot_id} = $seedlot_id;
    $c->stash->{uniquename} = $sl->uniquename();
    $c->stash->{organization_name} = $sl->organization_name();
    $c->stash->{population_name} = $populations_html;
    $c->stash->{content_html} = $accessions_html ? $accessions_html : $crosses_html;
    $c->stash->{current_count} = $sl->get_current_count_property();
    $c->stash->{timestamp} = localtime();
    $c->stash->{template} = '/breeders_toolbox/seedlot_details.mas';
}

1;
