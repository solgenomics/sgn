
package CXGN::GenotypeIOmain::Plugin::VCFNew;

use Moose::Role;
use Data::Dumper;

use CXGN::Genotype::SNP;

has 'file' => ( isa => 'Str',
		is => 'rw',
    );

has 'fh' => (isa => 'FileHandle',
	     is => 'rw',
    );

has 'current' => (isa => 'Int',
		  is => 'rw',
    );

has 'markers' => (isa => 'ArrayRef',
		  is => 'rw',
    );

has 'header' => (isa => 'ArrayRef',
		 is => 'rw',
    );

has 'header_information_lines' => (
    isa => 'ArrayRef',
    is => 'rw',
);

has 'observation_unit_names' => (
    isa => 'ArrayRef',
    is => 'rw',
);

sub init { 
    my $self = shift;
    my $args = shift;

    $self->file($args->{file});

    my $F;
    open($F, "<", $args->{file}) || die "Can't open file $args->{file}\n";

        my @header_info;
        my @fields;
        my @observation_unit_names;

        my @markers;
        while (<$F>) {
            chomp;
            #print STDERR Dumper $_;

            if ($_ =~ m/^##/){
                push @header_info, $_;
                next;
            }
            if ($_ =~ m/^#/){
                my $header = $_;
                @fields = split /\t/, $header;
                @observation_unit_names = @fields[9..$#fields];
                next;
            }

            my @values = split /\t/;
            if ($values[2] eq '.') {
                push @markers, $values[0]."_".$values[1];
            } else {
                push @markers, $values[2];
            }
        }

    close($F);

    $self->header(\@fields);
    $self->observation_unit_names(\@observation_unit_names);
    $self->markers(\@markers);
    $self->header_information_lines(\@header_info);

    my $fh = IO::File->new($args->{file});
    my $ignore_first_line = <$fh>;
    $self->current(1);
    $self->fh($fh);
}

sub next {
    my $self = shift;

    my $line;
    my $fh = $self->fh();
    if ( defined($line = <$fh>) ) {
        chomp($line);
        if ($line =~ m/^##/){
            return (undef, undef);
        }
        if ($line =~ m/^#/){
            return (undef, undef);
        }
        my @fields = split /\t/, $line;

        my @marker_info = @fields[ 0..8 ];
        my @values = @fields[ 9..$#fields ];
        #$self->current( $self->current()+1 );
        return (\@marker_info, \@values);
    }
    print STDERR "END\n";
    return;
}


1;
