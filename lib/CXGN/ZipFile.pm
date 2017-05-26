
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

has 'archived_zip' => (isa => 'Archive::Zip::Archive',
	is => 'rw',
);


my $archived_zip = Archive::Zip->new();

sub BUILD {
	my $self = shift;
	unless ( $archived_zip->read( $self->archived_zipfile_path() ) == AZ_OK ) {
		print STDERR "cannot read given zipfile\n";
        return;
	}
	$self->archived_zip($archived_zip);
}


#Assuming that zipfile is a flat list of files. 
sub file_names {
	my $self = shift;
    if (!$self->archived_zip){
        return;
    }
	my @file_names = $self->archived_zip()->memberNames();
	my @file_names_stripped;
	my @file_names_full;
	foreach (@file_names) {
		my @zip_names_split = split(/\//, $_);
		if ($zip_names_split[1]) {
			if ($zip_names_split[1] ne '.DS_Store' && $zip_names_split[1] ne '.fieldbook' && $zip_names_split[1] ne '.thumbnails') {
				my @zip_names_split_ext = split(/\./, $zip_names_split[1]);
				push @file_names_stripped, $zip_names_split_ext[0];
				push @file_names_full, $zip_names_split[1];
			}
		}
	}
	
	return (\@file_names_stripped, \@file_names_full);
}

sub file_members {
	my $self = shift;
	my @ret_members;
    if (!$self->archived_zip){
        return;
    }
	my @file_members = $self->archived_zip()->members();
	#print STDERR Dumper \@file_members;
	my %seen_files;
	foreach (@file_members) {
		if (exists($seen_files{$_->{'fileName'}}) || $_->{'compressedSize'} == 0 || index($_->{'fileName'}, '.DS_Store') != -1 || index($_->{'fileName'}, '.fieldbook') != -1 || index($_->{'fileName'}, '.thumbnails') != -1) {
			next;
		} else {
			$seen_files{$_->{'fileName'}} = 1;
			push @ret_members, $_;
		}
	}
	return \@ret_members;
}

sub extract_files_into_tempdir {
	my $self = shift;
	my $temp_dir = shift;
	
}

1;