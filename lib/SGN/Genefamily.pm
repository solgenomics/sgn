
=head1 NAME 

SGN::Genefamily - a class to deal with (currently disk-based) genefamilies for tomato annotation purposes

=head1 DESCRIPTION

The genefamilies are defined by alignment files in a subdirectory. Thus it is easy to update the family definitions, which will happen frequently over the next two months. Then the gene families will be moved to the database. So this code is only very temporary.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 METHODS

Methods in this class include:

=cut

package SGN::Genefamily;

use Moose;

use Module::Pluggable require => 1;
use namespace::autoclean;
use File::Slurp qw/slurp/;
use File::Spec::Functions;
use File::Basename qw/basename/;

=head2 accessors name()

 Usage:        $gf->name()
 Property:     the name of the gene family
 Side Effects: will be used to map to the corresponding file name
 Example:

=cut

has 'name' => (
    is       => 'rw',
#    required => 1,
   );

=head2 members

 Usage:        my @members = $gf->members()
 Desc:         retrieves the members of a genefamily. Read only.
 Property:     the members of the gene family
 Side Effects:
 Example:

=cut

has 'members' => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );

=head2 files_dir

 Usage:        my $dir = $gf->files_dir()
 Desc:         sets the directory where the genefamilies are located.
 Property:     a path
 Side Effects: used for retrieving gene family information
 Example:

=cut

has 'files_dir' => (
    is       => 'rw',
    required => 1,
   );

=head2 dataset

 Usage:        my $d = $gf->dataset()
 Desc:         under the genefamily dir (files_dir), a number of sub-dirs
               should be present, each of which represents a separate
               gene family clustering (for example, based on different
               species or different clustering parameters).
 Property:     the dataset name [string]
 Side Effects:
 Example:

=cut

has 'dataset' => (
    is       => 'rw',
    required => 1,
   );

=head2 get_alignment

 Usage:        my $alignment = $gf->get_alignment()
 Desc:         returns the alignment as a string
 Args:         none
 Side Effects: dies if the alignment has not yet been calculated.
 Example:

=cut

sub get_alignment {
    my $self = shift;
    my $file =
      catfile( $self->get_path(), "alignments", $self->name() . ".fa.align" );

    if ( !-e $file ) {
        die "No alignment file available for family " . $self->name();
    }

    return slurp($file);
}

=head2 get_fasta

 Usage:        my $fasta = $gf->get_fasta()
 Desc:         returns the sequences of a gene family as a string
               formatted in fasta.
 Ret:          fasta
 Args:         none
 Side Effects: dies if the fasta is not available.
 Example:

=cut

sub get_fasta {
    my $self = shift;
    my $file = catfile( $self->get_path(), "fasta", $self->name() . ".fa" );
    unless( -f $file ) {
        die "The fasta information for family "
          . $self->name()
          . " cannot be found";
    }
    return slurp($file);
}

=head2 get_seqs

 Usage:        my $fasta = $gf->get_seqs()
 Desc:         returns the sequences of a gene family as a list of
               Bio::Seq objects
 Ret:
 Args:         none
 Side Effects: dies if the fasta information is not available.
 Example:

=cut

sub get_seqs {
    my $self = shift;
    my $file = catfile( $self->get_path(), "fasta", $self->name() . ".fa" );
    if ( !-e $file ) {
        die "The fasta information for family "
          . $self->name()
          . " cannot be found";
    }
    my @seqs = ();
    my $io = Bio::SeqIO->new( -format => 'fasta', -file => $file );
    while ( my $seq = $io->next_seq() ) {
        push @seqs, $seq;
    }
    return @seqs;
}

=head2 get_tree

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_tree {
    my $self = shift;
    my $file =
      catfile( $self->get_path(), "/trees/" . $self->name() . ".tree" );
    if ( !-e $file ) {
        die "The tree information for family "
          . $self->name()
          . " cannot be found";
    }
    return slurp($file);
}

sub get_member_ids {
    my $self = shift;

}

=head2 get_available_datasets

 Usage:        my @ds = SGN::Genefamily->get_available_datasets($DIR)
 Desc:         a class function that returns the available datasets
 Ret:          a list of dataset names
 Args:         the $DIR where the datasets are located.
 Side Effects:
 Example:

=cut

sub get_available_datasets {
    my $class = shift;
    my $path  = shift;
    my @dirs  = map { basename($_) } grep -d, glob $self->files_dir()."/".$self->dataset()."/*";
    return @dirs;
}

sub get_path {
    my $self = shift;
    return catfile( $self->files_dir(), $self->dataset() );
}

sub table {
    my $self = shift;

    my $table;
    foreach my $p ($self->plugins()) {
	if ($self->genefamily_format() eq $p->name()) {
	    $table = $p->table();
	}
    }
    return $table;
}
    

1;
