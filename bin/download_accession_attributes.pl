
=head1 NAME

download_accession_attributes.pl - script to download accession attributes
=head1 DESCRIPTION

perl download_accession_attributes.pl -i trial_id -H host -D dbname -U dbuser -P dbpass

Downloads trials whose ids are provided as a comma separated list for the -i parameter.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>, March 2022.

=cut

use strict;

use Getopt::Std;
use Data::Dumper;

use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use CXGN::People::Schema;
use CXGN::DB::InsertDBH;
use CXGN::Stock;
use Config::Any;


our ($opt_H, $opt_D, $opt_U, $opt_P, $opt_b, $opt_i, $opt_n, $opt_t, $opt_r, $opt_c);

getopts('H:D:U:P:b:i:t:r:c:n');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $dbuser = $opt_U;
my $dbpass = $opt_P;
my $accession_file = $opt_i;
my $non_interactive = $opt_n;
my $sgn_local_conf_file = $opt_c || "sgn_local.conf";

print STDERR "Using config from $sgn_local_conf_file\n";

my @editable_stock_props = ("population_name", "organization_name", "synonym", "PUI", "accession number", "acquisition date", "biological status of accession code", "country of origin", "donor", "donor PUI", "donor institute", "genome_structure", "institute code", "institute name", "introgression_backcross_parent", "introgression_chromosome", "introgression_end_position_bp", "introgression_map_version", "introgression_parent", "introgression_start_position_bp", "location_code",  "ncbi_taxonomy_id", "notes","organization", "ploidy_level", "released_variety_name", "seed source", "state", "transgenic", "type of germplasm storage code", "variety" );

my $editable_stock_props_read_from_conf_file = 0;
if (-e $sgn_local_conf_file) { 
    my $config = Config::Any->load_files( { files => [ $sgn_local_conf_file ] , use_ext => 1} );

    print STDERR Dumper($config);
    @editable_stock_props = split /\,/, $config->[0]->{$sgn_local_conf_file}->{editable_stock_props};
    $editable_stock_props_read_from_conf_file = 1;
}

print STDERR "EDITABLE STOCK PROPS = ".Dumper(\@editable_stock_props);
print STDERR "(READ FROM FILE: $editable_stock_props_read_from_conf_file)\n";

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 0,
						 RaiseError => 1},
				     
				    },

				    
				    
    );

print STDERR "Connecting to database...\n";
my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() },{  on_connect_do => ['set search_path=public,sgn,phenome'] } );
my $people_schema = CXGN::People::Schema->connect( sub { $dbh->get_actual_dbh() } );
#my $metadata_schema = CXGN::Metadata::Schema->connect( sub { $dbh->get_actual_dbh() });
#my $pheome_schema = CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh() });

my @accessions;

my $cv_id = $schema->resultset('Cv::Cv')->find({ name => 'stock_property' })->cv_id();

my %db_stock_props;
my $db_stock_props_rs = $schema->resultset('Cv::Cvterm')->search( { 'cv_id' => $cv_id });
while (my $prop_cvterms = $db_stock_props_rs->next()) {
    $db_stock_props{$prop_cvterms->cvterm_id()} = $prop_cvterms->name();
}


open(my $F, "<", $accession_file) || die "Can't open $accession_file";
while (<$F>) {
    chomp;
    push @accessions, $_;
}

close($F);

print STDOUT join("\t", ('accession_name', 'species_name', @editable_stock_props))."\n";

foreach my $name (@accessions) { 
    my $accession_rs = $schema->resultset("Stock::Stock")->search( { uniquename => $name } );

    foreach my $row ($accession_rs->next()) {

	my $organism = $schema->resultset("Organism::Organism")->find( { organism_id => $row->organism_id } )->species();
	
	my $stockprop_rs = $schema->resultset("Stock::Stockprop")->search( { stock_id => $row->stock_id() });

	my @stockprops;
	while (my $sp_row = $stockprop_rs->next()) { 
	    push @stockprops, [ $row->stock_id(), $sp_row->type_id(), $db_stock_props{$sp_row->type_id()}, $sp_row->value() ];
	}
	    
	my %stockprops;
	print STDERR "STOCKPROP DATA = ".Dumper(\@stockprops);
	foreach my $sp (@stockprops) {
	    print STDERR "PROP NAME = $sp->[2], VALUE $sp->[3]\n";
	    $stockprops{$sp->[2]} = $sp->[3];
	    
	}

	# output the accession_name, species_name and the props in the right order
	#
	print STDOUT join("\t", ($row->uniquename(), $organism));
	
	
	my @accession_stock_props = ();
	foreach my $p (@editable_stock_props) {
	    print STDERR "STOCKPROP: $stockprops{$p}\n";
	    push @accession_stock_props, $stockprops{$p};
	}
	print STDOUT "\t".join("\t", @accession_stock_props)."\n";
	
	
    }
    
    
    
}



