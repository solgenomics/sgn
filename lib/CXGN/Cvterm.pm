=head1 NAME

CXGN::Cvterm - a second-level object for Cvterm

Version: 1.2

=head1 DESCRIPTION

This object was re-factored from CXGN::Chado::Cvterm and moosified.
Use CXGN::Cvterm for new code. CXGN::Chado::Cvterm is deprecated


=head1 AUTHOR

Naama Menda <nm249@cornell.edu>
Lukas Mueller <lam87@cornell.edu>

=cut

package CXGN::Cvterm ;

use Moose;

use Carp;
use Data::Dumper;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use SGN::Model::Cvterm;

use base qw / CXGN::DB::Object / ;

use Try::Tiny;

=head2 accessor schema

=cut

has 'schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);

=head2 accessor cvterm
  
   Returns: Cv::Cvterm DBIx::Class object

=cut

has 'cvterm' => (
    isa => 'Bio::Chado::Schema::Result::Cv::Cvterm',
    is => 'rw',
);

=head2 accessor cvterm_id

=cut

has 'cvterm_id' => (
    isa => 'Int',
    is => 'rw',
);

=head2 accessor cv

=cut

has 'cv' => (
    isa => 'Bio::Chado::Schema::Result::Cv::Cv',
    is => 'rw',
);

=head2 accessor cv_id

=cut

has 'cv_id' => (
    isa => 'Int',
    is => 'rw',
);

=head2 accessor dbxref

=cut

has 'dbxref' => (
    isa => 'Bio::Chado::Schema::Result::General::Dbxref',
    is => 'rw',
);

=head2 accessor db

=cut

has 'db' => (
    isa => 'Bio::Chado::Schema::Result::General::Db',
    is => 'rw',
);

=head2 accessor name

=cut

has 'name' => (
    isa => 'Str',
    is => 'rw',
);

=head2 accessor definition

=cut

has 'definition' => (
    isa => 'Str',
    is => 'rw',
);

=head2 accessor is_obsolete

=cut


has 'is_obsolete' => (
    isa => 'Bool',
    is => 'rw',
    default => 0,
);


=head2 accessor accession

   refers to dbxref.accession column

=cut

has 'accession' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'is_variable' => (
    isa => 'Bool',
    is => 'rw',
    default => sub { return 0; },
    );

#########################################


sub BUILD {
    my $self = shift;

    my $cvterm;
    if ($self->cvterm_id){
        $cvterm = $self->schema()->resultset("Cv::Cvterm")->find({ cvterm_id => $self->cvterm_id() });
	
	if ($cvterm) { 
	    my $cvterm_rel_rs = $self->schema()->resultset("Cv::CvtermRelationship")->search( { subject_id => $self->cvterm_id  });
	    # require at least one parent to have a variable_of type
	    #
	    while (my $row = $cvterm_rel_rs->next()) {
		#print STDERR "ROW TYPE: ".$row->type()->name()."\n";
		if (uc($row->type()->name) eq uc('variable_of')) { 
		    $self->is_variable(1);
		}
	    }
	    
	}
    } elsif ($self->accession )   {
	my ($db_name, $dbxref_accession) = split "\:", $self->accession;

	#InterPro accessions have a namespace (db.name) that is different from the accession prefic
	if ($self->accession =~ m/^IPR*/ ) {
	    $db_name = 'InterPro';
	    $dbxref_accession= $self->accession;
	}
	my $dbxref = $self->schema()->resultset("General::Dbxref")->find(
	    {
		'db.name'      => $db_name,
		'me.accession' => $dbxref_accession,
	    },
	    { join => 'db'}
	    );

	if ($dbxref) { $cvterm = $dbxref->cvterm ; }
    }

    if (defined $cvterm) {
        $self->cvterm($cvterm);
        $self->cvterm_id($cvterm->cvterm_id);
        $self->name($cvterm->name);
	$self->definition($cvterm->definition || '' );
	$self->is_obsolete($cvterm->is_obsolete);

        $self->dbxref( $self->schema()->resultset("General::Dbxref")->find({ dbxref_id=>$cvterm->dbxref_id() }) );
	$self->cv_id( $cvterm->cv_id);
	$self->cv( $self->schema()->resultset("Cv::Cv")->find( { cv_id => $cvterm->cv_id() }) );
	$self->db( $self->dbxref->db );
	$self->accession( $self->db->name . ':' . $self->dbxref->accession );

    }
    return $self;
}

=head2 function get_image_ids

  Synopsis:     my @images = $self->get_image_ids()
  Arguments:    none
  Returns:      a list of md_image_ids
  Side effects:	none
  Description:	a method for fetching all images associated with a cvterm

=cut

sub get_image_ids {
    my $self = shift;
    my @ids;
    my $q = "SELECT image_id FROM metadata.md_image_cvterm WHERE cvterm_id=? AND obsolete = 'f' ";
    my $h = $self->schema->storage->dbh()->prepare($q);
    $h->execute($self->cvterm_id);
    while (my ($image_id) = $h->fetchrow_array()){
        push @ids, [$image_id, 'cvterm'];
    }
    return @ids;
}



=head2 function get_is_relationshiptype

 Usage: my $is_relationshiptype = $self->get_is_relationship_type
 Desc:  find the database value of teh cvterm column is_relationship_type (integer 0,1)
 Property
 Side Effects:
 Example:

=cut

sub get_is_relationshiptype {
  my $self = shift;
  return $self->cvterm->is_relationship_type;
}




=head2 synonyms

 Usage: my @synonyms = $self->synonyms()
 Desc:  Fetch all synonym names of a cvterm. use BCS cvterm->add_synonym and $cvterm->delete_synonym to manipulate cvtermsynonyms
 Ret:   an array of synonym strings
 Args:  none
 Side Effects: none
 Example:

=cut

sub synonyms {
    my $self = shift;
    my $cvterm = $self->cvterm;
    my $synonym_rs = $cvterm->cvtermsynonyms;

    my @synonyms =() ;
    while ( my $s = $synonym_rs->next ) {
	push (@synonyms, $s->synonym)  ;
    }
    return @synonyms;
}

=head2 get_single_synonym

 Usage: my $single_synonym = $self->get_single_synonym;
 Desc: a method for fetching a single synonym, based on the synonym structure. This is ugly and it would be better if we used types and type ids
 Ret:  a single synonym
 Args: none
 Side Effects:
 Example:

=cut

sub get_single_synonym {
    my $self=shift;
    my $cvterm_id= $self->cvterm_id();

    my $query=  "SELECT synonym FROM cvtermsynonym WHERE cvterm_id= ? AND synonym NOT LIKE '% %' AND synonym NOT LIKE '%\\_%' LIMIT 1";
    my $synonym_sth = $self->schema->storage->dbh->prepare($query);
    $synonym_sth->execute($cvterm_id);

    my $single_synonym = $synonym_sth->fetchrow_array();

    return $single_synonym;
}


=head2 secondary_dbxrefs

 Usage: $self->secondary_dbxrefs
 Desc:  find all secondary accessions associated with the cvterm
        These are stored in cvterm_dbxref table
 Ret:   a list of full accession strings (PO:0001234)
 Args:  none
 Side Effects: none
 Example:

=cut

sub secondary_dbxrefs {
    my $self=shift;
    my $rs  =  $self->cvterm->search_related('cvterm_dbxrefs' , { is_for_definition => 0} );
    my @list;
    while (my $r = $rs->next) {
	push @list , $r->dbxref;
    }
    return @list;
}




=head2 def_dbxrefs

 Usage: $self->def_dbxrefs
 Desc:  find all definition dbxrefs of the cvterm
        These are stored in cvterm_dbxref table
 Ret:   an array of dbxref objects
 Args:  none
 Side Effects: none
 Example:

=cut

sub def_dbxrefs {
    my $self=shift;
    my $cvterm = $self->cvterm;
    my @defs =  $cvterm->search_related('cvterm_dbxrefs' , { is_for_definition => 1} );

    return @defs || undef ;
}


=head2 cvtermprops

 Usage: $self->cvtermprops
 Desc:  find all cvtermprops (names and values) of the cvterm
        These are stored in cvtermprop table
 Ret:   hashref of arrays - key = cvtermprop type name, value = list of cvtermprop values of that type
 Args:  none
 Side Effects: none
 Example:

=cut

sub cvtermprops {
    my $self = shift;
    my $properties;
    my $cvtermprops = $self->cvterm->cvtermprops;

    while ( my $prop =  $cvtermprops->next ) {
	push @{ $properties->{$prop->type->name } } ,   $prop->value ;
    }
    return $properties;
}


########################################
sub _retrieve_cvtermprop {
    my $self = shift;
    my $type = shift;
    my @results;

    try {
        my $cvtermprop_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'trait_property')->cvterm_id();
        my $rs = $self->schema()->resultset("Cv::Cvtermprop")->search({ cvterm_id => $self->cvterm_id(), type_id => $cvtermprop_type_id }, { order_by => {-asc => 'cvtermprop_id'} });

        while (my $r = $rs->next()){
            push @results, $r->value;
        }
    } catch {
        print STDERR "Cvterm $type does not exist in this database\n";
    };

    my $res = join ',', @results;
    return $res;
}

sub _remove_cvtermprop {
    my $self = shift;
    my $type = shift;
    my $value = shift;
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'trait_property')->cvterm_id();
    my $rs = $self->schema()->resultset("Cv::Cvtermprop")->search( { type_id=>$type_id, cvterm_id => $self->cvterm_id(), value=>$value } );

    if ($rs->count() == 1) {
        $rs->first->delete();
        return 1;
    }
    elsif ($rs->count() == 0) {
        return 0;
    }
    else {
        print STDERR "Error removing cvtermprop from cvterm ".$self->cvterm_id().". Please check this manually.\n";
        return 0;
    }
}


sub _store_cvtermprop {
    my $self = shift;
    my $type = shift;
    my $value = shift;
    my $cvtermprop = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'trait_property')->name();
    my $stored_cvtermprop = $self->cvterm->create_cvtermprops({ $cvtermprop => $value});
}




__PACKAGE__->meta->make_immutable;

##########
1;########
##########
