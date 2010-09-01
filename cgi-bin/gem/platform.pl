#!/usr/bin/perl

=head1 NAME

  platform.pl
  Controller to show the web_page for platform using MASON.

=cut
 
=head1 DESCRIPTION

  This is the controller script to show the web_page using MASON

=cut

=head1 AUTHORS

 Aureliano Bombarely Gomez
 (ab782@cornell.edu)

=cut


use strict;
use warnings;

use CXGN::MasonFactory;
use CXGN::Page;

use CXGN::DB::Connection;
use CXGN::DB::DBICFactory;
use CXGN::GEM::Schema;
use CXGN::GEM::Platform;
use CXGN::GEM::Target;


## Create mason object

my $m = CXGN::MasonFactory->new();


## Create the schema object

my $dbh = CXGN::DB::Connection->new();
my $schema_list = 'gem,biosource,metadata,public';
my $schema = CXGN::GEM::Schema->connect( sub { $dbh->get_actual_dbh },
            { on_connect_do => ["SET search_path TO $schema_list"] }, );

## Also it will create a dbi-connection object ($dbh) for all the methods that do not use schemas
## (as CXGN::People::Person) to not interfere with them


## Use of CXGN::Page to take the arguments from the URL

my %args = CXGN::Page->new()->get_all_encoded_arguments();

## Now it will create a platform object (by default it will create an empty platform object)

my $platform;

if (exists $args{'id'} && $args{'id'} =~ m/^\d+$/) {
   $platform = CXGN::GEM::Platform->new($dbh, $args{'id'});
} elsif (exists $args{'name'}) {
   $platform = CXGN::GEM::Platform->new_by_name($schema, $args{'name'});
} else {
    $platform = CXGN::GEM::Platform->new($dbh);
}

## Other data that the controller will suply will be: 

#### 1) @target_list with CXGN::GEM::Target objects for hybridizations 

my @target_list = ();

if (defined $platform->get_platform_id() ) {
    my @hyb_rows = $schema->resultset('GeHybridization')
	->search({ platform_id => $platform->get_platform_id() });
    
    foreach my $hyb_row (@hyb_rows) {
        my $target_id = $hyb_row->get_column('target_id');
        my $target = CXGN::GEM::Target->new($dbh, $target_id);
        push @target_list, $target;
    }
}

#### 2) @template_list with template_rows for templates (use CXGN::GEM::Template is slow because template object get other data)

my @template_row_list = ();

if (defined $platform->get_platform_id() ) {

    @template_row_list = $schema->resultset('GeTemplate')
	                        ->search( { platform_id => $platform->get_platform_id() } );
}

#### 3) @pub_id_list, a list of pub ids to show the publications associated with this platform

my @pub_id_list = ();

if (defined $platform->get_platform_id() ) {

    @pub_id_list = $platform->get_publication_list();
}


## There are two ways to access to the page, using id=int or name=something. If use other combinations give an error message 

if (defined $platform->get_platform_id or defined $platform->get_platform_name) {
    $m->exec('/gem/platform_detail.mas',
            dbh           => $dbh,
            schema        => $schema, 
            platform      => $platform,	     
            target_list   => \@target_list,
            template_list => \@template_row_list, 
            pub_list      => \@pub_id_list    
    );
} else {
    $m->exec('/gem/gem_page_error.mas', 
             schema => $schema, 
             object => $platform );
}
