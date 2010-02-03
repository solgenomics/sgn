
=head1 NAME

upload_usermap.pl - a script to upload user-defined maps to SGN.

=head1 DESCRIPTION


=head1 USAGE


=head2 New

This call will present the user with the option of selecting a file for upload.

=over 3

=item o 

I<action>: needs to be set to "new"

=back

=head2 Confirm upload

before the image is uploaded, a confirm step occurs. The confirm step has to be called with the following parameters:

=over 3

=item o

I<action>: needs to be set to confirm

=item o

I<file>: the file to upload

=back

=head2 Store map

This step will store the map in the SGN database. 

=over 3
 
=item o

I<action>=store

=item o

I<temp_file>: the temp_file basename of the temporarily uploaded file in the designated temp_dir

=back

=head2 NOTES

Please note the following restrictions:

=over 4

=item o

Note that only post requests are supported for the upload, with an enctype of multipart/form-data.

=item o

The user needs to be logged in and needs "submitter" privileges.

=back

=head1 SEE ALSO


=head1 VERSION 

Version 0.6, Dec 20, 2006.

=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)

=head1 FUNCTIONS

The following functions are documented in this script:

=cut

use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / blue_section_html page_title_html /;
use CXGN::People::UserMap;

my $page = CXGN::Page->new();
$page->header();
print "This page no longer exists.";
$page->footer();


# my $request = shift;
# my $apache = Apache::Request->instance($request);

# my $tempdir = CXGN::VHost->new()->get_conf("temp_dir")."/user_maps";

# my $action = $apache->param("action");
# if (!$action) { $action = "new"; }

# my $user_map_id = $apache->param("user_map_id");
# my $refering_page= $apache->param("refering_page");
# my $file = $apache->param("file");
# my $temp_file = $apache->param("temp_file");

# #print STDERR "********** ACTION=$action, USER_MAP_ID=$user_map_id, TEMP_DIR=$tempdir\n";

# my $upload = $apache->upload();

#my $page = CXGN::Page->new();
# #($action, $user_map_id, $refering_page, $file, $temp_file) = $page->get_encoded_arguments("action", "user_map_id", "refering_page", "file", "temp_file");

# # get db connection
# #
# my $dbh = CXGN::DB::Connection->new();

# # get the sp_person_id if user is logged in for actions add and upload.
# #
# my $user = undef;
# my $sp_person_id=undef;
# if ($action =~/new|confirm|store/i ) { 
#     my $login = CXGN::Login->new();
#     $sp_person_id = $login ->verify_session();
#     $user =  CXGN::People::Person->new($sp_person_id);
#     #$sp_person_id= $user->get_sp_person_id();
#     if ($user->get_user_type() !~ /curator|submitter/) { 
# 	$page->message_page("You do not have sufficient privileges to upload images. You need an account of type 'submitter'. Please contact SGN (sgn-feedback\@sgn.cornell.edu) to change your account type. Sorry.");
#     }
# }
# else { 
#     $page->message_page("Unknown action $action. ".(join ',', @$action)." If you think this was caused by an error, please contact SGN at sgn-feedback\@sgn.cornell.edu. Thanks!");
# }

# # create an new image object and go through the different 
# # possible actions. Emit error pages if needed.
# #

# if ($action eq "new") { 
#     # check stuff

#     # do stuff
#     add_dialog($page,$refering_page);

# }
# elsif ($action eq "confirm") { 
#     # check stuff

#     # do stuff
#     confirm($dbh, $page, $upload, $file);
# }
# elsif ($action eq "store") { 
#     # check stuff

#     # do stuff
#     store($dbh, $page, $temp_file, $file, $sp_person_id);
# }
# else { 
#     $page->message_page("No valid parameters were supplied.");
# }


# =head2 add_dialog

#  Usage:        add_dialog($page, $refering_page)
#  Desc:         Add dialog displays a page allowing to select and submit
#                an image file
#  Ret:
#  Args:         $page: a page object
#                $refering_page: This is used to show a link to the calling 
#                script.
#  Side Effects:
#  Example:

# =cut

# sub add_dialog { 
#     my $page = shift;
#     my $refering_page = shift;

#     $page->header();

#     print page_title_html("Upload UserMap" );

#     print qq { 

# 	<form action="upload_usermap.pl" method="post" enctype="multipart/form-data" >
# 	    <p>
# 	    On this page, you can upload a user map to SGN for viewing in the comparative viewer. The map is stored in the database and can either set to be public or private (be viewable only by the submitter). 
# 	    </p>

# 	    Upload a tab delimited file with the following columns:
# 	    <ul>
# 	    <li><b>marker name</b>: Should be identical to the SGN marker name if already available on SGN.</li>
# 	    <li><b>marker id</b>: If the marker is already in SGN, and you know its marker id (SGN-M number), provide it here. The marker name will be ignored in this case. If you don\'t have SGN marker ids, leave this column blank.
# 	    <li><b>linkage group</b>: The name or number of the chromosome or linkage group.</li>
# 	    <li><b>position</b>: The position in cM on the linkage group.</li>
# 	    <li><b>confidence</b>: Mapmaker\'s confidence for this marker - one of I, I(LOD2), F(LOD3), CF(LOD3). If your mapping software doesn\'t calculate a confidence, just leave this column blank.</li>
# 	  <li><b>protocol</b>: The type of experiment used to map the marker. Currently supported are CAPS, SSR, RFLP, SNP, and AFLP. </li>
# 	  </ul>
# 	  First, choose the mapping file using the "Choose file" button, then hit "Upload". <br />
# 	  The file will be checked for integrity and if no errors are found, you will need to confirm the upload for storing the map in the database.<br /><br />
	 
# 	    <input type="file" name="file" value="Choose file" />
# 	    <input type="hidden" name="action" value="confirm" /><br /><br />
# 	    <input type="hidden" name="refering_page" value="$refering_page" />
# 	    <input type="submit" value="Upload" />
# 	 </form>
#      };

#     if ($refering_page) { print "<a href=\"$refering_page\">Go back</a>"; }
    
#     $page->footer();
#     exit();
# }

# =head2 confirm

#  Usage:
#  Desc:
#  Ret:
#  Args:
#  Side Effects:
#  Example:

# =cut

# sub confirm { 
#     my $dbh = shift;
#     my $page = shift;
#     my $upload = shift;
#     my $file = shift;


#     #print STDERR "uploading [file: $file. tempfile: $temp_file]\n";

#     # deal with the upload options
#     #
#     my $upload_fh;

#     if (defined $upload) { 

# 	#print STDERR "upload is defined... we continue...\n";

# 	my $filename = $upload->filename();
# 	$filename =~ s/\.\.//g; # remove disagreeable properties such as ../
# 	my $vh = CXGN::VHost->new();
# 	my $temp_file = $vh->get_conf("basepath")."/".$vh->get_conf("tempfiles_subdir")
# 	    . "/user_maps/".$ENV{REMOTE_ADDR}."-".$filename;
	
# 	my $upload_fh = $upload->fh;
	
# 	# only copy file if it doesn't already exist
# 	#
# 	if (-e $temp_file) { 
# 	    die "The file $temp_file already exists. You cannot upload a file more than once\n";
# 	}
	
# 	#print STDERR "Uploading file to location: $temp_file\n";
	
# 	open UPLOADFILE, ">$temp_file" or die "Could not write to $temp_file: $!\n";
	
# 	binmode UPLOADFILE;
# 	while (<$upload_fh>) {
# 	    #warn "Read another chunk...\n";
# 	    print UPLOADFILE;
# 	}
# 	close UPLOADFILE;
# 	warn "Done uploading.\n";

# 	my $map = CXGN::People::UserMap->new($dbh);
# 	my @errors = $map->check_file($temp_file);

# 	my $temp_file_base = File::Basename::basename($temp_file);

# 	if (@errors) { 
# 	    my $error_summary = join "\n", map { $_->[0]." ".$_->[1] } @errors;
# 	    unlink ($temp_file);
# 	    $page->message_page("The map you uploaded contained errors. Please fix them and try again. Errors:\n$error_summary");
	    
# 	}
	
# 	my $stats_html = "<table>\n<tr><td>Linkage group:</td><td>marker count</td></tr>\n";
# 	my %stats = $map->get_map_stats_from_file($temp_file);
# 	foreach my $k (keys %stats) { 
# 	    $stats_html .="<tr><td><b>$k</b></td><td>$stats{$k}</td></tr>\n";
# 	}
# 	$stats_html .= "</table>\n";

# 	$page->header();


# 	print qq { 
# 	    Map statistics: <br />
# 	    $stats_html

# 	};

# 	print qq { 
# 	    <form method="get">
# 		<input type="hidden" name="temp_file" value="$temp_file_base" />
# 		<input type="hidden" name="action" value="store" />
# 		<input type="submit" value="Store in SGN database" />
		
# 		</form>
# 	    };

#  	if ($refering_page) { print "<a href=\"$refering_page\">[Cancel]</a><br /><br />\n"; }


#  	$page->footer();

#     }
#     else { 
# 	$page->error_page("A freakin error occurred!"); 
#     }
   
# }


# =head2 store

#  Usage:
#  Desc:
#  Ret:
#  Args:         $dbh - a database handle
#                $page - a page object
#                $temp_file - the temp file basename
#                $file - the filename (supplied by the user)
#                $sp_person_id - the logged in user id 
                     
#  Side Effects:
#  Example:

# =cut


# sub store { 
#     my ($dbh, $page, $temp_file, $file, $sp_person_id) = @_;
#     my $vh = CXGN::VHost->new();

#     my $user_map = CXGN::People::UserMap->new($dbh);

#     my $temp_image_dir = File::Spec->catfile($vh->get_conf("basepath"), $vh->get_conf("tempfiles_subdir"), "/user_maps");

# #    if ($user_map eq "CXGN::People::UserMap") { die"*******************OUCH\n"; }
#     my ($line, $err) = $user_map->import_map(File::Spec->catfile($temp_image_dir, $temp_file), $file, $sp_person_id);
#     if ($err) { 
# 	$page->message_page("An error occurred during the upload. Is the file you are uploading an correctly formatted map file? [$err] ");
# 	exit();
#     }
    
#     # set some image attributes...
#     # the image owner...
#     #print STDERR "Setting the submitter information in the map object...\n";
#     $user_map->set_sp_person_id($sp_person_id);
#     $user_map -> set_short_name($file);
#     $user_map -> assign_markers();
#     $user_map -> store();

#     #remove the temp_file
#     #
#     unlink ($temp_image_dir."/".$temp_file);

#     my $map_id=$user_map->get_user_map_id();
    
#     # go to the image detail page
#     # open for editing.....
#     $page->client_redirect("/cview/umap.pl?user_map_id=$map_id&action=edit");

# }

