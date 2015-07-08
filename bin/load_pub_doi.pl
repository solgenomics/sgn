#!/usr/bin/perl

use Getopt::Std;
use CXGN::DB::InsertDBH;
use Bio::Chado::Schema;
use Data::Dumper;
use CXGN::Chado::Publication;
use CXGN::Tools::Pubmed;
use strict;
use warnings;

use vars qw | $opt_H $opt_D |;

getopts('H:D:');

my $dbh = CXGN::DB::InsertDBH->new( {
    dbhost => $opt_H,
    dbname => $opt_D,
    } );



my $schema = Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() }, { on_connect_do => ['SET search_path TO public;'] , autocommit => 1 } );

print STDERR "finding dbxrefs for all publications\n"; 
my $dbxref_rs = $schema->resultset("General::Dbxref")->search( 
    {
	'db.name' => 'PMID',
    }, 
    {
	join       => [ 'db', 'pub_dbxrefs' ] ,
	"+select"  => [ "pub_dbxrefs.pub_id" ],
	"+as"      => [ "pub_id" ],
    }
    );
my $pub_count;
my $doi_count;
while (my $dbxref = $dbxref_rs->next ) {
    $pub_count++;
    my $accession = $dbxref->accession;
    my $pub_id = $dbxref->get_column("pub_id");
    if (!$pub_id) { 
	warn "No pub_id exists for accession $accession! Skipping ! \n\n";
	next;
    }
    my $pub = CXGN::Chado::Publication->new( $dbh, $pub_id );
    $pub->set_accession($accession);
    my $pubmed = CXGN::Tools::Pubmed->new($pub);
    
    my $eid = $pub->get_eid;
    my $title = $pub->get_title;
    if ( $eid ) {
	$doi_count++;
	print STDERR "Found DOI $eid\n";
	my $db = $schema->resultset("General::Db")->find_or_create( 
	    {
		name       => 'DOI',
		urlprefix =>  'http://',
		url        => 'doi.org',
	    } );

	my $e_dbxref = $db->find_or_create_related("dbxrefs" , { accession => $eid } );
	$e_dbxref->find_or_create_related("pub_dbxrefs", { pub_id => $pub_id } ) ;
	
	print STDERR "Loaded DOI $eid for publication $pub_id (accession $accession) dbxref id = " . $e_dbxref->get_column('dbxref_id') . " **\n";
    } else {
	print STDERR "no DOI for pub_id $pub_id , pubmed accession = $accession\n"; 
    }
}
$schema->txn_commit;
print STDERR "\nDONE. Found $pub_count publications, $doi_count DOIs \n\n";
