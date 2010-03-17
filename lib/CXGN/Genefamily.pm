

package CXGN::Genefamily;

use Moose;

has 'name' => (is=>'rw', required=>1);

has 'members' => (is=>'rw', isa=>'ArrayRef', default=>sub { [] });

has 'files_dir' => (is=>'rw');

sub get_alignment { 
    my $self = shift;

    my $a = "";
    
    my $file = $self->files_dir()."/alignments/family_".$self->name().".fa.align";
    open (my $F, "<$file") || die "Can't open ".$file;
    while (<$F>) { 
	$a .= $_;
    }
    close($F);
    return $a;
}

sub get_fasta { 
    my $self = shift;
    
    my $file = $self->files_dir()."/fasta/".$self->name().".fa";
    open (my $F, "<$file") || die "Can't open ".$file;
    while (<$F>) { 
	$a .= $_;
    }
    close($F);
    return $a;
}

sub get_member_ids { 
    my $self = shift;
    

}

return 1;
