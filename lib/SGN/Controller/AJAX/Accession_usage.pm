package SGN::Controller::AJAX::Accession_usage;

use Moose;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
use CXGN::Cross;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


sub accession_usage_trials: Path('/ajax/accession_usage_trials') :Args(0){

    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado', $sp_person_id);
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $field_layout_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();

    my $dbh = $schema->storage->dbh();

    my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename, COUNT(DISTINCT project.project_id) AS trials, COUNT(stock_relationship.subject_id)
            FROM stock JOIN stock_relationship on (stock.stock_id=stock_relationship.object_id) AND stock_relationship.type_id=?
            JOIN nd_experiment_stock ON (stock_relationship.subject_id=nd_experiment_stock.stock_id) AND nd_experiment_stock.type_id =?
            JOIN nd_experiment_project USING (nd_experiment_id)
            JOIN project USING (project_id) WHERE stock.type_id =? GROUP BY stock.stock_id ORDER BY trials DESC";

    my $h = $dbh->prepare($q);
    $h->execute($plot_of_type_id, $field_layout_type_id, $accession_type_id);

    my@accessions_trials =();
    while (my ($accession_id, $accession_name, $trial_count, $plot_count) = $h->fetchrow_array()){

        push @accessions_trials,[qq{<a href="/stock/$accession_id/view">$accession_name</a>}, $trial_count, $plot_count];
    }

    $c->stash->{rest}={data=>\@accessions_trials};

}


sub accession_usage_female: Path('/ajax/accession_usage_female') :Args(0){

    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $cross_obj = CXGN::Cross->new({schema => $schema, parent_type => 'female_parent'});
    my $data = $cross_obj->get_parents_and_numbers_of_progenies();
    my @all_female_parents = @$data;
    my @results;
    foreach my $each_female_parent (@all_female_parents) {
        my $female_id = $each_female_parent->[0];
        my $female_name = $each_female_parent->[1];
        my $number_of_progenies = $each_female_parent->[2];
        push @results, [qq{<a href="/stock/$female_id/view">$female_name</a>},$number_of_progenies];
    }
    $c->stash->{rest}={data=>\@results};

}


sub accession_usage_male: Path('/ajax/accession_usage_male') :Args(0){

    my $self = shift;
    my $c = shift;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $cross_obj = CXGN::Cross->new({schema => $schema, parent_type => 'male_parent'});
    my $data = $cross_obj->get_parents_and_numbers_of_progenies();
    my @all_male_parents = @$data;
    my @results;
    foreach my $each_male_parent (@all_male_parents) {
        my $male_id = $each_male_parent->[0];
        my $male_name = $each_male_parent->[1];
        my $number_of_progenies = $each_male_parent->[2];
        push @results, [qq{<a href="/stock/$male_id/view">$male_name</a>},$number_of_progenies];
    }
    $c->stash->{rest}={data=>\@results};


}

sub accession_usage_phenotypes: Path('/ajax/accession_usage_phenotypes') :Args(0){
    my $self = shift;
    my $c = shift;
    my $params = $c->req->params() || {};
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);

    my $round = Math::Round::Var->new(0.01);
    my $dbh = $c->dbc->dbh();
    my $display = $c->req->param('display');

    my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $rel_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $accesion_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my $limit = $c->req->param('length');
    my $offset = $c->req->param('start');

    my $limit_clause = '';
    my $offset_clause = '';
    if (defined($limit)) {
        $limit_clause = ' LIMIT '.$limit;
    }
    if (defined($offset)) {
        $offset_clause = ' OFFSET '.$offset;
    }

    my $h = $dbh->prepare("SELECT (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait,
        cvterm.cvterm_id,
        count(phenotype.value),
        to_char(avg(phenotype.value::real), 'FM999990.990'),
        to_char(max(phenotype.value::real), 'FM999990.990'),
        to_char(min(phenotype.value::real), 'FM999990.990'),
        to_char(stddev(phenotype.value::real), 'FM999990.990'),
        accession.uniquename,
        accession.stock_id,
        count(cvterm.cvterm_id) OVER() AS full_count
        FROM cvterm
            JOIN phenotype ON (cvterm_id=cvalue_id)
            JOIN nd_experiment_phenotype USING(phenotype_id)
            JOIN nd_experiment_project USING(nd_experiment_id)
            JOIN nd_experiment_stock USING(nd_experiment_id)
            JOIN stock as plot USING(stock_id)
            JOIN stock_relationship on (plot.stock_id = stock_relationship.subject_id)
            JOIN stock as accession on (accession.stock_id = stock_relationship.object_id)
            JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id
        WHERE phenotype.value~?
            AND stock_relationship.type_id=?
            AND plot.type_id=?
            AND accession.type_id=?
        GROUP BY (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, cvterm.cvterm_id, accession.stock_id, accession.uniquename
        ORDER BY cvterm.name ASC
        ,accession.uniquename DESC
        $limit_clause
        $offset_clause;");

    my $numeric_regex = '^-?[0-9]+([,.][0-9]+)?$';
    $h->execute($numeric_regex, $rel_type_id, $stock_type_id, $accesion_type_id);

    my @phenotype_data;

    my $total_count;
    while (my ($trait, $trait_id, $count, $average, $max, $min, $stddev, $stock_name, $stock_id, $full_count) = $h->fetchrow_array()) {
        $total_count = $full_count;
        if (looks_like_number($average)){
            my $cv = 0;
            if ($stddev && $average != 0) {
                $cv = ($stddev /  $average) * 100;
                $cv = $round->round($cv) . '%';
            }
            if ($average) { $average = $round->round($average); }
            if ($min) { $min = $round->round($min); }
            if ($max) { $max = $round->round($max); }
            if ($stddev) { $stddev = $round->round($stddev); }

            my @return_array = ( qq{<a href="/stock/$stock_id/view">$stock_name</a>}, qq{<a href="/cvterm/$trait_id/view">$trait</a>}, $average, $min, $max, $stddev, $cv, $count );
            push @phenotype_data, \@return_array;
        }
    }
    my $draw = $c->req->param('draw');
    if ($draw){
        $draw =~ s/\D//g; # cast to int
    }

    $c->stash->{rest} = { data => \@phenotype_data, draw => $draw, recordsTotal => $total_count,  recordsFiltered => $total_count };
}


1;
