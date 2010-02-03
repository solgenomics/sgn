#!/usr/bin/perl -w

# This script will simply have links to other scripts which will do the
# actual work in managing data.

use CXGN::Page;
use CXGN::People;
use CXGN::Insitu::Toolbar;
our $debug = 2; # higher for more verbosity

# default operation; print form
#
sub print_default {
	my $user_type = shift;
	print "Please select which data you want to update:<br /><br />\n\n";

	print "<div class=\"subheading\">Experiments / Images</div>\n";
	print "<ul>\n";
	print "<li><a href=\"detail/experiment.pl?action=new\"><strong>Add new experiment</strong></a></li>\n";
	print "</ul>\n";

# 	print "<div class=\"subheading\">Categories</div>\n";
# 	print "<ul>\n";
# 	print "<li><a href=\"/insitu/detail/tag.pl?action=new\"><strong>Add new tag</strong></a></li>\n";
# #	print "<li><a href=\"/cgi-bin/edit_cats.pl?op=edit\"><strong>Edit categories</strong></a><br /> <em>Change category names and descriptions, as well as add implied categories, for your tags.</em></li>\n";
# 	print "</ul>\n";

	print qq { <div class="subheading">Probes</div>\n
		       <ul>\n
		       <li><a href="/insitu/detail/probe.pl?action=new"><strong>Add new probe</strong></a></li>
		       </ul> 
		   };
                      
	

	# only curators can add/edit organisms
	# FIXME -- the first submitters shouldn't be curators, but they should
	# be allowed to enter the species they want regardless
	#if ($user_type eq 'curator') {
		print "<div class=\"subheading\">Organisms</div>\n";
		print "<ul>\n";
		print "<li><a href=\"/insitu/detail/organism.pl?action=new\"><strong>Add organisms</strong></a></li>\n";
		#print "<li><a href=\"/cgi-bin/edit_species.pl?op=edit\"><strong>Edit organisms</strong></a></li>\n";
		#print "<li><a href=\"/cgi-bin/edit_species.pl?op=del\"><strong>Delete organisms</strong></a></li>\n";
		print "</ul>\n";
	#}

}

#####################################################################
#####################################################################
# Stuff happens here
#####################################################################
#####################################################################

# display what needs displaying, do what needs doing
####################################################
my $page = CXGN::Page->new( "Manage Data", "Teri");
$page->header("Insitu Manager", "<a href=\"/insitu\">Insitu</a>: Manage Data");

CXGN::Insitu::Toolbar::display_toolbar("Manage");

print_default($user_type);

$page->footer();
