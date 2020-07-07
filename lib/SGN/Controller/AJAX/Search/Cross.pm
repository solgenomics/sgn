

package SGN::Controller::AJAX::Search::Cross;

use Moose;
use Data::Dumper;
use CXGN::Cross;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub search_cross_male_parents :Path('/ajax/search/cross_male_parents') :Args(0){
    my $self = shift;
    my $c = shift;
    my $cross_female_parent= $c->req->param("female_parent");
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $cross_male_parents = CXGN::Cross->get_cross_male_parents($schema, $cross_female_parent);

    $c->stash->{rest}={ data => $cross_male_parents};

}


sub search_cross_female_parents :Path('/ajax/search/cross_female_parents') :Args(0){
    my $self = shift;
    my $c = shift;
    my $cross_male_parent= $c->req->param("male_parent");
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $cross_female_parents = CXGN::Cross->get_cross_female_parents($schema, $cross_male_parent);

    $c->stash->{rest} = {data => $cross_female_parents};

}


sub search_crosses : Path('/ajax/search/crosses') Args(0) {
    my $self = shift;
    my $c = shift;

    my $female_parent = $c->req->param("female_parent");
    my $male_parent = $c->req->param("male_parent");
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $result = CXGN::Cross->get_cross_details($schema, $female_parent, $male_parent);
    my @cross_details;
    foreach my $r (@$result){
        my ($female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $cross_entry_id, $cross_name, $cross_type, $family_id, $family_name, $project_id, $project_name) = @$r;
        push @cross_details, [ qq{<a href="/stock/$female_parent_id/view">$female_parent_name</a>},
            qq{<a href="/stock/$male_parent_id/view">$male_parent_name</a>},
            qq{<a href="/cross/$cross_entry_id">$cross_name</a>},
            $cross_type,
            qq{<a href="/stock/$family_id/view">$family_name</a>},
            qq{<a href="/breeders/trial/$project_id">$project_name</a>},
        ];
    }

    $c->stash->{rest}={ data=> \@cross_details};

}


sub search_pedigree_male_parents :Path('/ajax/search/pedigree_male_parents') :Args(0){
    my $self = shift;
    my $c = shift;
    my $pedigree_female_parent= $c->req->param("pedigree_female_parent");
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $pedigree_male_parents = CXGN::Cross->get_pedigree_male_parents($schema, $pedigree_female_parent);

    $c->stash->{rest}={ data=> $pedigree_male_parents};

}


sub search_pedigree_female_parents :Path('/ajax/search/pedigree_female_parents') :Args(0){
    my $self = shift;
    my $c = shift;
    my $pedigree_male_parent= $c->req->param("pedigree_male_parent");
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $pedigree_female_parents = CXGN::Cross->get_pedigree_female_parents($schema, $pedigree_male_parent);

    $c->stash->{rest} = {data=> $pedigree_female_parents};

}


sub search_progenies : Path('/ajax/search/progenies') Args(0) {
    my $self = shift;
    my $c = shift;

    my $pedigree_female_parent = $c->req->param("pedigree_female_parent");
    my $pedigree_male_parent = $c->req->param("pedigree_male_parent");

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $result = CXGN::Cross->get_progeny_info($schema, $pedigree_female_parent, $pedigree_male_parent);
    my @progenies;
    foreach my $r(@$result){
        my ($female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $progeny_id, $progeny_name, $cross_type) = @$r;
        push @progenies, [ qq{<a href="/stock/$female_parent_id/view">$female_parent_name</a>},
        qq{<a href="/stock/$male_parent_id/view">$male_parent_name</a>},
        qq{<a href="/stock/$progeny_id/view">$progeny_name</a>}, $cross_type];
    }

    $c->stash->{rest}={ data=> \@progenies};

}


1;
