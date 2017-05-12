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


sub compose_trait {
      my $self = shift;
      my $ids = shift;

      my @ids = split(',', $ids);
      print STDERR "Ids for composing in CXGN:Onto = $ids\n";
      if (scalar @ids < 2) {
        die "Can't create a new trait from fewer than 2 components.\n";
      }

      my $schema = $self->schema();
      my $dbh = $schema->storage->dbh;

      my $existing_trait_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, \@ids);
      if ($existing_trait_id) {
        die "This trait already exists.\n";
      }

      my $db = $schema->resultset("General::Db")->find_or_create(
          { name => 'COMP' });

      my $cv= $schema->resultset('Cv::Cv')->find_or_create( { name => 'composed_trait' });

      my $accession_query = "SELECT nextval('composed_trait_ids')";
      my $h = $dbh->prepare($accession_query);
      $h->execute();
      my $accession = $h->fetchrow_array();

      # check for minimum of OBJ, ATTR, METH, UNIT OR TRAIT + TIME

      #print STDERR "New trait accession = $accession and name = $name\n";

      my $compose_query = " SELECT string_agg(ordered_components.name::text, '|'),
                                  string_agg(ordered_components.synonym::text, '_')
                                  FROM (
                                    SELECT cvterm.name,
                                    CASE WHEN synonym IS NULL THEN cvterm.name
                                      WHEN substring(synonym from '\"(.+)\"') IS NULL THEN synonym
                                      ELSE substring(synonym from '\"(.+)\"')
                                    END AS synonym,
                                          cv.cv_id
                                    FROM cvterm
                                    LEFT JOIN cvtermsynonym syn ON (cvterm.cvterm_id = syn.cvterm_id AND syn.type_id = (SELECT cvterm_id from cvterm where name = 'EXACT'))
                                    JOIN cv USING(cv_id)
                                    JOIN cvprop ON(cv.cv_id = cvprop.cv_id)
                                    JOIN cvterm type ON(cvprop.type_id = type.cvterm_id)
                                    WHERE cvterm.cvterm_id IN (@{[join',', ('?') x @ids]})
                                    ORDER BY (
                                      case when type.name = 'object_ontology' then 1
                                          when type.name = 'attribute_ontology' then 2
                                          when type.name = 'method_ontology' then 3
                                          when type.name = 'unit_ontology' then 4
                                          when type.name = 'trait_ontology' then 5
                                          when type.name = 'time_ontology' then 6
                                      end
                                    )
                                  ) ordered_components";

      print STDERR "Compose query = $compose_query\n";

      $h = $dbh->prepare($compose_query);
      $h->execute(@ids);
      my ($name, $synonym) = $h->fetchrow_array();

      print STDERR "New trait name = $name and synonym = $synonym\n";

      my $new_term_dbxref =  $schema->resultset("General::Dbxref")->create(
      {   db_id     => $db->get_column('db_id'),
		      accession => sprintf("%07d",$accession)
		  });

      my $parent_term= $schema->resultset("Cv::Cvterm")->find(
        { cv_id  =>$cv->cv_id(),
          name   => 'Composed traits',
      });

    #print STDERR "Parent cvterm_id = " . $parent_term->cvterm_id();

    my $new_term= $schema->resultset("Cv::Cvterm")->create(
      { cv_id  =>$cv->cv_id(),
        name   => $name,
        dbxref_id  => $new_term_dbxref-> dbxref_id()
      });

      $new_term->add_synonym($synonym, { synonym_type => 'EXACT' , autocreate => 1});  #adds synonym with type

    #print STDERR "New term cvterm_id = " . $new_term->cvterm_id();

    my $isa_relationship = $schema->resultset("Cv::Cvterm")->find(
    	  { name => 'is_a',
      });

    #print STDERR "Is a relationship cvterm_id = " . $isa_relationship->cvterm_id();

    my $contains_relationship = $schema->resultset("Cv::Cvterm")->find(
        { name => 'contains',
      });

    #print STDERR "Contains relationship cvterm_id = " . $contains_relationship->cvterm_id();

    my @component_ids = split ',', $ids;

    my $isa_rel = $schema->resultset('Cv::CvtermRelationship')->create(
      { subject_id => $new_term->cvterm_id(),
        object_id  => $parent_term->cvterm_id(),
        type_id    => $isa_relationship->cvterm_id()
    });

    foreach my $component_id (@component_ids) {
      my $contains_rel = $schema->resultset('Cv::CvtermRelationship')->create(
        { subject_id => $component_id,
          object_id  => $new_term->cvterm_id(),
          type_id    => $contains_relationship->cvterm_id()
      });
    }

    my $refresh1 = "REFRESH MATERIALIZED VIEW traits";
    $h = $dbh->prepare($refresh1);
    $h->execute();

    my $refresh2 = "REFRESH MATERIALIZED VIEW trait_componentsXtraits";
    $h = $dbh->prepare($refresh2);
    $h->execute();

    return { cvterm_id => $new_term->cvterm_id(),
            name => $new_term->name().'|COMP:'.sprintf("%07d",$accession)
        };
}


1;
