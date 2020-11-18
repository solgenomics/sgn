
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


sub get_family_members :Path('/ajax/family/members') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $family_id = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $family = CXGN::FamilyName->new({schema=>$schema, family_stock_id=>$family_id});

    my $result = $family->get_family_members();

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


###
1;
###
