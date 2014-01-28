#!/usr/bin/perl
use strict;
use warnings;

use lib 't/lib';
use SGN::Test qw/validate_urls/;

use Test::More tests => 33;
use SGN::Test::WWW::Mechanize;
use CXGN::GEM::Schema;

my $base_url = $ENV{SGN_TEST_SERVER};
my $mech = SGN::Test::WWW::Mechanize->new;

$mech->with_test_level( local => sub {

    ## First take variables for the test from the database ##

    my @schema_list = ('gem', 'biosource', 'metadata', 'public');
    my $schema_list = join(',', @schema_list);
    my $set_path = "SET search_path TO $schema_list";

    my $dbh = $mech->context()->dbc()->dbh();
    
    my $schema = CXGN::GEM::Schema->connect( sub { $dbh }, 
					     {on_connect_do => $set_path} );

    ## WWW. DETAIL PAGES ###

    ## TEMPLATE ##
    ## Take a template, an experiment name and a platform name

    my ($template_row) = $schema->resultset('GeTemplate')
                                ->search( undef, 
                                          { 
					      order_by => {-asc => 'template_id'}, 
					      rows     => 1, 
					  }
				        );

    if (defined $template_row) {

	my $template_id = $template_row->get_column('template_id');
	my $template_name = $template_row->get_column('template_name');
	
	$mech->get_ok("$base_url/gem/template.pl?id=$template_id");
	$mech->content_like(qr/Expression Template: $template_name/);
	$mech->content_unlike( qr/ERROR PAGE/ );

	$mech->get_ok("$base_url/gem/template.pl?name=$template_name");
	$mech->content_like(qr/Expression Template: $template_name/);
	$mech->content_unlike( qr/ERROR PAGE/ );
    }

    ## EXPERIMENT ##

    my ($experiment_row) = $schema->resultset('GeExperiment')
                                ->search( undef, 
                                          { 
					      order_by => {-asc => 'experiment_id'}, 
					      rows     => 1, 
					  }
				        );

    if (defined $experiment_row) {

	my $experiment_id = $experiment_row->get_column('experiment_id');
	my $experiment_name = $experiment_row->get_column('experiment_name');

	$mech->get_ok("$base_url/gem/experiment.pl?id=$experiment_id");
	$mech->content_unlike( qr/ERROR PAGE/ );
	$mech->content_like( qr/Expression Experiment: $experiment_name/ );

	$mech->get_ok("$base_url/gem/experiment.pl?name=$experiment_name");
	$mech->content_unlike( qr/ERROR PAGE/ );
	$mech->content_like( qr/Expression Experiment: $experiment_name/ );

	$mech->get_ok("$base_url/gem/experiment.pl?name=foob");
	$mech->content_unlike( qr/ERROR PAGE/ );
	$mech->content_like( qr/No experiment data for the specified parameters/);	
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

	$mech->get_ok("$base_url/gem/platform.pl?name=$platform_name");
	$mech->content_like(qr/Expression Platform: $platform_name/);
	$mech->content_unlike( qr/ERROR PAGE/ );

	$mech->get_ok("$base_url/gem/platform.pl?id=$platform_id");
	$mech->content_like(qr/Expression Platform: $platform_name/);
	$mech->content_unlike( qr/ERROR PAGE/ );
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
	
	$mech->get_ok("$base_url/gem/experimental_design.pl?id=$expdesign_id");
	$mech->content_like(qr/Expression Experimental Design:\s+$expdesign_name/);
	$mech->content_unlike( qr/ERROR PAGE/ );

	$mech->get_ok("$base_url/gem/experimental_design.pl?name=$expdesign_name");
	$mech->content_like(qr/Expression Experimental Design:\s+$expdesign_name/);
	$mech->content_unlike( qr/ERROR PAGE/ );
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

	$mech->get_ok("$base_url/gem/target.pl?name=$target_name");
	$mech->content_like(qr/Expression Target: $target_name/);
	$mech->content_unlike( qr/ERROR PAGE/ );
	
	$mech->get_ok("$base_url/gem/target.pl?id=$target_id");
	$mech->content_like(qr/Expression Target: $target_name/);
	$mech->content_unlike( qr/ERROR PAGE/ );
    }

});






