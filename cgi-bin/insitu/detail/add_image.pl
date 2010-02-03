
use strict;

use Apache2::Request;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / blue_section_html page_title_html /;
use CXGN::Insitu::Image;
use CXGN::Insitu::Experiment;

# get the parameters.
# legal parameters are: 
#  action: new upload
#  image_id: a valid image_id
#  experiment_id: a valid experiment_id
#  upload_file: the file to be uploaded, if action=upload.
#
my %args =();

# here we need to use the Apache2::Request methods for getting
# the parameters because uploading a file will cause the
# page object not to receive any of the parameters.
#
my $request = shift;
my $apache = Apache2::Request->instance($request);
$args{image_id} = $apache->param("image_id");
$args{experiment_id} = $apache->param("experiment_id");
$args{action}=$apache->param("action");
$args{upload_file}=$apache->param("upload_file");

# now that we got everthing safely, let's initiate the page object
#
my $page = CXGN::Page->new();

# get db connection
#
my $dbh = CXGN::DB::Connection->new("insitu");

# set the default action if none was supplied
#
if (!exists($args{action}) || !defined($args{action})) { 
    $args{action}="new";
}

# get the user_id if user is logged in for actions add and upload.
#
my $user = undef;
my $user_id=undef;
if ($args{action} =~/new|upload/i ) { 
    $user =  CXGN::People::Person->new(CXGN::Login->new()->verify_session());
    $user_id= $user->get_sp_person_id();
    if ($user->get_user_type() !~ /curator|submitter/) { 
	$page->message_page("You do not have sufficient privileges to upload images. You need an account of type 'submitter'. Please contact SGN to change your account type. Sorry.");
    }
}

if (!exists($args{experiment_id}) || !defined($args{experiment_id})) { 
    my $page = CXGN::Page->new();

    $page->error_page("Need an experiment_id to add image.");
}

# create an new image object and go through the different 
# possible actions. Emit error pages if needed.
#
my $image = CXGN::Insitu::Image->new($dbh);
$image -> set_experiment_id($args{experiment_id});
$image -> set_user_id($user_id);

if ($args{action} eq "new") { 
    add_dialog($image, %args);
    exit();
}
elsif ($args{action} eq "upload") { 
    upload($dbh, $apache, $image, %args);
}    
else { 
    my $page = CXGN::Page->new();
    $page->error_page("No recognized action defined.");
}

sub upload { 
    my $dbh = shift;
    my $apache = shift;
    my $image = shift;
    my %args = @_;

    # deal with the upload options
    #
    my $upload = $apache->upload();
    my $upload_fh;

    my $experiment = CXGN::Insitu::Experiment->new($dbh, $image->get_experiment_id());
    #print STDERR "Uploading file $args{upload_file}...\n";
    if (defined $upload) { 
	$upload_fh = $upload->fh();
	$image->upload_image($experiment, $args{upload_file}, $upload_fh);
	$image->process_image($args{upload_file}, $experiment);
	my $experiment_id = $image->get_experiment_id();
	my $page = CXGN::Page->new();
	$page->header();
	print "The following file was uploaded: <br />";
	
	print $image->get_img_src_tag();
	
	print qq { <br /><br />Return to <a href="experiment.pl?experiment_id=$experiment_id">experiment</a> };


	$page->footer();

	# we're done!
	#
	exit();
    }
    else { 
	my $page = CXGN::Page->new();
	$page->error_page("A freakin error occurred!"); 
    }
   
}


sub add_dialog { 
    my $image = shift;


    my $page = CXGN::Page->new();
    my $experiment_id = $image->get_experiment_id();
    my $experiment = CXGN::Insitu::Experiment->new($image->get_dbh(),$experiment_id);
    my $experiment_name = $experiment->get_name();
    
    $page->header();

    page_title_html("<a href=\"/insitu\">Insitu</a> Add Image" );

    foreach my $k (keys %args) { 
	#print "$k, $args{$k}<br />\n";
    }

    print qq { 
	<form action="add_image.pl" method="post" enctype="multipart/form-data" >
	    Upload an image for experiment "$experiment_name": 
	    [<a href="experiment.pl?experiment_id=$experiment_id&amp;action=edit">Cancel</a>]<br /><br />
	    
	    <input type="file" name="upload_file" value="Choose image file" />
	    <input type="hidden" name="action" value="upload" />
	    <input type="hidden" name="experiment_id" value="$experiment_id" />
	    <input type="submit" value="Upload" />
	 </form>
	};
    $page->footer();
    exit();
}
