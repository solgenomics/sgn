package SGN::Controller::AJAX::Accession_usage;

use Moose;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub accession_usage_trials: Path('/ajax/accession_usage_trials') :Args(0){

    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');
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

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $female_parent_typeid = $c->model("Cvterm")->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
  #  my $cross_typeid = $c->model("Cvterm")->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id()
    my $accession_typeid = $c->model("Cvterm")->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $dbh = $schema->storage->dbh();

#   my $q = "SELECT DISTINCT female_parent.stock_id, female_parent.uniquename, COUNT (DISTINCT cross_id.stock_id) AS cross_number
#            FROM stock as female_parent JOIN stock_relationship ON (female_parent.stock_id=stock_relationship.subject_id) AND stock_relationship.type_id=?
#            JOIN stock AS cross_id ON (cross_id.stock_id=stock_relationship.object_id) AND cross_id.type_id=?
#            GROUP BY female_parent.stock_id ORDER BY cross_number DESC";

    my $q = "SELECT DISTINCT female_parent.stock_id, female_parent.uniquename, COUNT (DISTINCT stock_relationship.object_id) AS num_of_progenies
            FROM stock_relationship INNER JOIN stock AS check_type ON (stock_relationship.object_id = check_type.stock_id)
            INNER JOIN stock AS female_parent ON (stock_relationship.subject_id = female_parent.stock_id)
            WHERE stock_relationship.type_id = ? AND check_type.type_id = ?
            GROUP BY female_parent.stock_id ORDER BY num_of_progenies DESC";

    my $h = $dbh->prepare($q);
    $h->execute($female_parent_typeid, $accession_typeid);

    my@female_parents =();
    while (my ($female_parent_id, $female_parent_name, $num_of_progenies) = $h->fetchrow_array()){

    push @female_parents, [qq{<a href="/stock/$female_parent_id/view">$female_parent_name</a>},$num_of_progenies];
        }

    $c->stash->{rest}={data=>\@female_parents};
}

sub accession_usage_male: Path('/ajax/accession_usage_male') :Args(0){

    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $male_parent_typeid = $c->model("Cvterm")->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    #my $cross_typeid = $c->model("Cvterm")->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
    my $accession_typeid = $c->model("Cvterm")->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $dbh = $schema->storage->dbh();

    #my $q = "SELECT DISTINCT male_parent.stock_id, male_parent.uniquename, COUNT (DISTINCT cross_id.stock_id) AS cross_number
    #           FROM stock as male_parent JOIN stock_relationship ON (male_parent.stock_id=stock_relationship.subject_id) AND stock_relationship.type_id=?
    #           JOIN stock AS cross_id ON (cross_id.stock_id=stock_relationship.object_id) and cross_id.type_id=?
    #           GROUP BY male_parent.stock_id ORDER BY cross_number DESC";

    my $q = "SELECT DISTINCT male_parent.stock_id, male_parent.uniquename, COUNT (DISTINCT stock_relationship.object_id) AS num_of_progenies
            FROM stock_relationship INNER JOIN stock AS check_type ON (stock_relationship.object_id = check_type.stock_id)
            INNER JOIN stock AS male_parent ON (stock_relationship.subject_id = male_parent.stock_id)
            WHERE stock_relationship.type_id = ? AND check_type.type_id = ?
            GROUP BY male_parent.stock_id ORDER BY num_of_progenies DESC";

    my $h = $dbh->prepare($q);
    $h->execute($male_parent_typeid, $accession_typeid);

    my@male_parents =();
    while (my ($male_parent_id, $male_parent_name, $num_of_progenies) = $h->fetchrow_array()){

    push @male_parents, [qq{<a href="/stock/$male_parent_id/view">$male_parent_name</a>}, $num_of_progenies];
    }

    $c->stash->{rest}={data=>\@male_parents};
}

  1;
