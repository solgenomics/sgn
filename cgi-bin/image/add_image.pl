
=head1 NAME

add_image.pl - a web script to add image to the SGN database

=head1 DESCRIPTION

uploads an image to the SGN image database (the image table in the metadata schema) and places the image on the file system (using the conf object's image_dir parameters), resizes the image to thumbnail size etc. This is different from the deprecated CXGN::Insitu::Image, which had similar functionality, but was too insitu specific.

=head2 IMPORTANT NOTE

The uploaded images will be stored using the SGN::Image object. This object stores meta-information in the SGN database, and the image on disk. The file location is given by the $c SGN:Context  variable "image_dir". On the production server, this should be set to "/data/shared/website/image/image_files". To prevent different image to clobber the image_dir, that variable needs to be set to "/data/shared/website/image/image_files_sandbox" for the devel server. When the cxgn database is copied to sandbox, the corresponding image_dir needs to be copied over as well. Check these variables before adding images.

=head1 USAGE

This web script uses 3 stages for uploading an image, each step has its own set of parameters, explained below:

=head2 New image 

This call will present the user with the option of selecting a file for upload.

=over 3

=item o 

I<action>: needs to be set to "new"

=item o

I<type>: either experiment, individual, locus, or to be defined data types in the SGN database that can have associated images (fish etc).

=item o

I<type_id>: the primary key of the object of type "type" to which this image should be associated.

=item o

I<refering_page>: the page that requested the image upload.

=back

=head2 Confirm upload

before the image is uploaded, a confirm step occurs. The confirm step has to be called with the following parameters:

=over 3

=item o

I<action>: needs to be set to confirm

=item o

I<type>: see above

=item o

I<file>: the file to upload

=item o

I<refering_page>: The page that requested the image upload.

=back

=head2 Store image

This step will actually store the image in the SGN database. It then client_redirects to the image detail page for that image, such that hitting reload will not cause the image to be uploaded again.

=over 3
 
=item o

I<action>=store

=item o

I<type>: see above

=item o

I<type_id>: see above

=item o

I<refering_page>: the url of the refering page

=item o

I<temp_file>: the temp_file basename of the temporarily uploaded file in the designated temp_dir

=back

=head2 NOTES

Please note the following restrictions:

=over 4

=item o

Note that only post requests are supported for the image upload, with an enctype of multipart/form-data.

=item o

The user needs to be logged in and needs "submitter" privileges.

=back

=head1 SEE ALSO

The script that deals with displaying and editing the meta information is /image/index.pl .
This script is based on the L<SGN::Image> object.

=head1 VERSION 

Version 0.6, Dec 20, 2006.

=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)

=head1 FUNCTIONS

The following functions are documented in this script:

=cut

use strict;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / blue_section_html page_title_html / ;
use SGN::Image;
use CXGN::People::Person;
use CXGN::Contact;

# get the parameters.
# legal parameters are: 
#  action: new upload
#  image_id: a valid image_id
#  experiment_id: a valid experiment_id
#  upload_file: the file to be uploaded, if action=upload.
#

my $request = shift;


my $page = CXGN::Page->new();

my %args = $page->get_all_encoded_arguments;

# get db connection
#
my $dbh = CXGN::DB::Connection->new();

# get the sp_person_id if user is logged in for actions add and upload.
#
my $user = undef;
my $sp_person_id=undef;
if ($args{action} =~/new|confirm|store/i ) { 
    my $login = CXGN::Login->new($dbh);
    $sp_person_id = $login ->verify_session();
    $user =  CXGN::People::Person->new($dbh, $sp_person_id);
    #$sp_person_id= $user->get_sp_person_id();
    if ($user->get_user_type() !~ /curator|submitter/) { 
	$page->message_page("You do not have sufficient privileges to upload images. You need an account of type 'submitter'. Please contact SGN to change your account type. Sorry.");
    }
}
else { 
    $page->message_page("Unknown action $args{action}. What do you want to do exactly?");
}

# create an new image object and go through the different 
# possible actions. Emit error pages if needed.
#
my $image = SGN::Image->new($dbh);

if ($args{action} eq "new") { 
    # check stuff

    # do stuff
    add_dialog($page, $image, %args);

}
elsif ($args{action} eq "confirm") { 
    # check stuff

    # do stuff
    confirm($dbh, $page, %args);
}
elsif ($args{action} eq "store") { 
    # check stuff

    # do stuff
    $args{sp_person_id} = $sp_person_id ; 
    store($dbh, $page, $image, %args);
}
else { 
    $page->message_page("No valid parameters were supplied.");
}


=head2 add_dialog

 Usage:        add_dialog($page, $image, %args)
 Desc:         Add dialog displays a page allowing to select and submit
               an image file
 Ret:
 Args:         $page: a page object
               $image: an image object (empty)
               $args{type}: either "individual" or "experiment"
               $args{type_id}: the primary key identifying the object 
               of type $args{type}
               $args{refering_page}: The page that has called the 
               add_image script.
               This is used to show a link to the calling script.
 Side Effects:
 Example:

=cut

sub add_dialog { 
    my $page = shift;
    my $image = shift;
    my %args = @_;

    $page->header();

    print page_title_html("Add image to $args{type} $args{type_id}" );

    print qq { 

	<p class="boxbgcolor2">Note: By pressing the "Upload" button, you are considered to be the copyright owner of the image being uploaded and that you grant a non-exclusive license to SGN to display and use the image on SGN webpages and materials related to SGN.<br /></p>
        <p> Supported file formats include .jpg. .jpeg, .gif, .png, .pdf, .ps,
	.eps <br></p>
	<form action="add_image.pl" method="post" enctype="multipart/form-data" >
	    Upload an image, and associated with object <b>$args{type}</b> id $args{type_id}<br /><br />
	    <input type="file" name="file" value="Choose image file" />
	    <input type="hidden" name="action" value="confirm" /><br /><br />
	    <input type="hidden" name="type" value="$args{type}" />
	    <input type="hidden" name="type_id" value="$args{type_id}" />
	    <input type="hidden" name="refering_page" value="$args{refering_page}" />
	    <input type="submit" value="Upload" />
	 </form>
     };

    if ($args{refering_page}) { print "<a href=\"$args{refering_page}\">Go back</a>"; }
    
    $page->footer();
}

=head2 confirm

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub confirm { 
    my $dbh = shift;
    my $page = shift;
    my %args = @_;


    # deal with the upload options
    #
    my $upload = $page->get_upload();
    my $upload_fh;
   
    if (defined $upload) { 


	$args{temp_file} = $image->apache_upload_image($upload);
	#if ($temp_file eq "-1") { 
	#    $page->message_page("It seems that this file is in the process of being uploaded. Please do not upload files several times!!!! ");
	#}
	
	my $temp_file_base = File::Basename::basename($args{temp_file});
	my $sample_image = $temp_file_base;

 	$page->header();
        
        my $filename_validation_msg =  validate_image_filename($temp_file_base);
        if ( $filename_validation_msg )  { #if non-blank, there is a problem with Filename, print messages
            #print STDERR "Invalid Upload Filename Attempt: $temp_file_base, $filename_validation_msg \n";
	    print qq { There is a problem with the image file you selected: $temp_file_base <br />};
            print qq { Error:  };
            print $filename_validation_msg; 
            print qq {<br />};
            unlink $args{temp_file};  # remove upload! prevents more errors on item we have rejected
            if ($args{refering_page}) { print "<a href=\"$args{refering_page}\">[Return]</a><br /><br />\n"; }
        } else {	
	### deanx Testing --  this is trashable
        if   ($temp_file_base =~ /(.*)\.(.{1,4})$/ ) {
           if ( $2 =~ /[pdf|ps|eps]/i ) {
 	     SGN::Image::iconify_file($args{temp_file});
             $sample_image = $temp_file_base.'.jpg';
	     }
	 }

	print qq { The image uploaded is shown below. Please click on "Store in SGN database" to permanently store the image in the database. <br /> };
	
 	print "<br /><br />\n";
 	if ($args{type} && $args{type_id}) { print "<b>Association</b> $args{type} id $args{type_id}<br /><br />\n"; }

	print "Submitter: $sp_person_id<br />\n";

	print qq { 
	    <form method="get">
		<input type="hidden" name="temp_file" value="$temp_file_base" />
		<input type="hidden" name="action" value="store" />
		<input type="hidden" name="type" value="$args{type}" />
		<input type="hidden" name="type_id" value="$args{type_id}" />
		<input type="submit" value="Store in SGN database" />
		
		</form>
	    };

 	if ($args{refering_page}) { print "<a href=\"$args{refering_page}\">[Cancel]</a><br /><br />\n"; }

	print qq { <img src="/documents/tempfiles/temp_images/$sample_image" /> };

 	$page->footer();

       } # Ok filename
    }
    else { 
	$page->error_page("A freakin error occurred!"); 
    }
   
}


=head2 store

 Usage:
 Desc:
 Ret:
 Args:         $dbh - a database handle
               $page - a page object
               $image - an image object
               %args, with the following key/values:
                      $args{file} -  
                      $args{temp_file} - 
                      $args{type} - 
                      $args{type_id} - 
                      $args{refering_page} - 
                      $args{sp_person_id} -
 Side Effects:
 Example:

=cut

#  store($dbh, $page, $file, $image, $type, $type_id, $refering_page, $sp_person_id);
sub store { 
    my ($dbh, $page, $image, %args) = @_;
    my $sp_person_id = $args{sp_person_id};
    
    my $temp_image_dir = $c->get_conf("basepath")."/".$c->get_conf("tempfiles_subdir") ."/temp_images";
   
    $image -> set_sp_person_id($sp_person_id);

    if ((my $err = $image->process_image($temp_image_dir."/".$args{temp_file}, $args{type}, $args{type_id}))<=0) { 
	$page->message_page("An error occurred during the upload. Is the file you are uploading an image file? [$err] ");
	exit();
    }
    
    # set some image attributes...
    # the image owner...
    #print STDERR "Setting the submitter information in the image object...\n";

    $image -> set_name($args{file});
    
    
    $image->store();
    
    send_image_email($dbh, $image, $sp_person_id, %args);
    #remove the temp_file
    #
    unlink ($temp_image_dir."/".$args{temp_file});

    $args{image_id}=$image->get_image_id();
   
    
    # go to the image detail page
    # open for editing.....
    $page->client_redirect("/image/?image_id=$args{image_id}&action=edit");
}

=head2 store

 Usage:  validate_image_filename($filename);
 Desc:   Validate the Upload Image file string seems reasonable
 Ret:    Returns 0 if file name OK, otherwise returns appropriate error msg
 Args:   $filename

 Side Effects:
 Example:

=cut

sub validate_image_filename {
  my $fn = shift;
  my %file_types = ( '.jpg' => 'JPEG file',
                     '.jpeg' => 'JPEG file',
                     '.gif' => 'GIF file',
		     '.pdf' => 'PDF file',
		     '.ps'  => 'PS file',
                     '.eps' => 'EPS file',
		     '.png' => 'PNG file');



  # first test is non-acceptable characters in filename
  my $OK_CHARS='-a-zA-Z0-9_.@\ '; # as recommend by CERT, test for what you will allow
  my $test_fn = $fn;
  $test_fn =~ s/[^$OK_CHARS]/_/go;
  if ( $fn ne $test_fn ) {
      #print STDERR "Upload Attempt with bad shell characters: $fn \n";
       return "Invalid characters found in filename, must not contain
	characters <b>\& ; : \` \' \\ \| \* \? ~ ^ < > ( ) [ ] { } \$</b>" ;
     }



  my $ext; 
  if ($fn =~ m/^(.*)(\.\S{1,4})\r*$/) {
      $ext = lc ($2);
      #print STDERR "Upload Attempt with disallowed filename extension: $fn Extension: $ext\n";
      return "File Type must be one of: .png, .jpg, .jpeg, .gif, .pdf, .ps, or .eps" unless exists $file_types{$ext};
    } else {
      #print STDERR "Upload Attempt with filename extension we could not parse: $fn \n";
      return "File Type must be one of: .png, .jpg, .jpeg, .gif, .pdf, .ps, or .eps";
    }

  return 0;  # FALSE, if passes all tests
}

sub send_image_email {
    my $dbh = shift;
    my $image = shift;
    my $sp_person_id = shift;
    my %args = @_;
    my $refering_page=$args{refering_page};
    my $type= $args{type};  #locus or...?
    my $type_id = $args{type_id}; #the database id of the refering object (locus..)
    my $image_id = $image->get_image_id();
    my $action = $args{action};
    #my $sp_person_id = $args{sp_person_id};
   
    my $person= CXGN::People::Person->new($dbh, $sp_person_id);
    my $user=$person->get_first_name()." ".$person->get_last_name();
    
    my $type_link;
    
    
    my $user_link = qq | http://sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;
    my $usermail=$person->get_contact_email();
    my $image_link = qq |http://sgn.cornell.edu/image/?image_id=$image_id|;
    if ($type eq 'locus') {
	$type_link = qq | http://sgn.cornell.edu/phenome/locus_display.pl?locus_id=$type_id|;
    }
#    elsif ($type eq 'allele') {
#	$type_link = qq | http://sgn.cornell.edu/phenome/allele.pl?allele_id=$type_id|;
#     }
#     elsif ($type eq 'population') {
# 	$type_link = qq | http://sgn.cornell.edu/phenome/population.pl?population_id=$type_id|;
#     }

    my $fdbk_body;
    my $subject;

    if ($action eq 'store') {

        $subject="[New image associated with $type: $type_id]";
	$fdbk_body="$user ($user_link) has associated image $image_link \n with $type: $type_link"; 
   }
    elsif($action eq 'delete') {
	
	
	$subject="[A image-$type association removed from $type: $type_id]";
	$fdbk_body="$user ($user_link) has removed publication $image_link \n from $type: $type_link"; 
    }
    
    CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
    
}
