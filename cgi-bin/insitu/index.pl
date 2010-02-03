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
use CXGN::Insitu::DB;
use Data::Dumper;
use CXGN::Insitu::Toolbar;
use CXGN::VHost;

#####################################################################
#####################################################################
# Configuration
#####################################################################
#####################################################################

our $debug = 2; # higher for more verbosity

# directory this script will move renamed fullsize images to
my $conf = CXGN::VHost->new();
my $fullsize_dir = $conf->get_conf("insitu_fullsize_dir");
# directory this script will move  shrunken images to
my $display_dir = $conf->get_conf("insitu_display_dir");

# suffix / resolution for thumbnail images
my $thumb_suffix = "_thumb";
my $thumb_size = "200";

# suffix / resolution for large (but not fullsize) images
my $large_suffix = "_mid";
my $large_size = "600";


#####################################################################
#####################################################################
# Stuff happens here
#####################################################################
#####################################################################

# set up DB connection
#our $tag_table = CXGN::Insitu->new();
my $dbh = CXGN::DB::Connection->new();

my $insitu_db = CXGN::Insitu::DB->new($dbh);


# get name of this script
#our $script_name = $0;
#if ($script_name =~ /(\/cgi-bin\/.*)/) {
#	$script_name = $1;
#}

# display what needs displaying, do what needs doing
####################################################
our $page = CXGN::Page->new( "Insitu DB", "Teri");
$page->header("Insitu DB", "Insitu Database");

my ($experiment_count, $image_count, $tag_count) = $insitu_db->stats();

CXGN::Insitu::Toolbar::display_toolbar("Insitu home");

print qq {
    <br /><br /><table summary=""><tr><td><img src="/documents/insitu/insitu_logo.jpg" border="0" alt="" /></td><td width="20">&nbsp;</td><td>
    The insitu database currently contains:<br />


	   $experiment_count experiments<br />
	   $image_count images and <br />
	   $tag_count tags.<br />
      	   <a href="/insitu/search.pl?experiment_name=">[Browse]</a><br />
	   <br />
	   <br />
          <b>This database is supported by the <a href="http://floralgenome.org">Floral Genome Project</a> funded by the <a href="http://www.nsf.gov/">NSF</a>. <br /></b>
	 
	   <br /><br /><br />

</td></tr></table>

       };

#my $query = new CGI;

#my ($op) = $page->get_arguments("op");

# if ($query->param('op')) {
# 	# the form has been submitted before
# 	if ($query->param('op') eq "experiment") {
# 		print_default(display_experiment($query->param('id')));
# 	}
# 	elsif ($query->param('op') eq "tag") {
# 		print_default(display_tag($query->param('id')));
# 	}
# 	elsif ($query->param('op') eq "image") {
# 		print_default(display_image($query->param('id')));
# 	}
# 	elsif ($query->param('op') eq "probe") {
# 		print_default(display_primer($query->param('id')));
# 	}
# 	elsif ($query->param('op') eq "probes") {
# 		print_default(display_primers());
# 	}
# 	elsif ($query->param('op') eq "organism") {
# 		print_default(display_organism($query->param('id')));
# 	}
# 	elsif ($query->param('op') eq "user") {
# 		print_default(display_user($query->param('id')));
# 	}
# 	else {
# 		# unknown operation; this shouldn't happen
# 		print "<div class=\"error\">An error has occured!</div>";
# 		print_default();
# 	}
# } else {
# 	# first run; default operation
# 	print_default();
# }

$page->footer();


#####################################################################
#####################################################################
# Functions
#####################################################################
#####################################################################

#####################################################################
# default operation; print form

# sub print_default {
# 	my $content_area = shift;
# 	my $tag_table;
# 	# set default content here, in case none was sent with this function
# 	$content_area ||= <<END_CONTENT;
# <p>Please use the list on the left to select the images you want to see.</p>
# END_CONTENT
# 	if ($debug > 2) {
# 		warn "print_default printing:\n";
# 		warn "$content_area\n";
# 	}
	
# 	my ($experiment_list, $tag_list);

# 	# generate list of experiments
# 	my %experiments = $tag_table->return_experiments;
# 	if ($debug>2) {
# 		warn "print_default: all experiments:\n";
# 		warn Dumper \%experiments;
# 	}
# 	foreach my $experiment (sort keys %experiments) {
# 		$experiment_list .= "<p class=\"sub-item\"><a href=\"?op=experiment&amp;id=$experiment\">$experiments{$experiment}{name}</a></p>\n";
# 	}
	
# 	# generate list of tags
# 	my %tags = $tag_table->return_tags();
# 	if ($debug>2) {
# 		warn "print_default: all tags:\n";
# 		warn Dumper \%tags;
# 	}
# 	$tag_list = get_tag_links_menu(\%tags);
	
# 	# generate organism list
# 	my %organisms = $tag_table->return_organisms();
# 	if ($debug>2) {
# 		warn "print_default: all organisms:\n";
# 		warn Dumper \%organisms;
# 	}
# 	my $organism_list = get_organism_links(\%organisms);
	
# 	# print out page content
# 	print <<HTMLFOO;
# <center><table border="0" cellpadding="0" cellspacing="0" width="100%"><tr><td width="200" align="left" valign="top" class="view-box">
# 	<div class="view-heading">
# 		Organisms
# 	</div>
# 	<div class="view-sub">
# $organism_list
# 	</div>
# 	<div class="view-heading">
# 		<a href="?op=probes">Probes</a>
# 	</div>
# 	<div class="view-sub">
# 	</div>
# 	<div class="view-heading">
# 		Experiments
# 	</div>
# 	<div class="view-sub">
# $experiment_list
# 	</div>
# 	<div class="view-heading">
# 		Categories
# 	</div>
# 	<div class="view-sub">
# $tag_list
# 	</div>
# </td><td align="left" valign="top" class="content-area">
# $content_area
# </td></tr></table></center>
# HTMLFOO
# }

# #####################################################################
# # get all information from an experiment, including images
# sub display_experiment {
# 	my $experiment_id = shift;
# 	$debug and warn "Displaying information for experiment $experiment_id\n";
# 	my $output;

# 	# get general information for experiment
# 	$output .= get_experiment_string($experiment_id);
# 	$output .= "<hr noshade=\"noshade\" />\n\n";
	
# 	# get images in this experiment
# 	my %images = $tag_table->return_images($experiment_id);
# 	if ($debug > 2) {
# 		warn "display_experiment images:\n";
# 		warn Dumper \%images;
# 	}
# 	my $div_width = $thumb_size+10;
# 	foreach my $image (sort keys %images) {
# 		$output .= <<IMAGE;
# <div class="thumb_disp" style="width: ${div_width}px">
# 	<a href="?op=image&amp;id=$image"><img src="/thumbnail_images/${experiment_id}/$images{$image}[2]__thumb.jpg" border="0" width="$thumb_size" alt="image id: $image" /></a>
# </div>
# IMAGE
# 	}
	
# 	return $output;
# }

#####################################################################
# display an image, with experiment info
# sub display_image {
# 	my $image_id = shift;
# 	$debug and warn "Displaying information for image $image_id\n";
# 	my $output;

# 	# get general information for image
# 	my %image = $tag_table->return_image($image_id);
# 	if ($debug > 2) {
# 		warn "display_image experiment:\n";
# 		warn Dumper \%image
# 	}

# 	# generate output displaying mid-sized image, with link to open
# 	# full sized image in a new window
# 	$output .= <<IMAGE_DISPLAY;
# <center>
# <a href="/thumbnail_images/$image{experiment_id}/$image{filename}.jpg" onclick="javascript: window.open('/fullsize_images/$image{experiment_id}/$image{filename}$image{file_ext}', 'blank', 'toolbar=no'); return false;"><img src="/thumbnail_images/$image{experiment_id}/$image{filename}_${large_suffix}.jpg" border="0" width="$large_size" alt="image id: $image_id" /></a><br /><em>$image{filename}</em></center>
# IMAGE_DISPLAY
# 	$output .= "<hr noshade=\"noshade\" />\n\n";
	
# 	# generate table showing additional information for this image
# 	if ($image{name} || $image{description} || (keys(%{$image{tags}})>0)) {
# 		$output .= <<IMAGE_INFO;
# <center><table border="0" cellpadding="0" cellspacing="0" width="90%">
# <tr>
# 	<th class="fielddef" style="text-align:center" colspan="2">Image Info</td>
# </tr>
# IMAGE_INFO
# 		if ($image{name}) {
# 			$output .= <<IMAGE_NAME;
# <tr>
# 	<td class="fielddef">Name</td>
# 	<td class="fieldinput">$image{name}</td>
# </tr>
# IMAGE_NAME
# 		}
# 		if ($image{description}) {
# 			$output .= <<IMAGE_DESC;
# <tr>
# 	<td class="fielddef">Description</td>
# 	<td class="fieldinput">$image{description}</td>
# </td>
# IMAGE_DESC
# 		}
# 		if (keys(%{$image{tags}})>0) {
# 			# first make sure to kill any redundancy with the experiment tags
# 			my %expr_tags = $tag_table->return_relevant_tags("ex", $image{experiment_id});
# 			my %new_image_tags = ();
# 			foreach my $img_tag (keys %{$image{tags}}) {
# 				if (!$expr_tags{$img_tag}) {
# 					($debug>1) and warn "setting tag $img_tag for image\n";
# 					$new_image_tags{$img_tag} = $image{tags}{$img_tag};
# 				}
# 				else {
# 					($debug>1) and warn "tag $img_tag is set for both experiment and image!\n";
# 				}	
# 			}
# 			my $categories = get_tag_links(\%new_image_tags);
# 			(keys(%new_image_tags)>0) and $output .= <<IMAGE_TAGS;
# <tr>
# 	<td class="fielddef">Categories</td>
# 	<td class="fieldinput">$categories</td>
# </tr>
# IMAGE_TAGS
# 		}
# 		$output .= "</table></center>\n";
# 		$output .= "<hr noshade=\"noshade\" />\n\n";
# 	}

# 	# generate table showing information about this experiment
# 	$output .= get_experiment_string($image{experiment_id});
	
# 	return $output;
# }

#####################################################################
# get information about the specified primer
# sub display_primer {
# 	my $primer_id = shift;
# 	my %primer = $tag_table->return_primer($primer_id);
# 	my ($output, $id, $name, $p1, $p1_seq, $p2, $p2_seq, $seq, $clone, $link, $link_desc) = "";
# 	$id = $primer{id};
# 	$name = <<PRIMER_NAME;
# <tr><td class="fielddef" colspan="2" style="text-align:center">
# $primer{name}
# </td></tr>
# PRIMER_NAME
# 	if ($primer{primer1}) {
# 		$p1 = <<PRIMER_P1;
# <tr><td class="fielddef">Primer One</td>
# <td>$primer{primer1}</td></tr>
# PRIMER_P1
# 	}
# 	if ($primer{primer1_seq}) {
# 		$p1_seq = <<PRIMER_P1_SEQ;
# <tr><td class="fielddef">Primer One Sequence</td>
# <td>$primer{primer1_seq}</td></tr>
# PRIMER_P1_SEQ
# 	}
# 	if ($primer{primer2}) {
# 		$p2 = <<PRIMER_P2;
# <tr><td class="fielddef">Primer Two</td>
# <td>$primer{primer2}</td></tr>
# PRIMER_P2
# 	}
# 	if ($primer{primer2_seq}) {
# 		$p2_seq = <<PRIMER_P2_SEQ;
# <tr><td class="fielddef">Primer Two Sequence</td>
# <td>$primer{primer2_seq}</td></tr>
# PRIMER_P2_SEQ
# 	}
# 	if ($primer{sequence}) {
# 		$seq = <<PRIMER_SEQ;
# <tr><td class="fielddef">Probe Sequence</td>
# <td>$primer{sequence}</td></tr>
# PRIMER_SEQ
# 	}
# 	if ($primer{clone}) {
# 		$clone = <<PRIMER_CLONE;
# <tr><td class="fielddef">Clone</td>
# <td><a href="http://pgn.cornell.edu/cgi-bin/search/seq_search_result.pl?identifier=$primer{clone}">$primer{clone}</a></td></tr>
# PRIMER_CLONE
# 	}
# 	if ($primer{link} && $primer{link_desc}) {
# 		$link = <<PRIMER_LINK;
# <tr><td class="fielddef">Source</td>
# <td><a href="$primer{link}">$primer{link_desc}</a></td></tr>
# PRIMER_LINK
# 	}
# 	$output .= <<PRIMER_INFO;
# <center><table border="0" cellpadding="0" cellspacing="0" width="90%">
# $name
# $p1
# $p1_seq
# $p2
# $p2_seq
# $seq
# $clone
# $link
# </table></center>
# PRIMER_INFO

# 	# get experiments that this primer was used for
# 	my %results = $tag_table->get_primer_items($id);
# 	my $num_results = keys %results;
# 	$output .= "$num_results experiments found for $primer{name}<br />\n";
# 	$output .= get_experiment_links(\%results);

# 	return $output;
# }

#####################################################################
# get information about all primers
# sub display_primers {
# 	my $output;
# 	my %primers = $tag_table->return_primers();
# 	$output .= "<div style=\"text-align:center\">\n";
# 	foreach my $primer (sort keys %primers) {
# 		$output .= "<a href=\"?op=probe&amp;id=$primers{$primer}{id}\">$primer</a><br />\n";
# 	}
# 	$output .= "</div>\n";
# 	return $output;
# }

#####################################################################
# get all experiments for specified organism
# sub display_organism {
# 	my $org_id = shift;
# 	my $output;
# 	if ($debug > 1) {
# 		warn "display_organism searching for organism id $org_id\n";
# 	}

# 	# get basic info about this organism
# 	my %organism =$tag_table->return_organism($org_id);

# 	# search for all experiments involving this organism
# 	my %results = $tag_table->get_organism_items($org_id);

# 	my $num_results = keys %results;
	
# 	$output .= "$num_results matches found for $organism{name}<br />\n";
# 	$output .= get_experiment_links(\%results);

# 	return $output;
# }

#####################################################################
# get all experiments submitted by specified user
# sub display_user {
# 	my $user_id = shift;
# 	my $output;
# 	if ($debug > 1) {
# 		warn "display_user searching for user id $user_id\n";
# 	}

# 	my $username=$user_id;# get basic info about this user
# 	my $user = CXGN::People::Person->new($user_id);
#         if($user)
# 	{
# 	    $username = $user->get_first_name() . " " . $user->get_last_name();
# 	    $username ||= $user->get_username();
# 	}
	
# 	# search for all experiments submitted by this user
# 	my %results = $tag_table->get_user_items($user_id);

# 	my $num_results = keys %results;

# 	$output .= "$num_results experiments submitted by $username<br />\n";
# 	$output .= get_experiment_links(\%results);

# 	return $output;
# }

#####################################################################
# get all experiments and images that use $tag
# sub display_tag {
# 	my $tag_string = shift;
# 	my @search_tags = split /\./,$tag_string;
# 	if ($debug>2) {
# 		warn "display_tag searching for categories:\n";
# 		warn Dumper \@search_tags;
# 	}

# 	# get a human parseable interpretation of the search tags
# 	my ($tag_name_string, $count, $ack_string);
# 	$count = 0;
# 	my %tags;
# 	foreach (@search_tags) {
# 		$count++;
# 		$tags{$_} = $tag_table->return_tag($_);
# 		if ($count == @search_tags) { # is this the last item?
# 			$tag_name_string .= "and '<em>$tags{$_}</em>'";
# 		}
# 		else {
# 			$tag_name_string .= "'<em>$tags{$_}</em>', ";
# 		}
# 	}
# 	if ($count>1) {
# 		$tag_name_string =~ s/, and / and /;
# 	}
# 	else {
# 		$tag_name_string =~ s/and //;
# 	}

# 	# search for all experiments and images which these tags apply to
# 	my %results = $tag_table->get_tagged_items(\@search_tags);
	
# 	my $total_matches = $results{matches}{experiments} + $results{matches}{images};
# 	($debug>1) and warn "$total_matches match(es) found.\n";
	
# 	# if there are any other tags that are common to these results, print
# 	# a list of them to narrow the results
# 	my $tag_name="";
# 	my $tag_id="";
# 	my $tag_desc="";
# 	my $sub_tag_string = "\n\n<!-- no sub tags found! -->\n\n";
# 	if ((scalar(keys %{$results{sub_tags}})) && ($total_matches>1)) {
# 		my $sub_tags;
# 		foreach my $sub_tag (sort keys %{$results{sub_tags}}) {
# 			$tag_name = $sub_tag;
# 			$tag_id = $results{sub_tags}{$sub_tag}[0];
# 			$tag_desc = $results{sub_tags}{$sub_tag}[2];
# 			$tag_desc ||= $tag_name;
# 			if (($tag_string !~ m/^($tag_id)/) && 
# 				($tag_string !~ m/\.$tag_id$/) &&
# 				($tag_string !~ m/\.$tag_id\./))
# 			{
# 				$sub_tags .= ", <a href=\"?op=tag&amp;id=${tag_string}.${tag_id}\" title=\"$tag_desc\">$tag_name</a>";
# 			}
# 		}
# 		$sub_tags =~ s/^, //;
# 		$sub_tag_string = <<SUB_TAGS;
# <div class="sub-content">
# <strong>Narrow down results:</strong><br />
# $sub_tags
# </div>
# SUB_TAGS
# 	}

# 	# compile list of experiments
# 	my $experiment_string = get_experiment_links($results{experiments});
	
# 	# compile list of images
# 	my $image_string = "\n\n<!-- no images found! -->\n\n";
# 	my $img_odd = 0;
# 	if (scalar(keys %{$results{images}})) {
# 		my $images;
# 		foreach my $image (sort keys %{$results{images}}) {
# 			$img_odd++;
# 			my $bgcolor="#FFFFFF";
# 			($img_odd%2) and $bgcolor="#DDDDDD";
# 			my $description = $results{images}{$image}{description};
# 			$description =~ s!\r!!g;
# 			$description =~ s!\n!<br />!g;
# 			$images .= <<IMAGE;
# <tr bgcolor="$bgcolor">
# <td valign="top" align="center">
# <a href="?op=image&amp;id=$image"><img src="/thumbnail_images/$results{images}{$image}{experiment}/$results{images}{$image}{filename}_${thumb_suffix}.jpg" border="0" width="$thumb_size" alt="image id: $image" /></a>
# </td><td>
# <em>$results{images}{$image}{filename}</em><br />\n
# IMAGE
# 			$results{images}{$image}{name} and $images .= "<strong>Name</strong>: $results{images}{$image}{name}<br />\n";
# 			$results{images}{$image}{description} and $images .= "<strong>Descripton</strong>:<br />$description<br />\n";
# 			$results{images}{$image}{tags} and $images .= "<strong>Categories</strong>:<br />".get_tag_links($results{images}{$image}{tags})."\n";
# 			$images .= <<IMAGE;
# </td>
# </tr>
# IMAGE
# 		}
# 		$image_string = <<IMAGE_STRING;
# <p style="text-align:left; font-size: larger;">Images:</p>
# <center>
# <table border="1" width="95%" cellpadding="5" cellspacing="0">
# $images
# </table>
# </center>
# IMAGE_STRING
# 	}
	
# 	my $output = <<OUTPUT_STRING;
# <p style="text-align:left; font-size: larger;">$total_matches matches found for ${tag_name_string}</p>
# ${sub_tag_string}
# $experiment_string
# $image_string
# OUTPUT_STRING
	
# 	return $output;
# }

# #####################################################################
# # given a hash of experiments, print them in a linkable manner
# sub get_experiment_links {
# 	my $experiments = shift;
# 	if ($debug > 1) {
# 		warn "get_experiment_links got:\n";
# 		warn Dumper $experiments;
# 	}
# 	my $experiment_string = "\n\n<!-- no experiments found! -->\n\n";
# 	my $exp_odd = 0;
# 	if (scalar(keys %$experiments)) {
# 		my $exps;
# 		foreach my $exp (sort keys %$experiments) {
# 			$exp_odd++;
# 			my $bgcolor="#FFFFFF";
# 			($exp_odd%2) and $bgcolor="#DDDDDD";
# 			my $description = $experiments->{$exp}{description};
# 			$description =~ s!\r!!g;
# 			$description =~ s!\n!<br />!g;
# 			$exps .= <<EXPERIMENT;
# <tr bgcolor="$bgcolor">
# <td>
# <strong>Name</strong>: <a href="?op=experiment&amp;id=$exp">$experiments->{$exp}{name}</a><br />
# <strong>Organism</strong>: <a href="?op=organism&amp;id=$experiments->{$exp}{organism_id}" title="$experiments->{$exp}{organism_common}">$experiments->{$exp}{organism_name}</a><br />
# <strong>Descripton</strong>:<br />$description<br />
# EXPERIMENT
# 			$experiments->{$exp}{tags} and $exps .= "<strong>Categories</strong>:<br />".get_tag_links($experiments->{$exp}{tags})."\n";
# 			$exps .= <<EXPERIMENT;
# </td>
# </tr>
# EXPERIMENT
# 		}
# 		$experiment_string = <<EXPERIMENT_STRING;
# <p style="text-align:left; font-size: larger;">Experiments:</p>
# <center>
# <table border="1" width="95%" cellpadding="5" cellspacing="0">
# $exps
# </table>
# </center>
# EXPERIMENT_STRING
# 	}
# 	return $experiment_string;
# }

# #####################################################################
# # given a hash of tags, print them in a linkable manner, menu-friendly
# sub get_tag_links_menu {
# 	my $tags = shift;
# 	if ($debug > 2) {
# 		warn "get_tag_links_menu received:\n";
# 		warn Dumper $tags;
# 	}
# 	my $categories;
# 	foreach my $tag (sort keys %$tags) {
# 		my $description="$tag";
# 		$tags->{$tag}[2] and $description=$tags->{$tag}[2];
# 		$categories .= "<p class=\"sub-item\"><a href=\"?op=tag&amp;id=$tags->{$tag}[0]\" title=\"$description\">$tags->{$tag}[1]</a></p>\n";
# 	}
# 	return $categories;
# }

# #####################################################################
# # given a hash of tags, print them in a linkable manner, paragraph friendly
# sub get_tag_links {
# 	my $tags = shift;
# 	if ($debug > 2) {
# 		warn "get_tag_links_menu received:\n";
# 		warn Dumper $tags;
# 	}
# 	my $categories;
# 	foreach my $tag (sort keys %$tags) {
# 		my $description="$tag";
# 		$tags->{$tag}[2] and $description=$tags->{$tag}[2];
# 		$categories .= "<a href=\"?op=tag&amp;id=$tags->{$tag}[0]\" title=\"$description\">$tags->{$tag}[1]</a>, ";
# 	}
# 	$categories =~ s/, $//;
# 	return $categories;
# }

# #####################################################################
# # given a hash of organisms, print them in a linkable manner
# sub get_organism_links {
# 	my $organisms = shift;
# 	if ($debug > 2) {
# 		warn "get_organism_links received:\n";
# 		warn Dumper $organisms;
# 	}
# 	my $orgs;
# 	foreach my $org (sort keys %$organisms) {
# 		my $description="$organisms->{$org}{common_name}";
# 		$orgs .= "<p class=\"sub-item\"><a href=\"?op=organism&amp;id=$organisms->{$org}{id}\" title=\"$description\">$organisms->{$org}{name}</a></p>\n";
# 	}
# 	return $orgs;
# }

# #####################################################################
# # generate formatted output with experiment info
# sub get_experiment_string {
# 	my $experiment_id = shift;
# 	$debug and warn "generating output string for experiment $experiment_id\n";
# 	# get general information for experiment
# 	my %experiment =  $tag_table->return_experiment($experiment_id);
# 	if ($debug > 2) {
# 		warn "get_experiment_string experiment:\n";
# 		warn Dumper \%experiment;
# 	}
# 	my $other_info = $experiment{description};
# 	$other_info ||= " ";
# 	$other_info =~ s!\r!!g;
# 	$other_info =~ s!\n!<br />!g;
# 	my $categories = get_tag_links(\%{$experiment{tags}});
# 	my $organism = $experiment{organism_name};
# 	my $user_id = $experiment{user_id};
# 	my $username = $user_id;
# 	if ($user_id) {
# 		my $user = CXGN::People::Person->new($user_id);
# 		if($user)
# 		{
# 		    $username = $user->get_first_name() . " " . $user->get_last_name();
# 		    $username ||= $user->get_username();
# 		}
# 		$username = "<a href=\"?op=user&amp;id=$user_id\">$username</a>";
# 	}
# 	my $primer = "<a href=\"?op=probe&amp;id=$experiment{primer_id}\">$experiment{primer}</a>";
# 	$experiment{organism_common} and $organism = "<span title=\"$experiment{organism_common}\">$experiment{organism_name}</span>";
# 	my $output = <<EXPERIMENT_TOP;
# <center><table border="0" cellpadding="0" cellspacing="0" width="90%">
# <tr>
# 	<th class="fielddef" style="text-align:center" colspan="2">Experiment Info</td>
# </tr>
# <tr>
# 	<td class="fielddef">Name</td>
# 	<td class="fieldinput"><a href=\"?op=experiment&amp;id=$experiment_id\">$experiment{name}</a></td>
# </tr>
# <tr>
# 	<td class="fielddef">Submitter</td>
# 	<td class="fieldinput">$username</td>
# </td>
# <tr>
# 	<td class="fielddef">Date</td>
# 	<td class="fieldinput">$experiment{date}</td>
# </tr>
# <tr>
# 	<td class="fielddef">Organism</td>
# 	<td class="fieldinput">$organism</td>
# </tr>
# <tr>
# 	<td class="fielddef">Tissue</td>
# 	<td class="fieldinput">$experiment{tissue}</td>
# </tr>
# <tr>
# 	<td class="fielddef">Stage</td>
# 	<td class="fieldinput">$experiment{stage}</td>
# </tr>
# <tr>
# 	<td class="fielddef">Probe</td>
# 	<td class="fieldinput">$primer</td>
# </tr>
# <tr>
# 	<td class="fielddef">Other Info</td>
# 	<td class="fieldinput">$other_info</td>
# </tr>
# <tr>
# 	<td class="fielddef">Categories</td>
# 	<td class="fieldinput">$categories</td>
# </tr>
# </table></center>
# EXPERIMENT_TOP
# 	return $output;
# }

# #####################################################################
# # Print error and exit, closing the page
# sub happy_death {
# 	my $message = shift;
# 	print $message;
# 	$page->footer();
# 	exit;
# }

