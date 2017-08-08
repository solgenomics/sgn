
package SGN::Controller::AJAX::BreedersToolbox::Population;

use Moose;
use CXGN::Pedigree::AddPopulations;
use List::MoreUtils qw | any |;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

   has 'schema' => (
   		 is       => 'rw',
   		 isa      => 'DBIx::Class::Schema',
   		 lazy_build => 1,
   		);

sub create_population :Path('/ajax/population/new') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $population_name = $c->req->param('population_name');
    my $accession_list_id = $c->req->param('accession_list_id');
    my $members;
    if ($accession_list_id){
        my $dbh = $c->dbc->dbh;
        my $list = CXGN::List->new({dbh=>$dbh, list_id=>$accession_list_id});
        $members = $list->elements();
    } else {
        my @input_members = $c->req->param('accessions[]');
        $members = \@input_members;
    }

    my $population_add = CXGN::Pedigree::AddPopulations->new({ schema => $schema, name => $population_name, members => $members} );
    my $return = $population_add->add_population();

    $c->stash->{rest} = $return;
}

sub add_accessions_to_population :Path('/ajax/population/add_accessions') Args(0) {
    my $self = shift;
    my $c = shift;

    my $population_name = $c->req->param('population_name');
    my $accession_list_id = $c->req->param('accession_list_id');
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $c->dbc->dbh;
    my $list = CXGN::List->new({dbh=>$dbh, list_id=>$accession_list_id});
    my $members = $list->elements();

    my $population_add = CXGN::Pedigree::AddPopulations->new({ schema => $schema, name => $population_name, members => $members });
    my $return = $population_add->add_accessions();

    $c->stash->{rest} = $return;
}

1;
