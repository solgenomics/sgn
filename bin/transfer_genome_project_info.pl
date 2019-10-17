


####   {"genome_project_funding_agencies":"TraitGenetics Inc.","genome_project_contact_person":"Martin Ganal, ganal@traitgenetics.de","genome_project_sequencing_center":"TraitGenetics","genome_project_dates":"2012","genome_project_genbank_link":"","genome_project_url":"traitgenetics.com","genome_project_sequenced_accessions":"Ailsa Craig"}

use strict;

use Getopt::Std;
use Data::Dumper;
use Pod::Usage;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use JSON::Any;

our ($opt_H, $opt_D, $opt_i);

getopts('H:D:i:');

if (!$opt_H || !$opt_D ) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file) \n");
}

my $dbhost = $opt_H;
my $dbname = $opt_D;

my $dbh = CXGN::DB::InsertDBH->new({ 
        dbhost=>$dbhost,
        dbname=>$dbname,
        dbargs => {AutoCommit => 1, RaiseError => 1}
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() });

my $q = "SELECT organismprop_id, organism_id, type_id, value from organismprop where type_id=(SELECT cvterm_id FROM cvterm where name='organism_sequencing_metadata')";

my $h = $dbh->prepare($q);
$h->execute();
					  
while (my ($organismprop_id, $organism_id, $type_id, $value)= $h->fetchrow_array()) {
    my $data = JSON::Any->decode($value);
					      
    my $row = $schema->resultset("Stock::Stock")->find( { organism_id => $organism_id, uniquename => $data->{genome_project_sequenced_accessions} });

    if ($row) {
	print STDERR "accession $data->{genome_project_sequenced_accessions} FOUND in database!!!!\n";
	my $si = CXGN::Stock::SequencingInfo->new( { schema => $schema });
	
	$si->funded_by($data->{genome_project_funding_agencies});
	$si->contact_email($data->{genome_project_contact_person});
	$si->organization($data->{genome_project_sequencing_center});
	$si->sequencing_year($data->{genome_project_dates});
	$si->genbank_accession($data->{genome_project_genbank_link});
	$si->website($data->{genome_project_url});
	$si->stock_id($row->stock_id());
	$si->store();

    }
    else {
	print sTDERR "accession $data->{genome_project_sequenced_accessions} ***NOT*** FOUND in database!!!!\n";

    }
}
