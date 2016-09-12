
package CXGN::ZipFile;

use Moose;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use SGN::Model::Cvterm;
use Data::Dumper;

has 'archived_zipfile_path' => (isa => 'Str',
	is => 'rw',
	required => 1,
);

has 'extract_directory' => (isa => 'Str',
	is => 'rw',
);


sub BUILD {
	my $self = shift;

}


#Assuming that zipfile is a flat list of files. 
sub file_names {
	my $self = shift;
	my $archived_zip = Archive::Zip->new();
	unless ( $archived_zip->read( $self->archived_zipfile_path() ) == AZ_OK ) {
		die "cannot read given zipfile";
	}
	my @file_names = $archived_zip->memberNames();
	my @file_names_stripped;
	my @file_names_full;
	foreach (@file_names) {
		my @zip_names_split = split(/\//, $_);
		if ($zip_names_split[1]) {
			if ($zip_names_split[1] ne '.DS_Store') {
				my @zip_names_split_ext = split(/\./, $zip_names_split[1]);
				push @file_names_stripped, $zip_names_split_ext[0];
				push @file_names_full, $zip_names_split[1];
			}
		}
	}
	
	return (\@file_names_stripped, \@file_names_full);
}

1;