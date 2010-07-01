#!/usr/bin/perl

use strict;
use warnings;

use Bio::Chado::Schema;
use SGN::Context;

#---declaring variables---
my $item;
my $title;
my $c = SGN::Context->new();

#---arrays of pubmed ids and titles of publications---
my @pmid = (18254380, 18317508, 17565940, 16830097, 16524981, 16489216, 16208505, 16010005, 10645957, 10382301, 10224272, 18469880, 8662247, 8653264, 8647403);

my @titles = ('A Snapshot of the Emerging Tomato Genome Sequence', 'Estimation of nuclear DNA content of plants by flow cytometry');


#---connect to schema---
my $dbdsn = 'dbi:Pg:host=' . $c->get_conf('dbhost') . 
            ':dbname=' . $c->get_conf('dbname');

my $schema = Bio::Chado::Schema->connect($dbdsn, $c->get_conf('dbuser'), $c->get_conf('dbpass'), { AutoCommit => 1, RaiseError => 1 });


#---add pubmed publications to pubprop---
my ($db) = $schema->resultset('General::Db')->find({name => 'PMID'});

foreach $item(@pmid){
my ($dbxref) = $db->find_related('dbxrefs', {accession => $item});
my $pub = $dbxref->find_related('pub_dbxrefs', {})->find_related('pub', {});
$pub->create_pubprops({'tomato genome publication' => '1'}, {autocreate => 1});
}

#---add other publications manually---
foreach $title(@titles){
my $pub = $schema->resultset("Pub::Pub")->find({title => $title});
$pub->create_pubprops({'tomato genome publication' => '1'}, {autocreate => 1});
}

1;
