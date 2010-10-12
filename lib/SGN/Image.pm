
=head1 NAME

SGN::Image.pm - a class to deal the SGN Context  configuration for
uploading images on SGN.

=head1 DESCRIPTION

This class provides database access and store functions as well as
image upload and certain image manipulation functions, such as image
file type conversion and image resizing; and functions to associate
tags with the image. Note that this was forked off from the insitu
image object. The insitu database needs to be re-factored to use this
image object.

The philosophy of the image object has changed slightly from the
Insitu::Image object. It now stores the images in a directory
specified by the conf object parameter "static_datasets_dir" plus
the conf parameter "image_dir" plus the directory name "image_files"
for the production server and the directory "image_files_sandbox" for
the test server. In those directories, it creates a subdirectory for
each image, with the subdirectory name being the corresponding image
id. In that directory are then several files, the originial image file
with the orignial name, the converted image into jpg in the standard
image sizes: large, medium, small and thumbnail with the names:
large.jpg, medium.jpg, small.jpg and thumbnail.jpg . All other
metadata about the image is stored in the database.


=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)
Naama Menda (nm249@cornell.edu)

=head1 VERSION

0.01, Dec 15, 2009.

=head1 MEMBER FUNCTIONS

The following functions are provided in this class:

=cut

use strict;

use File::Temp qw / tempfile tempdir /;
use File::Copy qw / copy move /;
use File::Basename qw / basename /;
use CXGN::DB::Connection;
use SGN::Context;
use CXGN::Tag;

package SGN::Image;

use base qw | CXGN::Image |;

# some pseudo constant definitions
#
our $LARGE_IMAGE_SIZE     = 800;
our $MEDIUM_IMAGE_SIZE    = 400;
our $SMALL_IMAGE_SIZE     = 200;
our $THUMBNAIL_IMAGE_SIZE = 100;

=head2 new

 Usage:        my $image = CXGN::Image->new($dbh)
 Desc:         constructor
 Ret:
 Args:         a database handle, optional identifier
 Side Effects: an empty object is returned. 
               a database connection is established.
 Example:

=cut

sub new {
    my $class = shift;
    my $dbh   = shift;

    my $self = $class->SUPER::new( $dbh, @_ );

    $self->set_configuration_object( SGN::Context->new() );
    $self->set_dbh($dbh);
    $self->set_upload_dir();

    return $self;
}

=head2 get_image_size_hash

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_image_size_hash {
    my $self = shift;
    return my %hash = (
        large     => $LARGE_IMAGE_SIZE,
        medium    => $MEDIUM_IMAGE_SIZE,
        small     => $SMALL_IMAGE_SIZE,
        thumbnail => $THUMBNAIL_IMAGE_SIZE,
    );
}

=head2 get_image_size

 Usage:
 Desc:
 Ret:
 Args:         "large" | "medium" | "small" | "thumbnail"
               default is medium
 Side Effects:
 Example:

=cut

sub get_image_size {
    my $self = shift;
    my $size = shift;
    my %hash = $self->get_image_size_hash();
    if ( exists( $hash{$size} ) ) {
        return $hash{$size};
    }

    # default
    #
    return $MEDIUM_IMAGE_SIZE;
}

=head2 get_image_dir

 Usage:        returns the image dir
 Desc:         uses the conf object to retrieve the image_dir configuration
               variable
 Ret:
 Args:         "full" for the full path, "partial" for just the part after the 
               website data dir (normally "/data/shared/website/");
               default is full path.
 Side Effects: 
 Example:     

=cut

sub get_image_dir {
    my $self  = shift;
    my $which = shift;

    my $dir = $self->get_configuration_object()->get_conf("image_dir");
    if ( !$dir ) {
        die
"Need a configuration variable called image_dir set in SGN.conf  Please contact SGN for help.";
    }
    if ( $which eq "full" ) {
        $dir =
          $self->get_configuration_object()
          ->get_conf("static_datasets_path") . "/$dir";
    }
    return $dir;
}

=head2 get_upload_dir

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_upload_dir {
    my $self = shift;
    return $self->{upload_dir};

}

=head2 set_upload_dir

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_upload_dir {
    my $self = shift;
    $self->{upload_dir} = shift;
}

=head2 get_image_url

 Usage: $self->get_image_url($size)
 Desc:  get the url for the image with a given size 
 Ret:   a url for the image
 Args:  size (large, medium, small, thumbnail,  original) 
 Side Effects: none
 Example:

=cut

sub get_image_url {
    my $self = shift;
    my $size = shift;

    my $url =
        $self->get_configuration_object()->get_conf("static_datasets_url")
      . "/"
      . $self->get_image_dir("partial") . "/"
      . $self->get_image_id();

    if ( $size eq "large" ) {
        return $url . "/large.jpg";
    }
    elsif ( $size eq "medium" ) {
        return $url . "/medium.jpg";
    }
    elsif ( $size eq "small" ) {
        return $url . "/small.jpg";
    }
    elsif ( $size eq "thumbnail" ) {
        return $url . "/thumbnail.jpg";
    }
    elsif ( $size eq "tiny" ) {
        return $url . "/thumbnail.jpg";
    }

    # deanx - 11/21/07
    elsif ( $size eq "original" ) {
        return
            $url . "/"
          . $self->get_original_filename()
          . $self->get_file_ext();
    }
    else {
        return $url . "/medium.jpg";
    }
}

=head2 get_configuration_object

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_configuration_object {
    my $self = shift;
    return $self->{configuration_object};
}

=head2 set_configuration_object

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_configuration_object {
    my $self = shift;
    $self->{configuration_object} = shift;
}

=head2 get_img_src_tag

 Usage:
 Desc:
 Ret:
 Args:         "large" | "medium" | "small" | "thumbnail" | "original" | "tiny"
               default is medium
 Side Effects:
 Example:

=cut

sub get_img_src_tag {
    my $self = shift;
    my $size = shift;
    my $url  = $self->get_image_url($size);
    my $name = $self->get_name();
    if ( $size eq "original" ) {

	my $static = $self->get_configuration_object()->get_conf("static_datasets_url");

        return
            "<a href=\""
          . ($url)
          . "\"><img src=\"$static/images/download_icon.png\" border=\"0\" alt=\""
          . $name
          . "\" /></a>";
    }
    elsif ( $size eq "tiny" ) {
        return
            "<img src=\""
          . ($url)
          . "\" width=\"20\" height=\"15\" border=\"0\" alt=\""
          . $name
          . "\" />\n";
    }
    else {
        return
            "<img src=\""
          . ($url)
          . "\" border=\"0\" alt=\""
          . $name
          . "\" />\n";
    }
}

=head2 get_temp_filename

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_temp_filename {
    my $self = shift;
    return $self->{temp_filename};

}

=head2 set_temp_filename

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_temp_filename {
    my $self = shift;
    $self->{temp_filename} = shift;
}

=head2 apache_upload_image

 Usage:        my $temp_file_name = $image->apache_upload_image($apache_upload_object);
 Desc:
 Ret:          the name of the intermediate tempfile that can be 
               used to access down the road.
 Args:         an apache upload object
 Side Effects: generates an intermediate temp file from an apache request
               that can be handled more easily. Adds the remote IP addr to the 
               filename so that different uploaders don\'t clobber but 
               allows only one upload per remote addr at a time.
 Errors:       change 11/30/07 - removes temp file if already exists
               # returns -1 if the intermediate temp file already exists.
               # this probably means that the submission button was hit twice
               # and that an upload is already in progress.
 Example:

=cut

sub apache_upload_image {
    my $self   = shift;
    my $upload = shift;
    ###  deanx jan 03 2007
# Adjust File name if using Windows IE - it sends whole paht; drive letter, path, and filename
    my $upload_filename;
    if ( $ENV{HTTP_USER_AGENT} =~ /msie/i ) {
        my ( $directory, $filename ) = $upload->filename =~ m/(.*\\)(.*)$/;
        $upload_filename = $filename;
    }
    else {
        $upload_filename = $upload->filename;
    }

    my $temp_file =
        $self->get_configuration_object()->get_conf("basepath") . "/"
      . $self->get_configuration_object()->get_conf("tempfiles_subdir")
      . "/temp_images/"
      . $ENV{REMOTE_ADDR} . "-"
      . $upload_filename;

    my $upload_fh = $upload->fh;

    ### 11/30/07 - change this so it removes existing file
    #     -deanx
    # # only copy file if it doesn't already exist
    # #
    if ( -e $temp_file ) {
        unlink $temp_file;
    }

    open UPLOADFILE, '>', $temp_file or die "Could not write to $temp_file: $!\n";

    binmode UPLOADFILE;
    while (<$upload_fh>) {

        #warn "Read another chunk...\n";
        print UPLOADFILE;
    }
    close UPLOADFILE;
    warn "Done uploading.\n";

    return $temp_file;

}

=head2 process_image

 Usage:        $return_code = $image -> process_image($filename, "individual", 234);
 Desc:         processes the image that has been uploaded with the upload command.
 Ret:          the image id of the image in the database as a positive number,
               error conditions as negative numbers.
 Args:         the filename of the file (complete path), the type of object it is
               associated to, and the id of that object.
 Side Effects: generates a new subdirectory in the image_dir for the image files,
               copies the image file around on the file system, and creates 
               thumnbnails and other views for the image.
 Example:

=cut

sub process_image {
    my $self      = shift;
    my $file_name = shift;
    my $type      = shift;
    my $type_id   = shift;

    if ( my $id = $self->get_image_id() ) {
        warn
"process_image: The image object ($id) should already have an associated image. The old image will be overwritten with the new image provided!\n";
        die "I'm dying now. Ouch!\n";
    }

    my ($upload_dir) =
      File::Temp::tempdir( "upload_XXXXXX",
        DIR => $self->get_image_dir("full") );
    system("chmod 775 $upload_dir");
    $self->set_upload_dir($upload_dir);

    # process image
    #
    $upload_dir = $self->get_upload_dir();

    # copy unmodified image to be fullsize image
    #
    my $basename = File::Basename::basename($file_name);

    # deanx - preserver original filename
    my $original_filename = $basename;

    my $dest_name = $self->get_upload_dir() . "/" . $basename;
    #print STDERR "Copying $file_name to $dest_name...\n";

    #    eval {
    File::Copy::copy( $file_name, $dest_name )
      || die "Can't copy file $file_name to $dest_name";
    my $chmod = "chmod 664 '$dest_name'";

    #	print STDERR "CHMODing FILE: $chmod\n";
    #system($chmod);
    #print STDERR
    #  "copied image $file_name to $dest_name and CHMODed 664 $dest_name.\n";

    #    };
    #    if ($@) {
    #	die "An error occurred during copy/chmod: $@\n";
    #	return -1;
    #    }

    ### Multi Page Document Support
    #    deanx - nov. 16 2007
    #   PDF, PS, EPS documents are now supported by ImageMagick/Ghostscript
    #   A primary impact is these types can multipage.  'mogrify' produces
    #   one image per page, labelled filename-0.jpg, filename-1.jpg ...
    #   This code detects multipage documents and copies the first page for
    #   thumbnail processing

##    my @image_pages = system("/usr/bin/identify", "$dest_name");  #returns rc, not comtents
    my @image_pages = `/usr/bin/identify "$dest_name"`;

    if ( $#image_pages > 0 ) {    # multipage, pdf, ps or eps

#	eval  {
# note mogrify used since 'convert' will not correctly reformat (convert makes blank images)
# if  (! (`mogrify -format jpg '$dest_name'`)) {die "Sorry, can't convert image $basename";}
# if ( system("/usr/bin/mogrify -format jpg","$upload_dir/$basename") != 0) {die "Sorry, can't convert image $basename";}
# my $chmod = "chmod 664 '$upload_dir/$basename'";
# Convert and mogrify both dislike the format of our filenames intensely if ghostscript
#   is envoked ... change filename to something beign like temp.<ext>

        my $newname;
        if ( $basename =~ /(.*)\.(.{1,4})$/ )
        {                         #note; mogrify will create files name
                                  # basename-0.jpg, basename-1.jpg
            my $mogrified_first_image = $upload_dir . "/temp-0.jpg";
            my $tempname =
              $upload_dir . "/temp." . $2;    # retrieve file extension
            $newname = $basename . ".jpg";    #
            my $new_dest = $upload_dir . "/" . $newname;

            # use temp name for mogrify/ghostscript
            File::Copy::copy( $dest_name, $tempname )
              || die "Can't copy file $basename to $tempname";

            if ( (`mogrify -format jpg '$tempname'`) ) {
                die "Sorry, can't convert image $basename";
            }

            File::Copy::copy( $mogrified_first_image, $new_dest )
              || die "Can't copy file $mogrified_first_image to $newname";

        }
        #print STDERR "Successfully converted $basename to $newname\n";
        $basename = $newname;

        #	};

        #	  if ($@) {
        #	      return -2;
        #	  }

    }         #Multi-page non-image file eg: pdf, ps, eps
    else {    # appears to be a regular simple image

        #	eval {
        my $newname = "";
        if ( !(`mogrify -format jpg '$dest_name'`) ) {
            if ( $basename !~ /(.*)\.(jpeg|jpg)$/i ) {    # has no jpg extension
                $newname = $1 . ".JPG";    # convert it to extention .JPG
            }
            elsif ( $basename !~ /(.*)\.(.{1,4})$/ ) { # has no extension at all
                $newname = $basename . ".JPG";         # add an extension .JPG
            }
            else {
                $newname = $basename;    # apparently, it has a JPG extension
            }
            if (
                system(
                    "/usr/bin/convert", "$upload_dir/$basename",
                    "$upload_dir/$newname"
                ) != 0
              )
            {
                die "Sorry, can't convert image $basename to $newname";
            }

            #print STDERR "Successfully converted $basename to $newname\n";
            $original_filename = $newname;
            $basename          = $newname;
        }

        #	};
        #	if ($@) {
        #	    return -2;
        #	}

    }

    #    eval {

    # create large image
    $self->copy_image_resize(
        "$upload_dir/$basename",
        $self->get_upload_dir() . "/large.jpg",
        $self->get_image_size("large")
    );

    # create midsize images
    $self->copy_image_resize(
        "$upload_dir/$basename",
        $self->get_upload_dir() . "/medium.jpg",
        $self->get_image_size("medium")
    );

    # create small image
    $self->copy_image_resize(
        "$upload_dir/$basename",
        $self->get_upload_dir() . "/small.jpg",
        $self->get_image_size("small")
    );

    # create thumbnail
    $self->copy_image_resize(
        "$upload_dir/$basename",
        $self->get_upload_dir() . "/thumbnail.jpg",
        $self->get_image_size("thumbnail")
    );

    #    };
    #	  if ($@) {
    #	      return -3;
    #	  }

    # enter preliminary image data into database
    #$tag_table->insert_image($experiment_id, $unix_file, ${safe_ext});
    #
    my $ext = "";

    # if ($basename =~ /(.*)(\.{1,4})$/) {
    # deanx - nov 21 2007 - logic changed ... preserve original name from above
    #     use this to extract file extension. note prior regex was wrong
    if ( $original_filename =~ /(.*)(\.\S{1,4})$/ ) {
        $original_filename = $1;
        $ext               = $2;
    }

    $self->set_original_filename($original_filename);
    $self->set_file_ext($ext);

    # start transaction, store the image object, and associate it to
    # the given type and type_id.
    #
    my $image_id = 0;

    #    eval {
    $image_id = $self->store();

    if ( $type eq "experiment" ) {
        #print STDERR "Associating experiment $type_id...\n";
        $self->associate_experiment($type_id);
    }
    elsif ( $type eq "individual" ) {
        #print STDERR "Associating individual $type_id...\n";
        $self->associate_individual($type_id);
    }
    elsif ( $type eq "fish" ) {
        #print STDERR "Associating to fish experiment $type_id\n";
        $self->associate_fish_result($type_id);
    }
    elsif ( $type eq "locus" ) {
        #print STDERR "Associating to locus $type_id\n";
        $self->associate_locus($type_id);
    }

    else {
        warn "type $type is like totally illegal! Not associating image with any object. Please check if your loading script links the image with an sgn object! \n";
    }
    
    # move the image into the image_id subdirectory
    #
    my $image_dir = $self->get_image_dir("full") . "/$image_id";
    #print STDERR "Moved $upload_dir to $image_dir...\n";
    File::Copy::move( $upload_dir, $image_dir )
      || die "Couldn't move temp dir to image dir ($upload_dir, $image_dir)";

    #    };

# if we are here, everything should have worked, so we commit.
#
#    if ($@) {
#	print STDERR "An error occurred while storing the image data. Sorry. error: $@";
#	$self->get_dbh()->rollback();

    # should also delete the newly created image file directory...
    #
    ### unlink $upload_dir."/$image_id";
    #   }
    #   else {
    #	$self->get_dbh()->commit();
    #    }
    $self->set_image_id($image_id);
    return $image_id;
}

sub copy_image_resize {
    my $self = shift;
    my ( $original_image, $new_image, $width ) = @_;

    # first copy the file
    my $copy = "cp '$original_image' '$new_image'";

    #print STDERR "COPYING: $copy\n";
    #system($copy);
    File::Copy::copy( $original_image, $new_image );
    my $chmod = "chmod 664 '$new_image'";

    #    print STDERR "CHMODing: $chmod\n";
    #system($chmod);
    #my $chown = "chown www-data:www-data '$new_image'";

    #   print STDERR "CHOWNing: $chown\n";
    #system($chown);

    # now resize the new file, and ensure it is a jpeg
    my $resize = `mogrify -format jpg -geometry $width '$new_image'`;

}

=head2 function get_copyright, set_copyright

  Synopsis:	$copyright = $image->get_copyright(); 
                $image->set_copyright("Copyright (c) 2001 by Picasso");
  Arguments:	getter: the copyright information string
  Returns:	setter: the copyright information string
  Side effects:	will be stored in the database in the copyright column.
  Description:	

=cut

sub get_copyright {
    my $self = shift;
    return $self->{copyright};
}

sub set_copyright {
    my $self = shift;
    $self->{copyright} = shift;
}

=head2 iconify_file

Usage:   Iconify_file ($filename)
Desc:    This is used only for PDF, PS and EPS files during Upload processing to produce a thumbnail image
         for these filetypes for the CONFIRM screen.  Results end up on disk but are not used other than to t
	 produce the thumbnail
Ret:
Args:    Full Filename of PDF file
Side Effects:  
Example:

=cut

sub iconify_file {
    my $file_name = shift;

    my $basename = File::Basename::basename($file_name);

    my $self = SGN::Context->new()
      ;    # merely used to retrieve correct temp dir on this host
    my $temp_dir =
        $self->get_conf("basepath") . "/"
      . $self->get_conf("tempfiles_subdir")
      . "/temp_images";

    my @image_pages = `/usr/bin/identify $file_name`;

    my $mogrified_image;
    my $newname;
    if ( $basename =~ /(.*)\.(.{1,4})$/ )
    {      #note; mogrify will create files name
            # basename-0.jpg, basename-1.jpg
        if ( $#image_pages > 0 ) {    # multipage, pdf, ps or eps
            $mogrified_image = $temp_dir . "/temp-0.jpg";
        }
        else {
            $mogrified_image = $temp_dir . "/temp.jpg";
        }
        my $tempname = $temp_dir . "/temp." . $2;    # retrieve file extension
        $newname = $basename . ".jpg";               #
        my $new_dest = $temp_dir . "/" . $newname;

        # use temp name for mogrify/ghostscript
        File::Copy::copy( $file_name, $tempname )
          || die "Can't copy file $basename to $tempname";

        if ( (`mogrify -format jpg '$tempname'`) ) {
            die "Sorry, can't convert image $basename";
        }

        File::Copy::copy( $mogrified_image, $new_dest )
          || die "Can't copy file $mogrified_image to $newname";

    }
    return;
}

1;
