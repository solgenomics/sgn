
use Modern::Perl;

use CXGN::Phenome::Locus;
use CXGN::Phenome::LocusMarker;

use CXGN::DB::InsertDBH;
use Getopt::Std;

our(%opts);
getopts('H:D:p:tc:', \%opts);

if (!exists($opts{p})) { 
    die "need -p parameter (sp_person_id of locus owner)";
}

if (!exists($opts{c})) { 
    die "need -c parameter (common_name_id)";
}

my $file = shift;


my $dbh = CXGN::DB::InsertDBH->new({ dbname => $opts{D},
				   dbhost => $opts{H}});

open(my $F, "<", $file) || die "Can't open file $file\n";
my $count = 0;
while (<$F>) { 
    my ($qtl, $chr, $pos, $protocol, $confidence, $description, $pubmed_id) = split /\t/;
    
    
    if ($protocol =~ /QTL/i) { 
	my $l = CXGN::Phenome::Locus->new($dbh);
    
	print STDERR "Setting locus name and symbol ($qtl)...\n";
	$l->set_locus_name($qtl);
	$l->set_locus_symbol($qtl);
	$l->set_common_name_id($opts{c});
	print STDERR "Setting description...\n";
	$l->set_description($description);
	$l->set_sp_person_id($opts{p});

	print STDERR "Adding publication $pubmed_id...\n";
	my $sth = $dbh->prepare("SELECT dbxref_id FROM dbxref WHERE accession=?");
	$sth->execute($pubmed_id);
	my ($dbxref_id) = $sth->fetchrow_array();
	if ($dbxref_id) { 
	    print STDERR "Adding dbxref_id $dbxref_id...\n";
	    my $dbxref = CXGN::Chado::Dbxref->new($dbh, $dbxref_id);
	    $dbxref->set_sp_person_id($opts{p});
	    $dbxref->set_accession($pubmed_id);
	    $dbxref->set_db_name('PMID');
	    $l->add_locus_dbxref($dbxref) if $dbxref;
	}
	
	
	if (!$opts{t}) { 
	    print STDERR "Storing...\n";
	    my $locus_id = $l->store();
	    
	    $l->add_owner($opts{p});
	    
	    my $sth = $dbh -> prepare("SELECT marker_id FROM sgn.marker_alias WHERE alias =?"); 
	    $sth->execute($qtl);
	    
	    my ($marker_id) = $sth->fetchrow_array();
	
	    if (!$marker_id) { die "Couldn't find a marker for $qtl!"; }
	    print STDERR "Found marker $marker_id. Associating it...\n";
	    
	    my $lm = CXGN::Phenome::LocusMarker->new($dbh);
	    $lm->set_marker_id($marker_id);
	    $lm->set_locus_id($locus_id);


	    $lm->store();
	    
	    $l->add_locus_marker($lm);
	    
	    
	} 

	else { 
	    print STDERR "NOT storing (-t in effect!)\n";
	}
	$count++;
    }
    
    
    
	###$l->associate_publication($pubmed, $opts{p});
	

}

if (!$opts{t}) { 
    print STDERR "Committing!!!!!\n";
    $dbh->commit;
}

print STDERR "Done. Processed $count qtls\n";
