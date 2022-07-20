

# seedlot_name 	accession_name 	operator_name 	amount 	weight(g) 	description 	box_name 	quality 	source


use strict;

use Getopt::Long;
use CXGN::Stock::Seedlot;
use CXGN::Stock::Seedlot::Transaction;

my ( $dbhost, $dbname, $file, $username, $test );

GetOptions(
    'i=s'        => \$file,
    'u=s'        => \$username,
    't'          => \$test,
    'dbname|D=s' => \$dbname,
    'dbhost|H=s' => \$dbhost,
);


my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 1,
						 RaiseError => 1}
				    }
    );
my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } ,  { on_connect_do => ['SET search_path TO  public;'] }
					  );
my $phenome_schema= CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh } , { on_connect_do => ['set search_path to public,phenome;'] }  );


open(my $F, "<", $file) || die "Can't open $file\n";

while (<$F>) {
    chomp;
    
    my ($seedlot_name, $accession_name, $operator_name, $amount, $weight, $description, $box_name, $quality, $source) = split /\t/;

    my $seedlot = CXGN::Stock::Seedlot->new( { schema => $schema });

    $seedlot->uniquename($seedlot_name);
    $seedlot->accessions( [$accession_name ]);
    $seedlot->box_name($seedlot_name);
    $seedlot->description($description);
    $seedlot->operator($operator_name);
    $seedlot->store();

    
#    my $slt = CXGN::Stock::Seedlot::Transaction->new( { schema => $schema });
#    $slt->from_stock($accession_name);
#    $slt->to_stock($accession_name);
#    $slt->amount($amount);
#    $slt->weight($weight);

#    $slt->store();

#    $seedlot->_add_transaction($slt);

#    $seedlot->store();
}

print STDERR "Done!\n";
    
  
	    
    
    



