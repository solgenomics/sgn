package CXGN::Onto;

use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use JSON::Any;
use Try::Tiny;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;

has 'schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
    );

=head2 get_terms

parameters: namespace

returns: terms in namespace

Side Effects: none

=cut

sub get_terms {
      my $self = shift;
      my $cv_id = shift;

      my $query = "SELECT cvterm_id, (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS name
                  FROM cvterm
                  JOIN dbxref USING(dbxref_id)
                  JOIN db USING(db_id)
                  LEFT JOIN cvterm_relationship is_subject ON cvterm.cvterm_id = is_subject.subject_id
                  LEFT JOIN cvterm_relationship is_object ON cvterm.cvterm_id = is_object.object_id
                  WHERE cv_id = ? AND is_object.object_id IS NULL AND is_subject.subject_id IS NOT NULL
                  GROUP BY 1,2
                  ORDER BY 2,1";

      my $h = $self->schema->storage->dbh->prepare($query);
      $h->execute($cv_id);

      my @results;
      while (my ($id, $name) = $h->fetchrow_array()) {
        push @results, [$id, $name];
      }

      return @results;
}

sub get_root_nodes {
      my $self = shift;
      my $cv_type = shift;

      my $query = "SELECT cv.cv_id, (((db.name::text || ':'::text) || dbxref.accession::text) || ' '::text) || cvterm.name AS name
                    FROM cv
                    JOIN cvprop ON(cv.cv_id = cvprop.cv_id AND cvprop.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = ?))
                    JOIN cvterm on(cvprop.cv_id = cvterm.cv_id)
                    JOIN dbxref USING(dbxref_id)
                    JOIN db USING(db_id)
                    LEFT JOIN cvterm_relationship ON(cvterm.cvterm_id=cvterm_relationship.subject_id)
                    WHERE cvterm_relationship.subject_id IS NULL AND cvterm.is_obsolete= 0 AND cvterm.is_relationshiptype = 0";

      my $h = $self->schema->storage->dbh->prepare($query);
      $h->execute($cv_type);

      my @results;
      while (my ($id, $name) = $h->fetchrow_array()) {
        push @results, [$id, $name];
      }

      return @results;
}


sub store_composed_term {
    my $self = shift;
    my $new_trait_names = shift;
    #print STDERR Dumper $new_trait_names;

    my $schema = $self->schema();
    my $dbh = $schema->storage->dbh;

    my $contains_relationship = $schema->resultset("Cv::Cvterm")->find({ name => 'contains' });
    my $variable_relationship = $schema->resultset("Cv::Cvterm")->find({ name => 'VARIABLE_OF' });

    my @new_terms;
    foreach my $name (sort keys %$new_trait_names){
        my $ids = $new_trait_names->{$name};
        my @component_ids = split ',', $ids;

        if (scalar(@component_ids)<2){
            die "Should not save postcomposed term with less than 2 components\n";
        }

        my $existing_trait_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, \@component_ids);
        if ($existing_trait_id) {
            print STDERR "Skipping: This trait already exists $name with the following component_ids".Dumper(\@component_ids)."\n";
            next;
        }

        my $db = $schema->resultset("General::Db")->find_or_create({ name => 'COMP' });
        my $cv= $schema->resultset('Cv::Cv')->find_or_create( { name => 'composed_trait' });

        my $accession_query = "SELECT nextval('composed_trait_ids')";
        my $h = $dbh->prepare($accession_query);
        $h->execute();
        my $accession = $h->fetchrow_array();

      my $new_term_dbxref =  $schema->resultset("General::Dbxref")->create(
      {   db_id     => $db->get_column('db_id'),
		      accession => sprintf("%07d",$accession)
		  });

      my $parent_term= $schema->resultset("Cv::Cvterm")->find(
        { cv_id  =>$cv->cv_id(),
          name   => 'Composed traits',
      });

    #print STDERR "Parent cvterm_id = " . $parent_term->cvterm_id();

    my $new_term = $schema->resultset('Cv::Cvterm')->find({ name=>$name });
    if ($new_term){
        print STDERR "Cvterm with name $name already exists... so components must be new\n";
    } else {
        $new_term= $schema->resultset("Cv::Cvterm")->create({
            cv_id  =>$cv->cv_id(),
            name   => $name,
            dbxref_id  => $new_term_dbxref-> dbxref_id()
        });
    }


    #print STDERR "New term cvterm_id = " . $new_term->cvterm_id();

        my $variable_rel = $schema->resultset('Cv::CvtermRelationship')->create({
            subject_id => $new_term->cvterm_id(),
            object_id  => $parent_term->cvterm_id(),
            type_id    => $variable_relationship->cvterm_id()
        });

        foreach my $component_id (@component_ids) {
            my $contains_rel = $schema->resultset('Cv::CvtermRelationship')->create({
                subject_id => $component_id,
                object_id  => $new_term->cvterm_id(),
                type_id    => $contains_relationship->cvterm_id()
            });
        }

        push @new_terms, [$new_term->cvterm_id, $new_term->name().'|COMP:'.sprintf("%07d",$accession)];
    }

    #Takes long on cassavabase.. instead the materialized view is refreshed automatically in a background ajax process.
    #my $refresh1 = "REFRESH MATERIALIZED VIEW traits";
    #my $h = $dbh->prepare($refresh1);
    #$h->execute();

    #my $refresh2 = "REFRESH MATERIALIZED VIEW trait_componentsXtraits";
    #$h = $dbh->prepare($refresh2);
    #$h->execute();

    return \@new_terms;
}


1;
