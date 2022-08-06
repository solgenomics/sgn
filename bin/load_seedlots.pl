

# seedlot_name 	accession_name 	operator_name 	amount 	weight(g) 	description 	box_name 	quality 	source


use strict;

use CXGN::DB::InsertDBH;
use SGN::Model::Cvterm;
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

my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
print STDERR "SEEDLOT CVTERM ID = $seedlot_cvterm_id\n";

open(my $F, "<", $file) || die "Can't open $file\n";

while (<$F>) {
    chomp;
    
    my ($seedlot_name, $accession_name, $operator_name, $amount, $weight, $description, $box_name, $quality, $source) = split /\t/;


    my $accession_row = $schema->resultset('Stock::Stock')->find( { uniquename => $accession_name } );

    if (!$accession_row) {
	print STDERR "accession $accession_name not found. SKIPPING!\n";
	next();
    }

    my $seedlot_row = $schema->resultset('Stock::Stock')->find( { uniquename => $seedlot_name });
    my $seedlot;
    if ($seedlot_row) {
	print STDERR "Seedlot $seedlot_name already exists...\n";
	if ($seedlot_row->type_id() != $seedlot_cvterm_id) {
	    print STDERR "Seedlot $seedlot_name exists in the database, but has wrong type_id (".$seedlot_row->type_id().")\n";
	    next();
	}

	$seedlot = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_row->stock_id() );
    }

    else {
	$seedlot = CXGN::Stock::Seedlot->new(schema => $schema );
    }	
    my $seedlot = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_row->stock_id() );

    my $accession_id = $accession_row->stock_id();
    $seedlot->uniquename($seedlot_name);
    $seedlot->accession_stock_id($accession_id);
    $seedlot->box_name($seedlot_name);
    $seedlot->description($description);
    $seedlot->location_code("Westchester");
    $seedlot->breeding_program_id(325);
    #$seedlot->operator($operator_name);
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
    
  
	    
    
    



