package CXGN::Onto;

use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use JSON::Any;
use Try::Tiny;
use Bio::Chado::Schema;

has 'dbh' => (
    is  => 'rw',
    required => 1,
    );
has 'dbname' => (
    is => 'rw',
    isa => 'Str',
    );
has 'schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    );

=head2 get_terms

parameters: namespace

returns: terms in namespace

Side Effects: none

=cut

sub get_terms {
      my $self = shift;
      my $cv_type = shift;

      my $query = "SELECT cvterm_id, (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS name
                  FROM cv
                  JOIN cvprop ON(cv.cv_id = cvprop.cv_id AND cvprop.type_id IN (SELECT cvterm_id from cvterm where cvterm.name = ?))
                  JOIN cvterm ON(cvprop.cv_id = cvterm.cv_id)
                  JOIN dbxref USING(dbxref_id)
                  JOIN db USING(db_id)
                  LEFT JOIN cvterm_relationship is_subject ON cvterm.cvterm_id = is_subject.subject_id
                  LEFT JOIN cvterm_relationship is_object ON cvterm.cvterm_id = is_object.object_id
                  WHERE is_object.object_id IS NULL AND is_subject.subject_id IS NOT NULL
                  GROUP BY 1,2
                  ORDER BY 2,1";

      my $h = $self->dbh->prepare($query);
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

      my $schema = $self->schema();

      my $db = $schema->resultset("General::Db")->find_or_create(
          { name => 'COMP' });

      my $cv= $schema->resultset('Cv::Cv')->find_or_create( { name => 'composed_trait' });

      my $accession_query = "SELECT nextval('composed_trait_ids')";
      my $h = $self->dbh->prepare($accession_query);
      $h->execute();
      my $accession = $h->fetchrow_array();

      #print STDERR "New trait accession = $accession and name = $name\n";

      my $compose_query = " SELECT string_agg(ordered_components.name::text, ' '),
                                  string_agg(ordered_components.synonym::text, '_')
                            FROM (
                              SELECT cvterm.name,
                                    synonym.synonym,
                                    cv.cv_id
                              FROM cvterm
                              LEFT JOIN LATERAL (
                                SELECT length(substring(synonym from '\"(.+)\"')) AS length,
                                      substring(synonym from '\"(.+)\"') AS synonym
                                FROM cvtermsynonym
                                WHERE cvterm.cvterm_id = cvtermsynonym.cvterm_id
                                GROUP by 2
                                ORDER BY 1
                                LIMIT 1
                              ) synonym on true
                              JOIN cv USING(cv_id)
                              JOIN cvprop ON(cv.cv_id = cvprop.cv_id)
                              JOIN cvterm type ON(cvprop.type_id = type.cvterm_id)
                              WHERE cvterm.cvterm_id IN (@{[join',', ('?') x @ids]})
                              ORDER BY (
                                case when type.name = 'entity_ontology' then 1
                                    when type.name = 'quality_ontology' then 2
                                    when type.name = 'unit_ontology' then 3
                                    when type.name = 'time_ontology' then 4
                                end
                              )
                            ) ordered_components";

      $h = $self->dbh->prepare($compose_query);
      $h->execute(@ids);
      my ($name, $synonym) = $h->fetchrow_array();

      print STDERR "New trait name = $name and synonym = $synonym\n";

      my $new_term_dbxref =  $schema->resultset("General::Dbxref")->create(
      {   db_id     => $db->get_column('db_id'),
		      accession => $accession
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

      my $new_term_synonym= $schema->resultset("Cv::Cvtermsynonym")->create(
        { cvterm_id  =>$new_term->cvterm_id(),
          synonym   => $synonym
        });

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

    return $new_term->cvterm_id();
}


1;
