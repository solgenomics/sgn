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
      my $namespaces = shift;
      print STDERR "Namespaces in CXGN:Onto = $namespaces\n";

      my $query = "SELECT cvterm_id, (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS name
                  FROM cvterm
                  JOIN dbxref USING(dbxref_id)
                  JOIN db ON(dbxref.db_id = db.db_id AND db.name = ?)
                  LEFT JOIN cvterm_relationship is_subject ON cvterm.cvterm_id = is_subject.subject_id
                  LEFT JOIN cvterm_relationship is_object ON cvterm.cvterm_id = is_object.object_id
                  WHERE is_object.object_id IS NULL AND is_subject.subject_id IS NOT NULL
                  ORDER BY 2,1";

      my $h = $self->dbh->prepare($query);
      $h->execute($namespaces);

      my @results;
      while (my ($id, $name) = $h->fetchrow_array()) {
        push @results, [$id, $name];
      }

      return @results;
}


sub compose_trait {
      my $self = shift;
      my $ids = shift;
      print STDERR "Ids for composing in CXGN:Onto = $ids\n";

      my $schema = $self->schema();

      my $db = $schema->resultset("General::Db")->find_or_create(
          { name => 'COMP' });

      my $cv= $schema->resultset('Cv::Cv')->find_or_create( { name => 'composed_traits' });

      my $accession_query = "SELECT nextval('postcomposed_trait_ids')";
      my $h = $self->dbh->prepare($accession_query);
      $h->execute();
      my $accession = $h->fetchrow_array();
    
      my $name = "Postcomposed trait " . $accession;
      print STDERR "New trait accession = $accession and name = $name\n";

      my $new_term_dbxref =  $schema->resultset("General::Dbxref")->create(
      {   db_id     => $db->get_column('db_id'),
		      accession => $accession
		  });

    my $parent_term= $schema->resultset("Cv::Cvterm")->find_or_create(
        { cv_id  =>$cv->cv_id(),
          name   => 'Composed traits',
      });

    my $new_term= $schema->resultset("Cv::Cvterm")->find_or_create(
      { cv_id  =>$cv->cv_id(),
        name   => $name,
        dbxref_id  => $new_term_dbxref-> dbxref_id()
      });

    #print STDERR "dumper new term:" . $new_term->cvterm_id();

    my $isa_relationship = $schema->resultset("Cv::Cvterm")->find(
    	  { name => 'is_a',
      });

    my $contains_relationship = $schema->resultset("Cv::Cvterm")->find(
        { name => 'contains',
      });

    #print STDERR "dumper relationship:" . $contains_relationship->cvterm_id();
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
