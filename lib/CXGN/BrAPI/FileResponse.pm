package CXGN::BrAPI::FileResponse;

use Moose;
use Data::Dumper;


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


sub tsv_or_csv {
	my $self = shift;
	my $format = shift;
	my $data_array = shift;
	my $file_path = $self->absolute_file_path;

	my $delim;
	if ($format eq 'tsv') {
		$delim = "\t";
	} elsif ($format eq 'csv') {
		$delim = ",";
	}

	open(my $fh, ">", $file_path);
		print STDERR $file_path."\n";
		foreach (@$data_array){
			print $fh join("$delim", @{$_}),"\n";
		}
	close $fh;
	my @datafiles = ($self->absolute_file_uri);
	return @datafiles;
}


1;
