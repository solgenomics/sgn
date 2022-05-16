

package SGN::Controller::AJAX::Search::Cross;

use Moose;
use Data::Dumper;
use CXGN::Cross;
use CXGN::Stock;
use CXGN::List::Validate;
use CXGN::List;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
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


sub search_common_parents : Path('/ajax/search/common_parents') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $accession_list_id = $c->req->param("accession_list_id");

    my $accession_list = CXGN::List->new({dbh => $schema->storage->dbh, list_id => $accession_list_id});
    my $accession_items = $accession_list->retrieve_elements($accession_list_id);
    my @accession_names = @$accession_items;

    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'uniquenames', $accession_items)->{'missing'}};

    if (scalar(@accessions_missing) > 0) {
        $c->stash->{rest} = {error_string => "The following accessions are not in the database, or are not in the database as uniquenames: ".join(',',@accessions_missing)};
        return;
    }

    my $accession_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my @results;
    foreach my $name (@accession_names) {
        my $accession_rs = $schema->resultset("Stock::Stock")->find ({ 'uniquename' => $name, 'type_id' => $accession_type_id });
        my $accession_id = $accession_rs->stock_id();
        my $stock = CXGN::Stock->new({schema => $schema, stock_id=>$accession_id});
        my $parents = $stock->get_parents();
        my $female_parent = $parents->{'mother'};
        my $male_parent = $parents->{'father'};
        push @results, [$female_parent, $male_parent, $name];
    }

    my %result_hash;
    foreach my $each_set (@results) {
        $result_hash{$each_set->[0]}{$each_set->[1]}{$each_set->[2]}++;
    }

    my @formatted_results;
    foreach my $female (keys %result_hash) {
        my $female_ref = $result_hash{$female};
        my %female_hash = %{$female_ref};
        foreach my $male (keys %female_hash) {
            my @progenies = ();
            my $progenies_string;
            my $male_ref = $female_hash{$male};
            my %male_hash = %{$male_ref};
            foreach my $progeny (keys %male_hash) {
                push @progenies, $progeny;
            }
            my $number_of_accessions = scalar @progenies;
            my @sort_progenies = sort @progenies;
            $progenies_string = join("<br>", @sort_progenies);
            push @formatted_results, [$female, $male, $number_of_accessions, $progenies_string]
        }
    }
    print STDERR "FORMATTED RESULTS =".Dumper(\@formatted_results)."\n";
    $c->stash->{rest}={ data=> \@formatted_results};

}



1;
