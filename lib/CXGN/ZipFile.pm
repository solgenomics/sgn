
package CXGN::ZipFile;

use Moose;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use SGN::Model::Cvterm;
use Data::Dumper;
use File::Spec::Functions qw(splitpath);
use IO::File;
use IO::Uncompress::Unzip qw($UnzipError);
use File::Path qw(mkpath);

has 'archived_zipfile_path' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'extract_directory' => (
    isa => 'Str',
    is => 'rw',
);

has 'archived_zip' => (
    isa => 'Archive::Zip::Archive',
    is => 'rw',
);


my $archived_zip = Archive::Zip->new();

sub BUILD {
    my $self = shift;
}


#Assuming that zipfile is a flat list of files. 
sub file_names {
    my $self = shift;
    unless ( $archived_zip->read( $self->archived_zipfile_path() ) == AZ_OK ) {
        print STDERR "cannot read given zipfile\n";
        return;
    }
    $self->archived_zip(Archive::Zip->new($self->archived_zipfile_path()));
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
    unless ( $archived_zip->read( $self->archived_zipfile_path() ) == AZ_OK ) {
        print STDERR "cannot read given zipfile\n";
        return;
    }
    $self->archived_zip(Archive::Zip->new($self->archived_zipfile_path()));
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

#warning: will copy files out of zipfile and file will lose metadata such as EXIF image data. Use something like SGN::Image::upload_drone_imagery_zipfile if metadata needed.
sub extract_files_into_tempdir {
    my $self = shift;
    my $dest = $self->extract_directory();
    my $file = $self->archived_zipfile_path();

    my $u = IO::Uncompress::Unzip->new($file)
        or die "Cannot open $file: $UnzipError";

    my $status;
    my @image_files;
    for ($status = 1; $status > 0; $status = $u->nextStream()) {
        my $header = $u->getHeaderInfo();
        my (undef, $path, $name) = splitpath($header->{Name});
        my $destdir = "$dest/$path";

        unless (-d $destdir) {
            mkpath($destdir) or die "Couldn't mkdir $destdir: $!";
        }

        if ($name =~ m!/$!) {
            last if $status < 0;
            next;
        }

        my $destfile = "$dest/$path/$name";
        # https://cwe.mitre.org/data/definitions/37.html
        # CWE-37: Path Traversal
        die "unsafe $destfile" if $destfile =~ m!\Q..\E(/|\\)!;

        my $buff;
        my $fh = IO::File->new($destfile, "w")
            or die "Couldn't write to $destfile: $!";
        while (($status = $u->read($buff)) > 0) {
            $fh->write($buff);
        }
        $fh->close();
        push @image_files, $destfile;
        my $stored_time = $header->{'Time'};
        utime ($stored_time, $stored_time, $destfile)
            or die "Couldn't touch $destfile: $!";
    }

    die "Error processing $file: $!\n"
        if $status < 0 ;

    return \@image_files;
}

1;