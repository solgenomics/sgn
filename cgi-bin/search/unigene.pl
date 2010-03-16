#!/usr/bin/perl

=head1 NAME

  unigene_mason.pl
  Controller to show the web_page for unigene using MASON.

=cut

=head1 SYNOPSIS

 
=head1 DESCRIPTION

  This is the script to show the web_page using MASON

=cut

=head1 AUTHORS

 Aureliano Bombarely Gomez
 (ab782@cornell.edu)

=cut


use strict;
use warnings;

use CXGN::VHost; ## used to get tempdir... but should be replace in the new branch

use CXGN::MasonFactory;
use CXGN::Page;

use CXGN::DB::Connection;
use CXGN::DB::DBICFactory;

use CXGN::GEM::Schema;
use CXGN::Transcript::Unigene;

## Create mason object

my $m = CXGN::MasonFactory->new();

## Use of CXGN::Page to take the arguments from the URL

my $page = CXGN::Page->new();

my %args = $page->get_all_encoded_arguments();

## Create the gem schema object (used to get data from expression to samples)

my $psqlv = `psql --version`;
chomp($psqlv);

my @schema_list = ('gem', 'biosource', 'metadata', 'public');
if ($psqlv =~ /8\.1/) {
    push @schema_list, 'tsearch2';
}

my $schema = CXGN::DB::DBICFactory->open_schema( 'CXGN::GEM::Schema', search_path => \@schema_list, );

## It will create a sgn_schema too

my $sgn_schema = CXGN::DB::DBICFactory->open_schema( 'SGN::Schema', search_path => ['sgn'], );

## Also it will create a dbi-connection object ($dbh) for all the methods that do not use schemas
## (as CXGN::Transcript::Unigene) to not interfiere with them

my $dbh = CXGN::DB::Connection->new();

## Also it will get the dir for temp files (for images)
## This will be replace in the new branch for the apache variable $c !!!!

my $vhost_conf = CXGN::VHost->new();
my $basepath = $vhost_conf->get_conf('basepath');
my $tmpdir = File::Spec->catdir($vhost_conf->get_conf('tempfiles_subdir'), 'unigene_images' );

## To do more flexible how the unigene can be called

if (defined $args{'unigene_id'}) {
    $args{'id'} = $args{'unigene_id'} ;
    $args{'id'} =~ s/^SGN-U//;    
}

## Random function will get at random unigene from the latest unigene build

if (defined $args{'random'}) {
    if ($args{'random'} =~ m/^yes$/i) {
	my $last_unigene_build_id = $sgn_schema->resultset('UnigeneBuild')
	                                       ->search(
	                                                 undef, 
	                                                 { 
							    order_by => 'unigene_build_id DESC', 
							    limit => 1 
							 }
					               )
					       ->first()
					       ->get_column('unigene_build_id');
	
        ## Now get all the unigene_id for this unigene_build_id

	my $random_unigene_id = $sgn_schema->resultset('Unigene')
	                                   ->search(
	                                              { 
							unigene_build_id => $last_unigene_build_id 
						      }, 
	                                              { 
							order_by => 'random()', 
							limit    => 1
						      }
					           )
					   ->first()
					   ->get_column('unigene_id');

	## It will replace $args{'id'}

	$args{'id'} = $random_unigene_id;
    }
}

## Now it will take the unigene object based in the unigene_id (it will create an empty object by default)

my $unigene = CXGN::Transcript::Unigene->new($dbh);

if (defined $args{'id'} && $args{'id'} =~ m/^\d+$/) {

    $unigene = CXGN::Transcript::Unigene->new($dbh, $args{'id'});
}


## Now depending if there are enought condition, it will call a mason unigen page ($unigene object has an id)
## or an error page

if (defined $unigene && defined $unigene->get_unigene_id() ) {

    $m->exec('/transcript/unigene_detail.mas', 
	     dbh         => $dbh,
	     schema      => $schema,
	     sgn_schema  => $sgn_schema,
	     unigene     => $unigene, 
	     highlight   => $args{'highlight'},
	     force_image => $args{'force_image'},
	     basepath    => $basepath,
	     temp_dir    => $tmpdir );
} else {
    $m->exec('/transcript/transcript_page_error.mas', 
	     object      => $unigene );
}
