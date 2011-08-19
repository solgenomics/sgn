use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

use SGN::Test::WWW::Mechanize;
use CXGN::GEM::Schema;

## define a %url hash

my %urls = ();

my $base_url = $ENV{SGN_TEST_SERVER};
my $mech = SGN::Test::WWW::Mechanize->new;

## This test are local test, so it will use the with_test_level function

$mech->with_test_level( local => sub {

    ## First take variables for the test from the database ##

    my @schema_list = ('gem', 'biosource', 'metadata', 'public');
    my $schema_list = join(',', @schema_list);

    my $dbh = $mech->context()->dbc()->dbh();

    my $schema = $mech->context->dbic_schema('CXGN::GEM::Schema');

    ## WWW. GEM SEARCH TEST ###

    $urls{"gem search page for templates"} = "/search/direct_search.pl?search=template";
    $urls{"gem search page for experiments"} = "/search/direct_search.pl?search=experiment";
    $urls{"gem search page for platforms"} = "/search/direct_search.pl?search=platform";
    
    ## WWW. RESULT AND DETAIL PAGES ###

    ## TEMPLATE ##
    ## Take a template, an experiment name and a platform name

    my ($template_row) = $schema->resultset('GeTemplate')
                                ->search( undef, 
                                          { 
					      order_by => {-asc => 'template_id'}, 
					      rows     => 1, 
					  }
				        );

    ## Now it will test the expected gem result web-page if there is at least one row 
    ## in the database. If not, it will test the error page

    if (defined $template_row) {

	my $template_id = $template_row->get_column('template_id');
	my $template_name = $template_row->get_column('template_name');
	
	$urls{'gem results page for templates'} = "/search/gem_template_search.pl?w616_template_parameters=$template_name";
	$urls{'gem template page'} = "/gem/template.pl?id=$template_id";
	$urls{'gem template page (name)'} = "/gem/template.pl?name=$template_name";	
    }

    ## EXPERIMENT ##

    my ($experiment_row) = $schema->resultset('GeExperiment')
                                ->search( undef, 
                                          { 
					      order_by => {-asc => 'experiment_id'}, 
					      rows     => 1, 
					  }
				        );

    ## Now it will test the expected gem result web-page if there is at least one row 
    ## in the database. If not, it will test the error page

    if (defined $experiment_row) {

	my $experiment_id = $experiment_row->get_column('experiment_id');
	my $experiment_name = $experiment_row->get_column('experiment_name');
	
	my @exp_frags = split(/ /, $experiment_name);
	my $partial_name = $exp_frags[0];

	$urls{'gem results page for experiments'} = "/search/gem_experiment_search.pl?w932_experiment_parameters=$partial_name";
	$urls{'gem experiment page'} = "/gem/experiment.pl?id=$experiment_id";
	$urls{'gem experiment page (name)'} = "/gem/experiment.pl?name=$experiment_name";	
    }

    ## PLATFORM ##

    my ($platform_row) = $schema->resultset('GePlatform')
                                ->search( undef, 
                                          { 
					      order_by => {-asc => 'platform_id'}, 
					      rows     => 1, 
					  }
				        );

    if (defined $platform_row) {

	my $platform_id = $platform_row->get_column('platform_id');
	my $platform_name = $platform_row->get_column('platform_name');
	
	my @plat_frags = split(/ /, $platform_name);
	my $plat_partial_name = $plat_frags[0];

	$urls{'gem results page for platform'} = "/search/gem_experiment_search.pl?w932_template_parameters=$plat_partial_name";
	$urls{'gem platform page'} = "/gem/platform.pl?id=$platform_id";
	$urls{'gem platform page (name)'} = "/gem/platform.pl?name=$platform_name";	
    }

    ## EXPERIMENTAL DESIGN ##

    my ($experimental_design_row) = $schema->resultset('GeExperimentalDesign')
                                ->search( undef, 
                                          { 
					      order_by => {-asc => 'experimental_design_id'}, 
					      rows     => 1, 
					  }
				        );

    if (defined $experimental_design_row) {

	my $expdesign_id = $experimental_design_row->get_column('experimental_design_id');
	my $expdesign_name = $experimental_design_row->get_column('experimental_design_name');

	$urls{'gem detail page for experimental design'} = "/gem/experimental_design.pl?id=$expdesign_id";
	$urls{'gem detail page for experimental design (name)'} = "/gem/experimental_design.pl?name=$expdesign_name";	
    }
 
    ## TARGET ##

    my ($target_row) = $schema->resultset('GeTarget')
                                ->search( undef, 
                                          { 
					      order_by => {-asc => 'target_id'}, 
					      rows     => 1, 
					  }
				        );

    if (defined $target_row) {

	my $target_id = $target_row->get_column('target_id');
	my $target_name = $target_row->get_column('target_name');

	$urls{'gem detail page for target'} = "/gem/target.pl?id=$target_id";
	$urls{'gem detail page for target (name)'} = "/gem/target.pl?name=$target_name";	
    }
    validate_urls(\%urls, $ENV{ITERATIONS} || 1 );

});



done_testing;
