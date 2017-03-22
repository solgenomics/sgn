package CXGN::BrAPI::FileResponse;

use Moose;
use Data::Dumper;
use Spreadsheet::WriteExcel;

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
	my $self = shift;
	my $data_array = $self->data;
	my $file_path = $self->absolute_file_path;

	my $num_col = scalar(@{$data_array->[0]});
	open(my $fh, ">", $file_path);
		print STDERR $file_path."\n";
		foreach my $cols (@$data_array){
			my $step = 1;
			for(my $i=0; $i<$num_col; $i++) {
				if ($cols->[$i]) {
					print $fh "\"$cols->[$i]\"";
				} else {
					print $fh "\"\"";
				}
				if ($step < $num_col) {
					print $fh ",";
				}
				$step++;
			}
			print $fh "\n";
		}
	close $fh;
	my @datafiles = ($self->absolute_file_uri);
	return @datafiles;
}

sub tsv {
	my $self = shift;
	my $data_array = $self->data;
	my $file_path = $self->absolute_file_path;

	my $num_col = scalar(@{$data_array->[0]});
	open(my $fh, ">", $file_path);
		print STDERR $file_path."\n";
		foreach my $cols (@$data_array){
			my $step = 1;
			for(my $i=0; $i<$num_col; $i++) {
				if ($cols->[$i]) {
					print $fh $cols->[$i];
				} else {
					print $fh "";
				}
				if ($step < $num_col) {
					print $fh "\t";
				}
				$step++;
			}
			print $fh "\n";
		}
	close $fh;
	my @datafiles = ($self->absolute_file_uri);
	return @datafiles;
}

sub xls {
	my $self = shift;
	my $data_array = $self->data;
	my $file_path = $self->absolute_file_path;

	my $ss = Spreadsheet::WriteExcel->new($file_path);
	my $ws = $ss->add_worksheet();

	for (my $line=0; $line< scalar(@$data_array); $line++) {
		$ws->write_row($line, 0, $data_array->[$line]);
	}
	$ss ->close();
	my @datafiles = ($self->absolute_file_uri);
	return @datafiles;
}

1;
