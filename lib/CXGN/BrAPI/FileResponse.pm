package CXGN::BrAPI::FileResponse;

use Moose;
use Data::Dumper;
use Spreadsheet::WriteExcel;
use Text::CSV;

has 'absolute_file_path' => (
	isa => 'File::Temp',
	is => 'rw',
	required => 1,
);

has 'absolute_file_uri' => (
	isa => 'Str',
	is => 'rw',
	required => 1,
);

has 'format' => (
	isa => 'Str',
	is => 'rw',
	required => 1,
);

has 'data' => (
	isa => 'ArrayRef[ArrayRef]',
	is => 'rw',
	required => 1,
);

sub BUILD {
	my $self = shift;
	my $format = $self->format;
	if ($format ne 'tsv' && $format ne 'csv' && $format ne 'xls'){
		die "format must be tsv, csv, or xls\n";
	}
}

sub get_datafiles {
	my $self = shift;
	my $format = $self->format;
	if ($format eq 'csv'){
		return $self->csv;
	}
	if ($format eq 'tsv'){
		return $self->tsv;
	}
	if ($format eq 'xls'){
		return $self->xls;
	}
}

sub csv {
    return shift->_delimited(',');
}

sub tsv {
    return shift->_delimited("\t");
}

sub _delimited {
    my ($self, $separator) = @_;
    my $data = $self->data;
    my $width = @{$data->[0] || []};
    my $csv = Text::CSV->new({binary=>1, sep_char=>$separator, eol=>"\n",
        always_quote=>$separator eq ',' ? 1 : 0}) or die Text::CSV->error_diag;
    open(my $fh, '>:encoding(UTF-8)', $self->absolute_file_path) or die "Cannot create BrAPI data file: $!";
    for my $row (@$data) {
        # Keep each existing caller's header width and preserve literal zero.
        my @values = map {defined($row->[$_]) ? $row->[$_] : ''} 0..$width-1;
        $csv->print($fh, \@values) or die $csv->error_diag;
    }
    close($fh) or die "Cannot close BrAPI data file: $!";
    return ($self->absolute_file_uri);
}

sub xls {
	my $self = shift;
	my $data_array = $self->data;
	my $file_path = $self->absolute_file_path;

	my $ss = Spreadsheet::WriteExcel->new($file_path);
	my $ws = $ss->add_worksheet();

	my $header = $data_array->[0] || [];
	for (my $line=0; $line< scalar(@$data_array); $line++) {
        for my $column (0..$#{$data_array->[$line]}) {
            my $value = $data_array->[$line][$column];
            my $name = $header->[$column] // '';
            # Design replication is a tag ("01" differs from "1"). Keep real
            # numeric measurements and the occurrence counter numeric.
            my $text = $name =~ /(?:_name|Name)$/ ||
                $name =~ /^(?:replicate|rep_number|design_rep_number|designReplicate|blockNumber|block_number)$/;
            if (defined($value) && ($line == 0 || $text || $value =~ /^=/)) {
                $ws->write_string($line, $column, $value);
            } else {
                $ws->write($line, $column, $value);
            }
        }
	}
	$ss ->close();
    $file_path->flush;
	my @datafiles = ($self->absolute_file_uri);
	return @datafiles;
}

1;
