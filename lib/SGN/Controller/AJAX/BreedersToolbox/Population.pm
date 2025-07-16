
package SGN::Controller::AJAX::BreedersToolbox::Population;

use Moose;
use CXGN::Pedigree::AddPopulations;
use List::MoreUtils qw | any |;
use Data::Dumper;
use Try::Tiny;
use CXGN::Population;

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
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $session_id = $c->req->param("sgn_session_id");

    my $user_role;
    my $user_id;
    if ($session_id) {
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to create a population!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to create a population!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_role = $c->user->get_object->get_user_type();
    }

    if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
        $c->stash->{rest} = {error=>'Only a submitter or a curator can create a population'};
        $c->detach();
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);

    my $population_name = $c->req->param('population_name');
    my $member_type = $c->req->param('member_type');
    my $list_id =  $c->req->param('list_id');

    my $members;
    if ($list_id){
        my $dbh = $c->dbc->dbh;
        my $list = CXGN::List->new({dbh=>$dbh, list_id=>$list_id});
        $members = $list->elements();
    } else {
        my @input_members = $c->req->param('accessions[]');
        $members = \@input_members;
    }

    my $population_add = CXGN::Pedigree::AddPopulations->new({ schema => $schema, phenome_schema => $phenome_schema, user_id => $user_id, name => $population_name, members => $members, member_type => $member_type} );
    my $return = $population_add->add_population();

    $c->stash->{rest} = $return;
}

sub add_members_to_population :Path('/ajax/population/add_members') Args(0) {
    my $self = shift;
    my $c = shift;
    my $session_id = $c->req->param("sgn_session_id");
    my $user_role;
    my $user_id;

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to add population members!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to add population members!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_role = $c->user->get_object->get_user_type();
    }

    if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
        $c->stash->{rest} = {error=>'Only a submitter or a curator can add population members'};
        $c->detach();
    }

    my $population_name = $c->req->param('population_name');
    my $list_id = $c->req->param('list_id');
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $list = CXGN::List->new({dbh=>$dbh, list_id=>$list_id});
    my $members = $list->elements();

    my $population_add = CXGN::Pedigree::AddPopulations->new({ schema => $schema, phenome_schema => $phenome_schema, name => $population_name, members => $members, user_id => $user_id });
    my $return = $population_add->add_members();

    $c->stash->{rest} = $return;
}

sub delete_population :Path('/ajax/population/delete') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $session_id = $c->req->param("sgn_session_id");
    my $user_role;
    my $user_id;

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to delete a population!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to delete a population!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'curator') {
        $c->stash->{rest} = {error=>'Only a curator can delete a population'};
        $c->detach();
    }

    my $population_id = $c->req->param('population_id');
    my $population_name = $c->req->param('population_name');
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $population_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();

    my $population = CXGN::Population->new( { schema => $schema, , population_stock_id => $population_id });

    if (!$population->population_stock_id()) {
        $c->stash->{rest} = { error => "No such population exists. Cannot delete." };
        return;
    }

    my $error = $population->delete_population();

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
    my $session_id = $c->req->param("sgn_session_id");
    my $user_role;
    my $user_id;

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to remove an accession from population!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to remove an accession from population!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_role = $c->user->get_object->get_user_type();
    }

    if ($user_role ne 'curator') {
        $c->stash->{rest} = {error=>'Only a curator can remove an accession from population'};
        $c->detach();
    }

    my $stock_relationship_id = $c->req->param('stock_relationship_id');
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $member_relationship = CXGN::Population->new( { schema => $schema, , stock_relationship_id => $stock_relationship_id });
    my $error = $member_relationship->delete_population_member();

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
