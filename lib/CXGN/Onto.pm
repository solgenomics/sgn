package CXGN::Onto;

use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use JSON::Any;
use Try::Tiny;

has 'dbh' => (
    is  => 'rw',
    required => 1,
    );
has 'dbname' => (
    is => 'rw',
    isa => 'Str',
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

      my $db = $schema->resultset("General::Db")->find_or_create(
          { name => 'COMP' });

      my $cv= $schema->resultset('Cv::Cv')->find_or_create( { name => 'composed_traits' });

      my $new_term_dbxref =  $schema->resultset("General::Dbxref")->create(
      {   db_id     => $db->get_column('db_id'),
		      accession => "SELECT nextval('postcomposed_trait_ids')"
		  });

    my $new_term= $schema->resultset("Cv::Cvterm")->create(
      { cv_id  =>$cv->cv_id(),
        name   => "SELECT string_agg(cvterm.name::text, ' ') FROM cvterm where cvterm id IN ($ids)",
        dbxref_id  => $new_term_dbxref-> dbxref_id()
      });

    my $relationship = $schema->resultset("Cv::Cvterm")->search(
  	    { name => 'contains',
      });

    foreach $component_id (@component_ids) {
      my $new_rel = $schema->resultset('Cv::CvtermRelationship')->create(
        { subject_id => $component_id
          object_id  => $new_term->cvterm_id(),
          type_id    => $relationship->cvterm_id(),
      });
    }

    return $new_term;
}


1;
