#!/usr/bin/perl
use strict;
use warnings;

use SGN::Context;

my $c = SGN::Context->new();

#---connect to schema---
my $schema = $c->dbic_schema('Bio::Chado::Schema');

#---add pubmed publications to pubprop---
my $db = $schema->resultset('General::Db')->find({name => 'PMID'});

#---arrays of pubmed ids and titles of publications---
my @pmid = (
    18254380,
    18317508,
    17565940,
    16830097,
    16524981,
    16489216,
    16208505,
    16010005,
    10645957,
    10382301,
    10224272,
    18469880,
    8662247,
    8653264,
    8647403,
);
foreach my $item ( @pmid ) {
    my $dbxref = $db->find_related(
        'dbxrefs',
        {accession => $item}
       );
    my $pub = $dbxref->find_related('pub_dbxrefs', {})
                     ->find_related('pub', {})
                     ->create_pubprops(
                         {'tomato genome publication' => '1'},
                         { autocreate => 1 }
                        );
}

#---add other publications manually---
my @titles = (
    'A Snapshot of the Emerging Tomato Genome Sequence',
    'Estimation of nuclear DNA content of plants by flow cytometry',
   );

foreach my $title ( @titles ) {
    my $pub = $schema
        ->resultset( "Pub::Pub" )
        ->find({ title => $title })
        ->create_pubprops(
            {'tomato genome publication' => '1'},
            {autocreate => 1}
           );
}

