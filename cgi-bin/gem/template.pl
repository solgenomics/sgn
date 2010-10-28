#!/usr/bin/perl

=head1 NAME

  template.pl
  Controller to show the web_page for template using MASON.

=cut

=head1 SYNOPSIS

 
=head1 DESCRIPTION

  This is the script controller to show the template web_page using MASON

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
use CXGN::GEM::Template;
use CXGN::GEM::Expression;

## Create the mason object

my $m = CXGN::MasonFactory->new();


## Create the schema object

my $psqlv = `psql --version`;
chomp($psqlv);

my @schema_list = ('gem', 'biosource', 'metadata', 'public');
if ($psqlv =~ /8\.1/) {
    push @schema_list, 'tsearch2';
}

my $schema = CXGN::DB::DBICFactory->open_schema( 'CXGN::GEM::Schema', search_path => \@schema_list, );

## Another schema to create is a schema that use sgn as schema

my $sgn_schema = CXGN::DB::DBICFactory->open_schema( 'SGN::Schema', search_path => ['sgn'], );


## Also it will create a dbi-connection object ($dbh) for all the methods that do not use schemas
## (as CXGN::People::Person) to not interfiere with them

my $dbh = CXGN::DB::Connection->new();


## Use of CXGN::Page to take the arguments from the URL


my $page = CXGN::Page->new();

my %args = $page->get_all_encoded_arguments();


## Get template object (by default it will create an empty template object)

my $template = CXGN::GEM::Template->new($schema);

if (exists $args{'id'}) {
   $template = CXGN::GEM::Template->new($schema, $args{'id'});
} elsif (exists $args{'name'}) {
   $template = CXGN::GEM::Template->new_by_name($schema, $args{'name'});
}
 
## Get the unigene list associated with this template to use with the annotations

my @unigene_ids = ();
if (defined $template->get_template_id) {
    @unigene_ids = $template->get_internal_accessions('unigene');
}

## Add expression object

my $expression = CXGN::GEM::Expression->new($schema);

if (defined $template->get_template_id()) {
    $expression = CXGN::GEM::Expression->new($schema, $template->get_template_id());
}



## There are two ways to access to the page, using id=int or name=something. If use other combinations give an error message 

if (defined $template->get_template_id() or defined $template->get_template_name() ) {
    $m->exec( '/gem/template_detail.mas',
              dbh          => $dbh,
              schema       => $schema,
	      sgn_schema   => $sgn_schema,
              template     => $template,
	      expression   => $expression,
	      unigene_list => \@unigene_ids
            );
} else {
    $m->exec('/gem/gem_page_error.mas', 
             schema => $schema, 
             object => $template );
}
