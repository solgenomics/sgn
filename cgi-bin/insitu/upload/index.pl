#!/usr/bin/perl -w

# This script will print a form so that users may upload a gzipped file of
# insitu images from an experiment and metadata about that experiment.
#
# The data will be loaded into the database, and thumbnail images will be 
# created for each uploaded image.
#
# The data will be displayed later on with the insitu_view script.

#####################################################################
#####################################################################
# #include
#####################################################################
#####################################################################

# local packages
use strict;
use CXGN::Page;
use CXGN::Insitu;
use CXGN::People;
use CGI;
use Data::Dumper;
use POSIX qw(strftime);

#####################################################################
#####################################################################
# Configuration
#####################################################################
#####################################################################

our $debug = 1; # higher for more verbosity

my $conf = CXGN::VHost->new();
# directory this script will keep temporary and backup data
our $input_dir =  $conf->get_conf("insitu_input");
# directory this script will move renamed fullsize images to
our $fullsize_dir = $conf->get_conf("insitu_fullsize_dir");
# directory this script will move  shrunken images to
our $display_dir = $conf->get_conf("insitu_display_dir");

# suffix / resolution for thumbnail images
our $thumb_suffix = "_thumb";
our $thumb_size = "200";

# suffix / resolution for large (but not fullsize) images
our $large_suffix = "_mid";
our $large_size = "600";


# set up DB connection
#
#our $tag_table = CXGN::Insitu->new();

my $dbh = CXGN::DB::Connection()->new();

my $page = CXGN::Page->new( "Insitu Upload", "Teri");
$page->header("Insitu Manager", "Insitu Upload");

# check whether there is a user logged in, and if so, what they are allowed
# to do
my $person_id=CXGN::Login->new()->has_session();
if($person_id) {
    my $person=CXGN::People::Person->new($person_id);
    if($person) {
	my $username=$person->get_username();
	my $user_type=$person->get_user_type()||'';
	if($user_type eq 'curator' or $user_type eq 'submitter') {
	    $debug and warn "Logged in as $username (uid $person_id)\n";
	    #my $query = new CGI;

	    my %args = $page->get_all_encoded_arguments();

	    if ($args{op})) {
		# the form has been submitted before
		if ($args{op} eq "submit_1") {
		    my $uploaded_filename;
		    warn "after test op eq submit_1...\n";
		    # if an image file has been uploaded, copy it to a temporary
		    # location
		    if ($args{op} eq 'e_file')) {
			
			# get remote file name, make it safe, keep it sane
			$uploaded_filename = $query->param('e_file');
			$uploaded_filename =~ s/.*[\/\\](.*)/$1/;
			# generate local file name, including IP and time, to make sure
			
			# multiple uploads don't clobber each other
			my $date = strftime "\%Y-\%m-\%d", gmtime;
			my $create_time = $args{starttime};
			$uploaded_filename = "${input_dir}/" . $ENV{REMOTE_ADDR} . "_${date}_${create_time}_${uploaded_filename}";
			warn "Uploaded_filename=$uploaded_filename\n";
			my $uploaded_filehandle = $query->upload('e_file');
			
			# only copy file if it doesn't already exist
			if (!-e $uploaded_filename) {
			    
			    # open a filehandle for the uploaded file
			    if (!$uploaded_filehandle) {
				happy_death("Source file wasn't opened as a valid filehandle: $!");
			    }
			    else {	
				# copy said file to destination, line by line
				warn "Now uploading file...\n";
				open UPLOADFILE, ">$uploaded_filename" or die "Could not write to ${uploaded_filename}: $!\n";
				warn "could open filename...\n";
				binmode UPLOADFILE;
				while (<$uploaded_filehandle>) {
				    warn "Read another chunk...\n";
				    print UPLOADFILE;
				}
				close UPLOADFILE;
				warn "Done uploading...\n";
							}
			}
			else {
			    print STDERR "$uploaded_filename exists, not overwriting...\n";
			}
			
		    } # done worrying about uploaded files, for now
		    
		    # validate the default form
		    validate_form(
				  $person_id,
				  $query->param('starttime'),
				  $uploaded_filename,
				  $query->param('e_file'),
				  $query->param('e_name'),
				  $query->param('e_date_year'),
				  $query->param('e_date_month'),
				  $query->param('e_date_day'),
				  $query->param('e_organism'),
				  $query->param('e_tissue'),
				  $query->param('e_stage'),
				  $query->param('e_primer'),
				  $query->param('e_primer_link_desc'),
				  $query->param('e_primer_link'),
				  $query->param('e_primer_clone'),
				  $query->param('e_primer_seq'),
				  $query->param('e_primer_p1'),
				  $query->param('e_primer_p1_seq'),
				  $query->param('e_primer_p2'),
				  $query->param('e_primer_p2_seq'),
				  $query->param('e_description'),
				  [$query->param('e_category')]
				  );
		}
		elsif ($query->param('op') eq "submit_2") {
		    if ($debug > 1) {
			warn Dumper $query->param;
		    }
		    # reformat data into useful hash
		    my %imgs = ();
		    foreach my $img ($query->param) {
			if ($img =~ m/([0-9]+)_(name|description|category)/) {
			    my $img_id = $1;
			    my $data_type = $2;
			    if ($data_type eq 'category') {
				$imgs{$img_id}{$data_type} = [$query->param($img)];
			    }
			    else {
				$imgs{$img_id}{$data_type} = $query->param($img);
			    }
			}
		    }
		    # send submitted image data to a function to process it
		    finalize_submission(\%imgs);
		}
		else {
		    # unknown operation; this shouldn't happen
		    print "<div class=\"error\">An error has occured!</div>";
		    print_form();
		}
	    } else {
		# first run; default operation
		print_form();
	    }
	}
	else {
	    print "You do not currently have rights to submit any data.";
	}
    }
}
else {
    print "You must log in to do that!";
}

$page->footer();






#####################################################################
#####################################################################
# Functions
#####################################################################
#####################################################################

#####################################################################
# default operation; print form
sub print_form {
    my ($starttime, $file, $name, $year, $month, $day, $organism, $tissue, $stage, $primer, $primer_link_desc, $primer_link, $primer_clone, $primer_sequence, $primer_p1, $primer_p1_seq, $primer_p2, $primer_p2_seq, $description, $categories) = @_;
    $starttime ||= time;
    $file ||= "";
    $name ||= "";
    $year ||= "";
    $month ||= "";
    $day ||= "";
    $organism ||= "";
    $tissue ||= "";
    $stage ||= "";
    $primer ||= "";
    $primer_link_desc ||= "";
    $primer_link ||= "";
    $primer_clone ||= "";
    $primer_sequence ||= "";
    $primer_p1 ||= "";
    $primer_p1_seq ||= "";
    $primer_p2 ||= "";
    $primer_p2_seq ||= "";
    $description ||= "";
    my $date = "$year-$month-$day";
    if ($debug > 1) {
	warn "\nprint_form input: \n";
	warn "\tstarttime: $starttime\n";
	warn "\tfile: $file\n";
	
	warn "\texperiment name: $name\n";
	warn "\tdate: $date\n";
	warn "\torganism_id: $organism\n";
	warn "\ttissue: $tissue\n";
	warn "\tdevelopmental stage: $stage\n";
	warn "\tprimer: $primer\n";
	warn "\tprimer_link_desc: $primer_link_desc\n";
	warn "\tprimer_link: $primer_link\n";
	warn "\tprimer_clone: $primer_clone\n";
	warn "\tprimer_sequence:\n$primer_sequence\n";
	warn "\tprimer_p1: $primer_p1\n";
	warn "\tprimer_p1_seq:\n$primer_p1_seq\n";
	warn "\tprimer_p2: $primer_p2\n";
	warn "\tprimer_p2_seq:\n$primer_p2_seq\n";	
	warn "\tdescription:\n$description\n";
	warn "\tcategories:\n";
	warn Dumper @$categories;
	warn "\n\n";
    }
    
    
    print "\n<br /><br />\n\n";
    print "<div class=\"heading\">Experiment Metadata</div>\n";
    print "<p>Please enter information about the experiment these images came from.  All fields are required.  The uploaded file should be a tar file (.tar, .tgz, .tar.gz, or.tar.bz2).</p>\n\n";
    print "<p>Please be patient, as after the file is uploaded it will be unpacked and the images will be processed.  This can take quite some time! <strong>Don't hit reload!</strong></p>\n\n";
    
    print "<form method=\"post\" action=\"$script_name\" enctype=\"multipart/form-data\">\n";
    print "<input type=\"hidden\" name=\"op\" value=\"submit_1\" />\n";
    print "<input type=\"hidden\" name=\"starttime\" value=\"$starttime\" />\n";
    print "<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\">\n\n";
    
    # file upload
    print "<tr><td class=\"fielddef\">\n";
    print "File upload:\n";
    print "</td><td class=\"fieldinput\">\n";
    if ($file) {
	print "<input type=\"hidden\" name=\"e_file\" value=\"$file\"/>";
	print "<strong>$file</strong>";
    }
    else {
	print "<input class=\"fieldinput\" type=\"file\" name=\"e_file\"/>";
    }
    print "</td></tr>\n\n";
    
    # experiment name
    print "<tr><td class=\"fielddef\">\n";
    print "Experiment name:\n";
    print "</td><td class=\"fieldinput\">\n";
    print "<input class=\"fieldinput\" type=\"text\" name=\"e_name\" value=\"$name\"/>";
    print "</td></tr>\n\n";
    
    # date of experiment
    print "<tr><td class=\"fielddef\">\n";
    print "Experiment date:\n";
    print "</td><td class=\"fieldinput\">\n";
    print "<select name=\"e_date_year\">\n";
    print "<option value=\"\"></option>\n";
    for (my $year1=strftime '%Y', gmtime; $year1>=1980; $year1--) {
	print "<option value=\"$year1\"";
	($year eq $year1) and print " selected=\"selected\"";
	print ">$year1</option>\n";
    }
    print "</select>\n";
    print "<select name=\"e_date_month\">\n";
    print "<option value=\"\"></option>\n";
    for (my $month1=1; $month1<=12; $month1++) {
	my $month2 = sprintf("%02d", $month1);
	print "<option value=\"$month2\"";
	($month eq $month2) and print " selected=\"selected\"";
	print ">$month2</option>\n";
    }
    print "</select>\n";
    print "<select name=\"e_date_day\">\n";
    print "<option value=\"\"></option>\n";
    for (my $day1=1; $day1<=31; $day1++) {
	my $day2 = sprintf("%02d", $day1);
	print "<option value=\"$day2\"";
	($day eq $day2) and print " selected=\"selected\"";
	print ">$day2</option>\n";
    }
    print "</select>\n";
    print "(YYYY/MM/DD)\n";
    print "</td></tr>\n\n";
    
    # organism
    print "<tr><td class=\"fielddef\">\n";
    print "Organism:\n";
    print "</td><td class=\"fieldinput\">\n";
    my %organisms = $tag_table->return_organisms();
    print "<select name=\"e_organism\">\n";
    print "<option value=\"\"></option>\n";
    ($debug > 1) and warn Dumper \%organisms;
    foreach my $organism2 (sort keys %organisms) {
	my $org_id = $organisms{$organism2}{id};
	my $org_name = $organisms{$organism2}{name};
	print "<option value=\"$org_id\"";
	($organism eq $org_id) and print " selected=\"selected\"";
	print ">$org_name</option>\n";
    }
    print "</select>\n";	
    print "</td></tr>\n\n";
    
    # tissue
    print "<tr><td class=\"fielddef\">\n";
    print "Tissue:\n";
    print "</td><td class=\"fieldinput\">\n";
    print "<input class=\"fieldinput\" type=\"text\" name=\"e_tissue\" value=\"$tissue\"/>";
    print "</td></tr>\n\n";
    
    # developmental stage
    print "<tr><td class=\"fielddef\">\n";
    print "Developmental Stage:\n";
    print "</td><td class=\"fieldinput\">\n";
    print "<input class=\"fieldinput\" type=\"text\" name=\"e_stage\" value=\"$stage\"/>";
    print "</td></tr>\n\n";
    
    # primer
    print "<tr><td class=\"fielddef\">\n";
    print "Probe Name:\n";
    print "<div style=\"font-weight:normal; font-size:x-small; color: #000000\">\n";
    print "<br />If you enter the name of an existing probe, the<br />information for that probe will be used for the<br />optional fields.\n";
    print "<br /><a href=\"/cgi-bin/insitu_view.pl?op=probes\">Existing Probes...</a>\n";
    print "</div>\n";
    print "</td><td class=\"fieldinput\" valign=\"top\">\n";
    print "<input class=\"fieldinput\" type=\"text\" name=\"e_primer\" value=\"$primer\"/><br />";
    print "<span class=\"subfield\">Optional probe fields...</span> (<a style=\"font-size:smaller; text-decoration:underline; cursor: pointer;\" onclick=\"toggle('primer_optional'); return false;\" onfocus=\"blur()\">show/hide</a>)<br />\n";
    print "<div id=\"primer_optional\">\n";
    print "<br />\n";
    print "<span class=\"subfield\">Primer One:</span><br />&nbsp;<input class=\"fieldinput\" type=\"text\" name=\"e_primer_p1\" value=\"$primer_p1\"/><br />\n";
    print "<span class=\"subfield\">Primer One Sequence:</span><br />&nbsp;\n";
    print "<textarea name=\"e_primer_p1_seq\" class=\"fieldtext\">$primer_p1_seq</textarea><br />\n";
    print "<span class=\"subfield\">Primer Two:</span><br />&nbsp;<input class=\"fieldinput\" type=\"text\" name=\"e_primer_p2\" value=\"$primer_p2\"/><br />\n";
    print "<span class=\"subfield\">Primer Two Sequence:</span><br />&nbsp;\n";
    print "<textarea name=\"e_primer_p2_seq\" class=\"fieldtext\">$primer_p2_seq</textarea><br />\n";
    print "<br />\n";
    print "<span class=\"subfield\">Probe Sequence:</span><br />&nbsp;\n";
    print "<textarea name=\"e_primer_seq\" class=\"fieldtext\">$primer_sequence</textarea><br />\n";
    print "<br />\n";
    print "<span class=\"subfield\">Clone:</span> (<a href=\"http://pgn.cornell.edu\">PGN</a> clones)<br />&nbsp;<input class=\"fieldinput\" type=\"text\" name=\"e_primer_clone\" value=\"$primer_clone\"/><br />\n";
    print "<span class=\"subfield\">Source Description:</span> (non-<a href=\"http://pgn.cornell.edu\">PGN</a>)<br />&nbsp;<input class=\"fieldinput\" type=\"text\" name=\"e_primer_link_desc\" value=\"$primer_link_desc\"/><br />\n";
    print "<span class=\"subfield\">Source Link:</span> (non-<a href=\"http://pgn.cornell.edu\">PGN</a>)<br />&nbsp;<input class=\"fieldinput\" type=\"text\" name=\"e_primer_link\" value=\"$primer_link\"/><br />\n";
    print "</div>\n";
    if (!$primer_link_desc && !$primer_link && !$primer_clone && !$primer_sequence && !$primer_p1 && !$primer_p1_seq && !$primer_p2 && !$primer_p2_seq) {
	print "<script language=\"JavaScript\" type=\"text/javascript\">\n<!--\ncontract('primer_optional');\n//-->\n</script>\n";
    }
    print "</td></tr>\n\n";
    
    # description of experiment
    print "<tr><td class=\"fielddef\">\n";
    print "Other information / Description:\n";
    print "</td><td class=\"fieldinput\">\n";
    print "<textarea name=\"e_description\" class=\"fieldtext\">$description</textarea>\n";
    print "</td></tr>\n\n";
    
    # categories 
    print "<tr><td class=\"fielddef\">\n";
    print "Categories:<br /><a style=\"font-weight: normal; font-size:smaller;\" href=\"edit_cats.pl\">Add/Edit Categories...</a>\n";
    print "</td><td class=\"fieldinput\">\n";
    # previously checked tags
    my %checked_cats;
    foreach (@$categories) {
	$checked_cats{$_} = 1;
    }
    # get tags from database and load them into a hash of arrays
    my %tags = $tag_table->return_tags();
    ($debug > 2) and warn "print_form tags from database:\n";
    ($debug > 2) and warn Dumper \%tags;
    # print out tags
    foreach my $tag_name (sort keys %tags) {
	my $tag_desc = $tags{$tag_name}[2];
	my $tag_id = $tags{$tag_name}[0];
	my $checked = "";
	$checked_cats{$tag_id} and $checked="checked=\"checked\"";
	print "<input class=\"fieldcheck\" type=\"checkbox\" name=\"e_category\" value=\"$tag_id\" $checked /> $tag_name";
	$tag_desc and print " - $tag_desc";
	print "<br />\n";
    }
    print "</td></tr>\n\n";
    
    # submit button
    print "<tr><td class=\"fielddef\" style=\"text-align:center\" colspan=\"2\">\n";
    print "<input class=\"fieldinput\" type=\"submit\" value=\"Upload data\" />\n";
    print "</td></tr>\n\n";
    
    print "</table>\n";
    print "</form>\n\n";
}

#####################################################################
# validate form data
sub validate_form {
    my ($person_id, $starttime, $local_file, $file, $name, $year, $month, $day, $organism, $tissue, $stage, $primer, $primer_link_desc, $primer_link, $primer_clone, $primer_sequence, $primer_p1, $primer_p1_seq, $primer_p2, $primer_p2_seq, $description, $categories) = @_;
    my $date = "$year-$month-$day";
    if ($debug > 1) {
	warn "\nvalidate_form input: \n";
	warn "\tperson_id: $person_id\n";
	warn "\tstarttime: $starttime\n";
	warn "\tfile: $file\n";
	warn "\tlocal filename: $local_file\n";
	warn "\texperiment name: $name\n";
	warn "\tdate: $date\n";
	warn "\torganism_id: $organism\n";
	warn "\ttissue: $tissue\n";
	warn "\tdevelopmental stage: $stage\n";
	warn "\tprimer: $primer\n";
	warn "\tprimer_link_desc: $primer_link_desc\n";
	warn "\tprimer_link: $primer_link\n";
	warn "\tprimer_clone: $primer_clone\n";
	warn "\tprimer_sequence:\n$primer_sequence\n";
	warn "\tprimer_p1: $primer_p1\n";
	warn "\tprimer_p1_seq:\n$primer_p1_seq\n";
	warn "\tprimer_p2: $primer_p2\n";
	warn "\tprimer_p2_seq:\n$primer_p2_seq\n";
	warn "\tdescription:\n$description\n";
	warn "\tcategories:\n";
	warn Dumper @$categories;
	warn "\n\n";
    }
    
    # by default everything is correct, increment this value as errors
    # are found
    my $failure = 0;
    
    print "<div class=\"error\">\n";
    
    # perform checks to make sure that all required data was submitted
    if (!$file) {
	$failure++;
	print "Please select a file to upload.<br />\n";
    }
    if (!$name) {
	$failure++;
	print "Please enter a name for this experiment<br />\n";
    }
    if (!$year) {
	$failure++;
	print "Please select the year this experiment was performed in.<br />\n";
    }
    if (!$month) {
	$failure++;
	print "Please select the month this experiment was performed in.<br />\n";
    }
    if (!$day) {
	$failure++;
	print "Please select the day this experiment was performed on.<br />\n";
    }
    if (!$organism) {
	$failure++;
	print "Please select an organism.<br />\n";
    }
    if (!$tissue) {
	$failure++;
	print "Please enter the tissue for this experiment.<br />\n";
    }
    if (!$stage) {
	$failure++;
	print "Please enter the developmental stage.<br />\n";
    }
    if (!$primer) {
	$failure++;
	print "Please enter the primer.<br />\n";
    }
    if (($primer_p1 && !$primer_p1_seq) || ($primer_p1_seq && !$primer_p1)) {
	$failure++;
	print "Please enter both the primer name and sequence for primer one.<br />\n";
    }
    if (($primer_p2 && !$primer_p2_seq) || ($primer_p2_seq && !$primer_p2)) {
	$failure++;
	print "Please enter both the primer name and sequence for primer two.<br />\n";
    }
    if ($primer_link_desc && !$primer_link) {
	$failure++;
	print "If you enter something for the source description, you must enter something for the source link.<br />\n";
    }
    if ($primer_link && $primer_link !~ /^http:\/\/.+/) {
	$failure++;
	print "Please ensure that the source link you entered is a full URL (i.e., that it starts with a 'http://').<br />\n";
    }
    if ($primer_clone && $primer_clone !~ /^[A-Za-z]{3}[0-9]{2}-[0-9a-zA-Z]+-[a-z0-9]+$/) {
	$failure++;
	print "Please ensure that the clone you entered is a PGN EST.<br />\n";
    }
# 	if (@$categories < 1) {
# 		$failure++;
# 		print "Please select the categories that apply to this experiment.<br />\n";
# 	}
    
    print "</div>\n";
    
    if ($failure>0) {
	# start over, retaining all data it is possible to retain
	print_form(
		   $starttime,
		   $file,
		   $name,
		   $year,
		   $month,
		   $day,
		   $organism,
		   $tissue,
		   $stage,
		   $primer,
		   $primer_link_desc,
		   $primer_link,
		   $primer_clone,
		   $primer_sequence,
		   $primer_p1,
		   $primer_p1_seq,
		   $primer_p2,
		   $primer_p2_seq,
		   $description,
		   $categories
		   );
    }
    else {
	# go to the next step
	process_submission(
			   $person_id,
			   $starttime,
			   $local_file,
			   $file,
			   $name,
			   $year,
			   $month,
			   $day,
			   $organism,
			   $tissue,
			   $stage,
			   $primer,
			   $primer_link_desc,
			   $primer_link,
			   $primer_clone,
			   $primer_sequence,
			   $primer_p1,
			   $primer_p1_seq,
			   $primer_p2,
			   $primer_p2_seq,
			   $description,
			   $categories
			   );
    }
}

#####################################################################
# do prep grunt work, and acquire some more metadata
sub process_submission {
    my ($person_id, $starttime, $local_file, $file, $name, $year, $month, $day, $organism, $tissue, $stage, $primer, $primer_link_desc, $primer_link, $primer_clone, $primer_sequence, $primer_p1, $primer_p1_seq, $primer_p2, $primer_p2_seq, $description, $categories) = @_;
    my $date = "$year-$month-$day";
    if ($debug) {
	warn "\nprocess_submission input: \n";
	warn "\tperson_id: $person_id\n";
	warn "\tstarttime: $starttime\n";
	warn "\tfile: $file\n";
	warn "\tlocal filename: $local_file\n";
	warn "\texperiment name: $name\n";
	warn "\tdate: $date\n";
	warn "\torganism_id: $organism\n";
	warn "\ttissue: $tissue\n";
	warn "\tdevelopmental stage: $stage\n";
	warn "\tprimer: $primer\n";
	warn "\tprimer_link_desc: $primer_link_desc\n";
	warn "\tprimer_link: $primer_link\n";
	warn "\tprimer_clone: $primer_clone\n";
	warn "\tprimer_sequence:\n$primer_sequence\n";
	warn "\tprimer_p1: $primer_p1\n";
	warn "\tprimer_p1_seq:\n$primer_p1_seq\n";
	warn "\tprimer_p2: $primer_p2\n";
	warn "\tprimer_p2_seq:\n$primer_p2_seq\n";
	warn "\tdescription:\n$description\n";
	warn "\tcategories:\n";
	#warn Dumper @$categories;
	warn "\n\n";
    }
    
    # figure out what type of file this is, unpack it
    my @images = ();
	my $error_msg;
    if ($local_file =~ m/(\.tgz)|(\.tar\.gz)$/i ) { # gzipped tar file
	$debug and warn "Unpacking gzipped tar file...\n";
	@images = unpack_tgz($local_file);
    }
    elsif ($local_file =~ m/(\.tar.bz2)|(\.bz2)$/i ) { # bzipped tar file
	$debug and warn "Unpacking bzip2ed tar file...\n";
	@images = unpack_tbz2($local_file);
    }
    elsif ($local_file =~ m/\.tar$/i ) { # uncompressed tar file
	$debug and warn "Unpacking tar file...\n";
	@images = unpack_tar($local_file);
    }
    elsif ($local_file =~ m/\.zip$/i ) { # zip file
	$debug and warn "Unpacking zip file...\n";
	@images = unpack_zip($local_file);
    }
    elsif ($local_file =~ m/\.bz2$/i ) { # bzip2ed file
	$debug and warn "Unpacking bz2 file...\n";
	@images = unpack_bz2($local_file);
    }
    elsif ($local_file =~ m/\.gz$/i ) { # gzipped file
	$debug and warn "Unpacking gz file...\n";
	@images = unpack_gz($local_file);
    }
    else { # unknown file type
	$debug and warn "Unknown file type!\n";

	$error_msg .= "<div class=\"error\">Unknown file type!</div>\n";
	$error_msg .= "Please go <a href=\"javascript:history.back(1)\">back</a> and upload a different file- this program is unable to unpack files of this file type.\n"; 
	happy_death($error_msg);
    }
    
    # make sure we have at least one image
    if (@images<1) {
	$error_msg .= "<div class=\"error\">Error unpacking file!</div>\n";
	$error_msg .= "We were unable to extract any image files from the file you uploaded.  Please ensure that the file you submitted was of a supported file type.\n";
	happy_death($error_msg);
    }
    
    # insert experiment info into database so that we can get an
    # experiment_id to associate with the uploaded images
    my $experiment_id = $tag_table->insert_experiment($name, $date, $organism, $tissue, $stage, $primer, $primer_link_desc, $primer_link, $primer_clone, $primer_sequence, $primer_p1, $primer_p1_seq, $primer_p2, $primer_p2_seq, $description, $categories, $person_id);
    $debug and warn "experiment has been inserted into database with experiment_id $experiment_id\n";
    
    # do all the work in moving, copying, resizing, databasing, etc., images
    process_images(\@images, $experiment_id);
    
    print "<p>Please enter any additional information you may have about these images.</p><p>All of this information is optional, and each image will already be associated with the categories selected for this experiment.</p>\n\n";
    
    # get all the images that were just inserted, print them all so that
    # any additional information for them can be entered
    my %images = $tag_table->return_images($experiment_id);
    if ($debug > 2) {
	warn "\n\nprocess: images info:\n ";
	warn Dumper \%images;
	warn "\n\n";
    }
    
    # print off the start of the form
    print "<form method=\"post\" action=\"$script_name\">\n";
    print "<input type=\"hidden\" name=\"op\" value=\"submit_2\" />\n";
    print "<table border=\"1\" cellpadding=\"10\" cellspacing=\"5\">\n\n";
    
    # alternate bg color for image rows to make things more legible
    my $row = 1;
    foreach my $image (keys %images) {
	my $color = "#FFFFFF";
	if ($row%2) {
	    $color = "#DDDDDD";
	}
	
	# print form elements to modify this images data
	print "<tr bgcolor=\"$color\"><td class=\"fielddef\" style=\"text-align:center\" width=\"250\" valign=\"top\">\n";
	
	# print a thumnail of the image, which will open the fullsized image
	# in a new window when clicked
	print "<a href=\"/thumbnail_images/${experiment_id}/$images{$image}[2].jpg\" onclick=\"javascript: window.open('/fullsize_images/${experiment_id}/$images{$image}[2]$images{$image}[3]', 'blank', 'toolbar=no'); return false;\"><img src=\"/thumbnail_images/${experiment_id}/$images{$image}[2]_${thumb_suffix}.jpg\" border=\"0\" width=\"$thumb_size\" alt=\"image id: $image\" /></a><br /><em>$images{$image}[2]</em>\n\n";
	
	print "</td><td width=\"100%\">\n";
	
	# print form elements to update data for this image
	#	name
	print "<strong>Name</strong><br />\n";
	print "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<input class=\"fieldinput\" type=\"text\" name=\"${image}_name\" value=\"\"/>\n";
	print "<br />\n";
	
	#	description
	print "<strong>Description</strong><br />\n";
	print "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<textarea name=\"${image}_description\" class=\"fieldtext\"></textarea>\n";
	print "<br />\n";
	
	#	tags
	print "<strong>Additional Categories</strong> (<a style=\"font-size:smaller; text-decoration:underline; cursor: pointer;\" onclick=\"toggle('${image}_taglist'); return false;\" onfocus=\"blur()\">show/hide</a>)<br />\n";
	print "<div id=\"${image}_taglist\">\n";
	my %tags = $tag_table->return_tags();
	($debug > 2) and warn "process_submission tags from database:\n";
	($debug > 2) and warn Dumper \%tags;
	# get previously applied tags for this experiment, those should
	# already be selected here and impossible to deselect
	my %expr_tags = $tag_table->return_relevant_tags("ex", $experiment_id);
	($debug > 2) and warn "process_submission experiment tags from database:\n";
	($debug > 2) and warn Dumper \%expr_tags;
	# print out tags
	foreach my $tag_name (sort keys %tags) {
	    my $tag_desc = $tags{$tag_name}[2];
	    my $tag_id = $tags{$tag_name}[0];
	    if ($expr_tags{$tag_name}) {
		print "<div class=\"greyed_out\">";
		print "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<input class=\"fieldcheck\" type=\"checkbox\" name=\"preselected\" value=\"$tag_id\" checked=\"checked\" disabled=\"disabled\" /> $tag_name";
	    }
	    else {
		print "<div>";
		print "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<input class=\"fieldcheck\" type=\"checkbox\" name=\"${image}_category\" value=\"$tag_id\"/> $tag_name";
	    }
	    $tag_desc and print " - $tag_desc";
	    print "</div>\n";
	}
	print "</div>\n";
	print "<script language=\"JavaScript\" type=\"text/javascript\">\n<!--\ncontract('${image}_taglist');\n//-->\n</script>\n";
	
	print "</td></tr>\n\n";
	
	$row++;
    }
    # print submit button, close out form
    my $color = "#FFFFFF";
    if ($row%2) {
	$color = "#DDDDDD";
    }
    print "<tr bgcolor=\"$color\"><td class=\"fielddef\" style=\"text-align:center\" colspan=\"2\">\n";
    print "<input class=\"fieldinput\" type=\"submit\" value=\"Update image data\" />\n";
    print "</td></tr>\n\n";
    
    print "</table>\n";
    print "</form>\n\n";
    
}

#####################################################################
# enter additional image data
sub finalize_submission {
    my $img_data = shift;
    ($debug > 0) and warn Dumper $img_data;
    foreach my $img_id (keys %$img_data) {
	$tag_table->update_image_data($img_id, $img_data->{$img_id}{'name'}, $img_data->{$img_id}{'description'}, $img_data->{$img_id}{'category'});
    }
    print "<p>Your images have been updated successfully.</p><p>Thanks!</p>\n";
}

#####################################################################
# given a file, break it open and return an array containing the 
# unpacked file locations/names

sub unpack_bz2 {
    #FIXME: can't unpack bz2 yet
}

sub unpack_gz {
    #FIXME: can't unpack gz yet
}

sub unpack_tar {
    my $input_file = shift;
    $debug and warn "Incoming file: $input_file\n";
    chdir $input_dir; 
    my @output_files = ();
    my $safe_tar_options = "--mode 644 -k --force-local";
    my $command = "tar vxf ${input_file} $safe_tar_options";
    $debug and warn "Executing command:\n\t$command\n";
    my $output = `$command`;
    @output_files = split /\n/, $output;
    return @output_files;
}

sub unpack_tbz2 {
    my $input_file = shift;
    $debug and warn "Incoming file: $input_file\n";
    chdir $input_dir; 
    my @output_files = ();
    my $safe_tar_options = "--mode 644 -k --force-local";
    my $command = "tar vxjf ${input_file} $safe_tar_options";
    $debug and warn "Executing command:\n\t$command\n";
    my $output = `$command`;
    @output_files = split /\n/, $output;
    return @output_files;
}

sub unpack_tgz {
    my $input_file = shift;
    $debug and warn "Incoming file: $input_file\n";
    chdir $input_dir; 
    my @output_files = ();
    my $safe_tar_options = "--mode 644 -k --force-local";
    my $command = "tar vxzf ${input_file} $safe_tar_options";
    $debug and warn "Executing command:\n\t$command\n";
    my $output = `$command`;
    @output_files = split /\n/, $output;
    return @output_files;
}

sub unpack_zip {
    my $input_file = shift;
    $debug and warn "Incoming file: $input_file\n";
    chdir $input_dir;
    my @output_files = ();
    my $safe_zip_options = "-n";
    my $command = "unzip $safe_zip_options ${input_file}";
    $debug and warn "Executing command:\n\t$command\n";
    my $output = `$command`;
    ($debug > 2) and warn "output of unzip:\n$output\n";
    @output_files = split /\n/, $output;
    my @output_filenames = ();
    foreach (@output_files) {
	if (($_ !~ /Archive:/) && ($_ =~ /inflating: (.+\.[A-Za-z0-9]{3,4})\b\s+?$/)) {
	    ($debug > 2) and warn "processing $_ ($1)...\n";
	    push @output_filenames, $1;
	}
	else { ($debug > 2) and warn "skipping $_...\n"; }
    }
    return @output_filenames;
}

#####################################################################
# given a list of unpacked files, create thumbnail and midsize images
# and copy all files to the correct places.
# $display_dir is for resized images
# $fullsize_dir is for original high resolution images
sub process_images {
    my ($original_files, $experiment_id) = @_;
    # create subdirectories for these images to live in
    my ($fullsize_path, $display_path);
    $fullsize_path = "${fullsize_dir}/$experiment_id";
    $display_path = "${display_dir}/$experiment_id";
    $debug and warn "Creating:\n\tfullsize directory: $fullsize_path\n\tdisplay directory: $display_path\n";
    # these commands shouldn't do any harm if these directories already exist
    system("mkdir $fullsize_path");
    system("chmod 775 '$fullsize_path'");
    system("mkdir $display_path");
    system("chmod 775 '$display_path'");
    
    # process each image
    foreach my $file (@$original_files) {
	my ($safe_file, $safe_ext, $unix_file);
	$safe_file = $file;
	$safe_file =~ m/(.*)(\.[a-zA-Z0-9]{3,4})$/i;
	$safe_file = $1;
	$safe_ext = $2;
	$unix_file = $safe_file;
	$unix_file =~ s/\s/_/g;
	
	$debug and warn "filename: $file\n\tsafe name: $safe_file\n\tunix name: $unix_file\n\textension: $safe_ext\n";
	
	# copy unmodified image to be fullsize image
	system("mv '${input_dir}/$file' '${fullsize_path}/${unix_file}${safe_ext}'");
	system("chmod 664 '${fullsize_path}/${unix_file}${safe_ext}'");
	
	# convert to jpg if format is different
	if ($safe_ext !~ /jpg/i || $safe_ext !~ /jpeg/i) {
	    system("/usr/bin/convert ${fullsize_path}${safe_ext} ${fullsize_path}.jpg");
	    $safe_ext = ".jpg";
	}
	
	# create small thumbnail for each image
	copy_image_resize("${fullsize_path}/${unix_file}${safe_ext}", "${display_path}/${unix_file}_${thumb_suffix}.jpg", "$thumb_size");
	
	# create midsize image for each image
	copy_image_resize("${fullsize_path}/${unix_file}${safe_ext}", "${display_path}/${unix_file}_${large_suffix}.jpg", "$large_size");
	
	# enter preliminary image data into database
	$tag_table->insert_image($experiment_id, $unix_file, ${safe_ext});	
    }
}

#####################################################################
# given an image file, and a size (see configuration),
# copy the image to a resized version
sub copy_image_resize {
    my ($original_image, $new_image, $width) = @_;
    
    $debug and warn "\tCopying $original_image to $new_image and resizing it to $width px wide\n";
    
    # first copy the file
    system("cp '$original_image' '$new_image'");
    system("chmod 664 '$new_image'");
    
    # now resize the new file, and ensure it is a jpeg
    my $resize = `mogrify -geometry $width '$new_image'`;
    my $jpeg = `mogrify -format jpg '$new_image'`;
    
    if ($resize || $jpeg) {
	happy_death("An error occurred while rezising $original_image:<div class=\"error\">$resize</div> <div class=\"error\">$jpeg</div>")
	}
    else {
	return 1;
    }
    
}

#####################################################################
# Print error and exit, closing the page
sub happy_death {
    my $message = shift;
    print $message;
    $page->footer();
    exit;
}

