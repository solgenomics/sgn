package SGN::Controller::AJAX::Accession_usage;

use Moose;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


  sub accession_usage: Path('/ajax/accession_usage') :Args(0){

      my $self = shift;
      my $c = shift;

      my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');
      my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

      my $dbh = $schema->storage->dbh();

      my $q = "SELECT DISTINCT accession.stock_id, accession.uniquename, COUNT (DISTINCT project.project_id) AS trials
               FROM stock as accession JOIN stock_relationship on (accession.stock_id=stock_relationship.object_id)
               JOIN stock as plot on (plot.stock_id=stock_relationship.subject_id) JOIN nd_experiment_stock
               ON (plot.stock_id=nd_experiment_stock.stock_id) JOIN nd_experiment_project USING (nd_experiment_id)
               JOIN project USING (project_id) WHERE accession.type_id =? GROUP BY accession.stock_id ORDER BY trials DESC LIMIT 100";

      my $h = $dbh->prepare($q);
      $h->execute($accession_type_id);

      my@accessions_trials =();
      while (my ($accession_id, $accession_name, $trial_count) = $h->fetchrow_array()){

        push @accessions_trials,[qq{<a href="/stock/$accession_id/view">$accession_name</a}, $trial_count];
      }

      $c->stash->{rest}={data=>\@accessions_trials};

    }


  1;
