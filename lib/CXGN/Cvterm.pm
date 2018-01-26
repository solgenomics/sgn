=head1 NAME

CXGN::Cvterm - a second-level object for Cvterm

Version: 1.0

=head1 DESCRIPTION

This object was re-factored from CXGN::Chado::Cvterm and moosified.


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

has 'schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);

has 'cvterm' => (
    isa => 'Bio::Chado::Schema::Result::Cv::Cvterm',
    is => 'rw',
);

has 'cvterm_id' => (
    isa => 'Maybe[Int]',
    is => 'rw',
);

has 'cv' => (
    isa => 'Bio::Chado::Schema::Result::Cv::Cv',
    is => 'rw',
);

has 'dbxref' => (
    isa => 'Bio::Chado::Schema::Result::General::Dbxref',
    is => 'rw',
);

has 'name' => (
    isa => 'Str',
    is => 'rw',
);

has 'definition' => (
    isa => 'Str',
    is => 'rw',
);


has 'is_obsolete' => (
    isa => 'Bool',
    is => 'rw',
    default => 0,
);

has 'cvtermprops' => (
    isa => 'Maybe[ArrayRef[Str]]',
    is => 'rw'
);


sub BUILD {
    my $self = shift;

    my $cvterm;
    if ($self->cvterm_id){
        $cvterm = $self->schema()->resultset("Cv::Cvterm")->find({ cvterm_id => $self->cvterm_id() });
    }
    if (defined $cvterm) {
        $self->cvterm($cvterm);
        $self->cvterm_id($cvterm->cvterm_id);
        $self->name($cvterm->name);
        $self->definition($cvterm->definition);
        $self->description($cvterm->description() || '');
        $self->dbxref_id($cvterm->type_id);
        $self->dbxref( $self->schema()->resultset("General::Dbxref")->find({ dbxref_id=>$self->dbxref_id() }) );
        $self->is_obsolete($cvterm->is_obsolete);
        #$self->organization_name($self->_retrieve_cvtermprop(''));
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
    my $ids = $self->schema()->storage->dbh->selectcol_arrayref
	( "SELECT image_id FROM metadata.md_image_cvterm WHERE cvterm_id=? AND obsolete = 'f' ",
	  undef,
	  $self->cvterm_id
        );
    return @$ids;
}



sub _retrieve_cvtermprop {
    my $self = shift;
    my $type = shift;
    my @results;

    try {
        my $cvtermprop_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'cvterm_property')->cvterm_id();
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
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'cvterm_property')->cvterm_id();
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
    my $cvtermprop = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'cvterm_property')->name();
    my $stored_cvtermprop = $self->cvterm->create_cvtermprops({ $cvtermprop => $value});
}




__PACKAGE__->meta->make_immutable;

##########
1;########
##########
