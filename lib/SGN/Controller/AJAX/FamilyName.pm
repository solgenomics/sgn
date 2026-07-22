
=head1 NAME

SGN::Controller::AJAX::FamilyName - a REST controller class to provide the
functions for retrieving family name related info

=head1 DESCRIPTION


=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut

package SGN::Controller::AJAX::FamilyName;

use Moose;
use Try::Tiny;
use Data::Dumper;
use CXGN::FamilyName;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }
__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );


sub get_family_parents :Path('/ajax/family/parents') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $family_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $family = CXGN::FamilyName->new({schema=>$schema, family_stock_id=>$family_id});

    my $result = $family->get_family_parents();
    my @family_parents;
    foreach my $r (@$result){
        my ($female_parent_id, $female_parent_name, $female_stock_type, $female_ploidy, $male_parent_id, $male_parent_name, $male_stock_type, $male_ploidy) =@$r;
        push @family_parents, [qq{<a href="/stock/$female_parent_id/view">$female_parent_name</a>}, $female_stock_type, $female_ploidy, qq{<a href="/stock/$male_parent_id/view">$male_parent_name</a>}, $male_stock_type, $male_ploidy];
    }

    $c->stash->{rest} = { data => \@family_parents };

}


sub get_family_members_and_info :Path('/ajax/family/members_and_info') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $family_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $family = CXGN::FamilyName->new({schema=>$schema, family_stock_id=>$family_id});

    my $result = $family->get_family_members_and_info();

    my @crosses;
    foreach my $r (@$result){
        my ($cross_id, $cross_name, $cross_type, $crossing_experiment_id, $crossing_experiment_name, $progeny_number) =@$r;
        push @crosses, {
            cross_id => $cross_id,
            cross_name => $cross_name,
            cross_type => $cross_type,
            crossing_experiment_id => $crossing_experiment_id,
            crossing_experiment_name => $crossing_experiment_name,
            progeny_number => $progeny_number
        };
    }

    $c->stash->{rest} = { data => \@crosses };

}


sub get_all_progenies :Path('/ajax/family/all_progenies') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $family_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $family = CXGN::FamilyName->new({schema=>$schema, family_stock_id=>$family_id});

    my $result = $family->get_all_progenies();

    my @progenies;
    foreach my $r (@$result){
        my ($progeny_id, $progeny_name, $cross_id, $cross_name) =@$r;
        push @progenies, {
            progeny_id => $progeny_id,
            progeny_name => $progeny_name,
            cross_id => $cross_id,
            cross_name => $cross_name,
        };
    }

    $c->stash->{rest} = { data => \@progenies };

}


sub get_family_members :Path('/ajax/family/members') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $family_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $family = CXGN::FamilyName->new({schema=>$schema, family_stock_id=>$family_id});
    my $result = $family->get_family_members();

    my @crosses;
    foreach my $r (@$result){
        my ($cross_id, $cross_name) =@$r;
        push @crosses, {
            cross_id => $cross_id,
            cross_name => $cross_name,
        };
    }

    $c->stash->{rest} = { data => \@crosses };

}


sub remove_family_member : Path('/ajax/family/remove_member') : ActionClass('REST'){ }

sub remove_family_member_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $cross_id = $c->req->param('cross_id');
    my $family_id = $c->req->param('family_id');

    my $family_obj = CXGN::FamilyName->new({schema=>$schema, family_stock_id=>$family_id, cross_stock_id=>$cross_id});
    my $error = $family_obj->remove_family_member();

    my $return;
    if ($error) {
        $c->stash->{rest} = { error => "Error removing member from family: $error" };
    } else {
        $c->stash->{rest} = {success => 1};
    }

}


sub delete_family : Path('/ajax/family/delete_family') : ActionClass('REST'){ }

sub delete_family_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    if (!$c->user()){
        $c->stash->{rest} = { error => "You must be logged in to delete family" };
        $c->detach();
    }
    if (!$c->user()->check_roles("curator")) {
        $c->stash->{rest} = { error => "You do not have the correct role to delete family. Please contact us." };
        $c->detach();
    }

    my $family_id = $c->req->param("family_id");

    my $family_obj = CXGN::FamilyName->new({schema=>$schema, family_stock_id=>$family_id});
    my $error = $family_obj->delete_family();
    my $return;
    if ($error) {
        $c->stash->{rest} = { error => "Error deleting family: $error" };
    } else {
        $c->stash->{rest} = {success => 1};
    }

}


sub add_family_members_using_list : Path('/ajax/family/add_family_members_using_list') : ActionClass('REST'){ }

sub add_family_members_using_list_POST : Args(0) {

    my $self = shift;
    my $c = shift;
    my $session_id = $c->req->param("sgn_session_id");
    my $user_role;
    my $user_id;

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to add family members!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
    } else {
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to add family members!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_role = $c->user->get_object->get_user_type();
    }

    if (($user_role ne 'curator') && ($user_role ne 'submitter')) {
        $c->stash->{rest} = {error=>'Only a submitter or a curator can add family members'};
        $c->detach();
    }

    my $family_name = $c->req->param('family_name');
    my $family_id = $c->req->param('family_id');
    my $list_id = $c->req->param('list_id');
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my $list = CXGN::List->new({dbh=>$dbh, list_id=>$list_id});
    my $family_members = $list->elements();

    my $family_obj = CXGN::FamilyName->new({schema=>$schema, family_stock_id=>$family_id, family_members=>$family_members});
    my $error = $family_obj->add_family_members();
    my $return;
    $c->stash->{rest} = $return;


}



###
1;
###
