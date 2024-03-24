
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

with 'MooseX::Object::Pluggable';

use namespace::autoclean;
use Data::Dumper;
use File::Slurp qw/slurp/;
use File::Spec qw | catfile |;
use File::Spec::Functions;
use File::Basename qw/basename/;

=head2 accessors genefamily_method()

=cut

has 'genefamily_format' => (
    is => 'rw',
    isa => 'Str',
    );

has 'genefamily_defs_file' => (
    is => 'rw',
    isa => 'Str',
    default => sub { return 'genefamily_defs.txt' },
    );

has 'sequence_link' => (
    is => 'rw',
    isa => 'Str',
    default => sub { return '/tools/genefamily/seq/'; }  # add /$build/$family/$seq_id
    );


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

# =head2 members

#  Usage:        my @members = $gf->members()
#  Desc:         retrieves the members of a genefamily. Read only.
#  Property:     the members of the gene family
#  Side Effects:
#  Example:

# =cut

# has 'members' => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );

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

=head2 build

 Usage:        my $d = $gf->build()
 Desc:         under the genefamily dir (files_dir), a number of sub-dirs
               should be present, each of which represents a separate
               gene family clustering (for example, based on different
               species or different clustering parameters).
 Property:     the build name [string]
 Side Effects:
 Example:

=cut

has 'build' => (
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

    print STDERR "Retrieving fasta file $file for family ".$self->name()."\n";
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

=head1 get_sequence

=cut

sub get_sequence {
    my $self = shift;
    my $sequence = shift;

    my $file = File::Spec->catfile($self->get_path(), 'fasta', $self->name().".fa");
    
    my @seqs = ();
    my $io = Bio::SeqIO->new( -format => 'fasta', -file => $file );

    while (my $seq = $io->next_seq()) {
	print STDERR "Now checking id ".$seq->id()." against search term $sequence\n";
        if ($seq->id() eq $sequence) {
	    return [ $seq->id(), $seq->desc(), $seq->seq() ]
	}
    }
    return [];
}


=head1 get_members

=cut

sub get_members {
    my $self = shift;
    my $family = shift;

    my $defs = File::Spec->catfile($self->get_path(), $self->genefamily_defs_file());

    print STDERR "Getting member info for family $family from file $defs\n";
    
    open(my $F, "<", $defs) || die "Can't open gene families definition file at $defs";

    my @all_members;
    while(<$F>) {
	chomp;

	my ($family_name, @members) = split/\t/;

	if ($family_name eq $family) { 
	    foreach my $m (@members) {
		
		my @species_members = split/\,/, $m;
		foreach my $id (@species_members) {
		    $id = '<a href="'.$self->sequence_link()."/".$self->build()."/$family/$id".'">'.$id."</a>";
		}
		@all_members = (@all_members, @species_members);
	    }   
	}
    }
    return \@all_members;
}

=head2 get_available_builds

 Usage:        my @ds = SGN::Genefamily->get_available_builds($DIR)
 Desc:         a class function that returns the available builds
 Ret:          a list of build names
 Args:         the $DIR where the builds are located.
 Side Effects:
 Example:

=cut

sub get_available_builds {
    my $class = shift;
    my $path  = shift;
    my @dirs  = map { basename($_) } grep -d, glob $path."/*";
    return @dirs;
}

sub get_path {
    my $self = shift;
    return catfile( $self->files_dir(), $self->build() );
}

sub table {
    my $self = shift;

    my $plugin = $self->genefamily_format();
    $self->load_plugin($plugin);
    my $table = $self->get_data($self->build());

    return $table;
}



1;
