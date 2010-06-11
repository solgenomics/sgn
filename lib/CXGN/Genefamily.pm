

package CXGN::Genefamily;

use Moose;
use File::Slurp qw/slurp/;

has 'name' => (is=>'rw', required=>1);

has 'members' => (is=>'rw', isa=>'ArrayRef', default=>sub { [] });

has 'files_dir' => (is=>'rw');

sub get_alignment {
    my $self = shift;
    my $file = $self->files_dir()."/alignments/family_".$self->name().".fa.align";
    return slurp($file);
}

sub get_fasta {
    my $self = shift;
    my $file = $self->files_dir()."/fasta/".$self->name().".fa";
    return slurp($file);
}

sub get_member_ids { 
    my $self = shift;
    

}

return 1;
