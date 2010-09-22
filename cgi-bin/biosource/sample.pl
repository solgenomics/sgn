#!/usr/bin/perl

=head1 NAME

  sample.pl
  Controller to show the web_page for sample information using MASON.

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

use CXGN::MasonFactory;
use CXGN::DB::DBICFactory;
use CXGN::DB::Connection;
use CXGN::Biosource::Schema;
use CXGN::Biosource::Sample;
use CXGN::GEM::Schema;
use CXGN::GEM::Target;
use CXGN::DB::Connection;

use CXGN::Page;
use CXGN::Page::FormattingHelpers  qw/ info_section_html info_table_html columnar_table_html page_title_html html_break_string /;


## Create the mason object

my $m = CXGN::MasonFactory->new();

## Use of CXGN::Page to take the arguments from the URL

my %args = CXGN::Page->new()
                     ->get_all_encoded_arguments();

## Create the schema used for the mason components

my $psqlv = `psql --version`;
chomp($psqlv);

my $schema_list = 'biosource,metadata,public';
if ($psqlv =~ /8\.1/) {
    $schema_list .= ',tsearch2';
}

my @schema_list = split(/,/, $schema_list);
my $schema = CXGN::DB::DBICFactory->open_schema( 'CXGN::Biosource::Schema', search_path => \@schema_list, );


## Get the sample data for sample specific mason components

my $sample;
if (exists $args{'id'} && $args{'id'} =~ m/^\d+$/) {
    $sample = CXGN::Biosource::Sample->new($schema, $args{'id'});
} elsif (exists $args{'name'}) {
    $sample = CXGN::Biosource::Sample->new_by_name($schema, $args{'name'});
} else {
    $sample = CXGN::Biosource::Sample->new($schema);
}

## Get a publication list for common mason components 

my @pubs = ();
if (defined $sample) {
   @pubs = $sample->get_publication_list();
}

## The sample can be associated expression data (search sample_id in gem.ge_target_element table)

my @targets = ();
if ($sample->get_sample_id() ) {

    ## First create an schema that contains gem schema
    my @gem_schema_list = ('gem', @schema_list);

    my $gemschema = CXGN::DB::DBICFactory->open_schema( 'CXGN::GEM::Schema', search_path => \@gem_schema_list, );
 
    my @sample_el_rows = $gemschema->resultset('GeTargetElement')
	                           ->search({ sample_id => $sample->get_sample_id() });

    foreach my $sample_el_row (@sample_el_rows) {
	my $target_id = $sample_el_row->get_column('target_id');
	my $target = CXGN::GEM::Target->new($gemschema, $target_id);
	push @targets, $target;
    }
}

## Get the sample relationship

my %sample_relations = $sample->get_relationship();

## Depending if the $sample has or not id, it call a mason page (error when does not exists sample in the database)

## There are two ways to access to the page, using id=int or name=something. If use other combinations give an error message 

if (defined $sample->get_sample_id() ) {
    $m->exec('/biosource/sample_detail.mas', schema => $schema, sample => $sample, sample_relations_href => \%sample_relations, pub_list => \@pubs, target_list => \@targets );
} else {
    $m->exec('/biosource/biosource_page_error.mas', schema => $schema, object => $sample );
}


