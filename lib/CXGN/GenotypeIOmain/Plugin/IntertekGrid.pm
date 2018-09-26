
package CXGN::GenotypeIOmain::Plugin::IntertekGrid;

use Moose::Role;
use Data::Dumper;
use Text::CSV;

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

    my $csv = Text::CSV->new({ sep_char => ',' });

    my $F;
    open($F, "<", $args->{file}) || die "Can't open file $args->{file}\n";

        my $header_row = <$F>;
        my @header_info;
        if ($csv->parse($header_row)) {
            @header_info = $csv->fields();
        }
        my $unneeded_first_column = shift @header_info;
        my @fields = ($unneeded_first_column);
        my @markers = @header_info;

        my @observation_unit_names;

        while my $line (<$F>) {
            my @line_info;
            if ($csv->parse($line)) {
                @line_info = $csv->fields();
            }
            push @observation_unit_names, $line_info[0];
        }

    close($F);

    $self->header(\@fields);
    $self->observation_unit_names(\@observation_unit_names);
    $self->markers(\@markers);
    $self->header_information_lines([]);

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
