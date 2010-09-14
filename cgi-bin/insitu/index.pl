#!/usr/bin/perl -w

# This script will print a form so that users may upload a gzipped file of
# insitu images from an experiment and metadata about that experiment.
#
# The data will be loaded into the database, and thumbnail images will be 
# created for each uploaded image.
#
# The data will be displayed later on with the insitu_view script.

use strict;
use warnings;
use CXGN::Page;
use CXGN::Insitu::DB;
use Data::Dumper;
use CXGN::Insitu::Toolbar;

use CatalystX::GlobalContext '$c';

our $debug = 2; # higher for more verbosity

# directory this script will move renamed fullsize images to
my $fullsize_dir = $c->config->{insitu_fullsize_dir};
# directory this script will move  shrunken images to
my $display_dir = $c->config->{insitu_display_dir};

# suffix / resolution for thumbnail images
my $thumb_suffix = "_thumb";
my $thumb_size = "200";

# suffix / resolution for large (but not fullsize) images
my $large_suffix = "_mid";
my $large_size = "600";

my $dbh = CXGN::DB::Connection->new();

my $insitu_db = CXGN::Insitu::DB->new($dbh);

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

$page->footer();
