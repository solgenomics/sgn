
package SGN::Controller::AJAX::BreedersToolbox::Population;

use Moose;
use CXGN::Pedigree::AddPopulations;
use List::MoreUtils qw | any |;
use Data::Dumper;
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );

   has 'schema' => (
   		 is       => 'rw',
   		 isa      => 'DBIx::Class::Schema',
   		 lazy_build => 1,
   		);

sub create_population :Path('/ajax/population/new') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    if(!$c->user){
        $c->stash->{rest} = { error => "You must be logged in to add a population" };
        $c->detach;
    }

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
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $dbh = $c->dbc->dbh;
    my $list = CXGN::List->new({dbh=>$dbh, list_id=>$accession_list_id});
    my $members = $list->elements();

    my $population_add = CXGN::Pedigree::AddPopulations->new({ schema => $schema, name => $population_name, members => $members });
    my $return = $population_add->add_accessions();

    $c->stash->{rest} = $return;
}

sub delete_population :Path('/ajax/population/delete') Args(0) {
    my $self = shift;
    my $c = shift;

    my $population_id = $c->req->param('population_id');
    my $population_name = $c->req->param('population_name');
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $population_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();

    my $error;
    try {
        my $population = $schema->resultset("Stock::Stock")->find({
            stock_id => $population_id,
            type_id => $population_cvterm_id,
        });
        $population->delete;
        #On cascade should delete all relationships to population
    }
    catch {
        $error =  $_;
    };
    my $return;
    if ($error) {
        print STDERR "Error deleting population $population_name: $error\n";
        $return = { error => "Error deleting population $population_name: $error" };
    } else {
        print STDERR "population $population_name deleted successfully\n";
        $return = { success => "Population $population_name deleted successfully!" };
    }

    $c->stash->{rest} = $return;
}

sub remove_population_member :Path('/ajax/population/remove_member') Args(0) {
    my $self = shift;
    my $c = shift;

    if(!$c->user){
        $c->stash->{rest} = { error => "You must be logged in to remove an accession from population" };
        $c->detach;
    }

    my $stock_relationship_id = $c->req->param('stock_relationship_id');
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $error;
    try {
        my $stock_relationship = $schema->resultset("Stock::StockRelationship")->find({
            stock_relationship_id => $stock_relationship_id,
        });
        $stock_relationship->delete;
        #On cascade should delete all relationships to population
    }
    catch {
        $error =  $_;
    };
    my $return;
    if ($error) {
        print STDERR "Error removing member from population: $error\n";
        $return = { error => "Error removing member from population: $error" };
    } else {
        print STDERR "Member removed successfully\n";
        $return = { success => "Removed successfully!" };
    }

    $c->stash->{rest} = $return;
}

1;
