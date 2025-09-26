
=head1 NAME

SGN::Test::Fixture - use the fixture in unit tests

=head1 SYNOPSIS

my $f = SGN::Test::Fixture;

my $dbh = $f->dbh(); # accesses the fixture db

my $bcs_schema = $f->bcs_schema(); # access DBIx::Class BCS schema

my $phenome_schema = $f->phenome_schema(); # access DBIx::Class phenome schema

my $sgn_schema = $f->sgn_schema(); # access DBIx::Class SGN schema

# run tests...

my $sample_class = CXGN::SampleClass->new( { dbh => $dbh });

is ($sample_class->foo(), 42, "foo test");

# etc...

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut


package SGN::Test::Fixture;

use Moose;
use DBI;
use DBIx::Class;
use Config::Any;
use Data::Dumper;
use File::Slurp qw | read_file |;
use Bio::Chado::Schema;
use CXGN::Phenome::Schema;
use CXGN::Metadata::Schema;
use CXGN::People::Schema;
use SGN::Schema;
use Catalyst::Authentication::User;
use CXGN::People::Person;

use warnings;

sub BUILD { 
    my $self = shift;

    if (! -f 'sgn_fixture.conf') { 
	print "ERROR! sgn_fixture.conf does not exist. Abort. Are you running test_fixture.pl ?\n";
	exit();
    }

    my $all_config = Config::Any->load_files({
	files=> ['sgn_fixture.conf'], use_ext=>1
					     });

    my $config = $all_config->[0]->{'sgn_fixture.conf'};

    $self->config($config);

    my $dsn = 'dbi:Pg:database='.$self->config->{dbname}.";host=".$self->config->{dbhost}.";port=5432";

    $self->dbh(DBI->connect($dsn, $self->config->{dbuser}, $self->config->{dbpass}, { on_connect_do => ['SET search_path TO phenome, public, sgn, metadata' ]} ));

    $self->bcs_schema(Bio::Chado::Schema->connect($dsn, $self->config->{dbuser}, $self->config->{dbpass}));

    $self->phenome_schema(CXGN::Phenome::Schema->connect($dsn, $self->config->{dbuser}, $self->config->{dbpass}, { on_connect_do => [ 'SET search_path TO phenome, public, sgn, metadata' ] } ));

    $self->sgn_schema(SGN::Schema->connect($dsn, $self->config->{dbuser}, $self->config->{dbpass}, { on_connect_do => [ 'SET search_path TO metadata, public, sgn' ] }));

    $self->metadata_schema(CXGN::Metadata::Schema->connect($dsn, $self->config->{dbuser}, $self->{config}->{dbpass}, { on_connect_do => [ 'SET search_path TO metadata, public, sgn' ] }));

    $self->people_schema(CXGN::People::Schema->connect($dsn, $self->config->{dbuser}, $self->{config}->{dbpass}, { on_connect_do => [ 'SET search_path TO sgn_people, public, sgn' ]}));

    #Janedoe in fixture db
    my $catalyst_user = Catalyst::Authentication::User->new();
    my $sgn_user = CXGN::People::Person->new($self->dbh, 41);
    $catalyst_user->set_object($sgn_user);
    $self->user($catalyst_user);
    $self->sp_person_id(41);
    $self->username('janedoe');

    $self->dbstats_start($self->get_db_stats());

    $self->auditstats_start($self->get_auditdb_stats());

}

has 'config' => ( isa => "Ref",
		  is => 'rw',
    );

has 'dbh' => (
		is => 'rw',
    );

has 'bcs_schema' => (isa => 'Bio::Chado::Schema',
		     is => 'rw',
    );

has 'phenome_schema' => (isa => 'CXGN::Phenome::Schema', 
			 is => 'rw',
    );

has 'sgn_schema' => (isa => 'SGN::Schema',
		     is => 'rw',
    );

has 'people_schema' => (isa => 'CXGN::People::Schema',
			is => 'rw',
    );

has 'metadata_schema' => (isa => 'CXGN::Metadata::Schema', 
			  is => 'rw',
    );

has 'user' => ( isa => 'Object',
    is => 'rw',
);

has 'sp_person_id' => ( isa => 'Int',
    is => 'rw',
);

has 'username' => ( isa => 'Str',
    is => 'rw',
);

has 'dbstats_start' => (isa => 'HashRef', is => 'rw' );

has 'dbstats_end' => (isa => 'HashRef', is => 'rw');

has 'auditstats_start' => (isa => 'HashRef', is => 'rw' );

has 'auditstats_end' => (isa => 'HashRef', is => 'rw');

sub dbic_schema {
    my $self = shift;
    my $name = shift;

    if ($name eq 'Bio::Chado::Schema') {
        return $self->bcs_schema();
    }
    if ($name eq 'CXGN::Phenome::Schema') {
        return $self->phenome_schema();
    }
    if ($name eq 'SGN::Schema') {
        return $self->sgn_schema();
    }
    if ($name eq 'CXGN::Metadata::Schema') {
        return $self->metadata_schema();
    }
    if ($name eq 'CXGN::People::Schema') { 
	return $self->people_schema();
    }

    return;
}

sub get_conf {
    my $self = shift;
    my $name = shift;

    return $self->config->{$name};
}

sub get_db_stats {
    my $self = shift;

    my $stats = {};

    print STDERR "Gathering DB stats...\n";
    
    # count number of stocks
    #
    my $rs = $self->bcs_schema()->resultset('Stock::Stock')->search( {}, { columns => [ { 'stock_id_max' => { max => 'stock_id' }} ] } );
    $stats->{stocks} = $rs->get_column('stock_id_max')->first();

    $rs = $self->phenome_schema()->resultset('StockOwner')->search( {}, { columns => [ { 'stock_owner_id_max' => { max => 'stock_owner_id' }} ] });
    $stats->{stock_owners} = $rs->get_column('stock_owner_id_max')->first();

    $rs = $self->bcs_schema()->resultset('Stock::StockRelationship')->search( {}, { columns => [ { 'stock_relationship_id_max' => { max => 'stock_relationship_id' }} ] } );
    $stats->{stock_relationships} = $rs->get_column('stock_relationship_id_max')->first();

    $rs = $self->bcs_schema()->resultset('Stock::Stockprop')->search( {}, { columns => [ { 'stockprop_id_max' => { max => 'stockprop_id' }} ] } );
    $stats->{stockprops} = $rs->get_column('stockprop_id_max')->first();

    # count cvterms
    #
    $rs = $self->bcs_schema()->resultset('Cv::Cvterm')->search( {}, { columns => [ { 'cvterm_id_max' => { max => 'cvterm_id' }} ] } );
    $stats->{cvterms} = $rs->get_column('cvterm_id_max')->first();

    # count cvtermprops
    #
    $rs = $self->bcs_schema()->resultset('Cv::Cvtermprop')->search( {}, { columns => [ { 'cvtermprop_id_max' => { max => 'cvtermprop_id' }} ] } );
    $stats->{cvtermprops} = $rs->get_column('cvtermprop_id_max')->first();
    
    # count users
    #
    $rs = $self->people_schema()->resultset('SpPerson')->search( {}, { columns => [ { 'sp_person_id_max' => { max => 'sp_person_id' }} ] } );
    $stats->{people} = $rs->get_column('sp_person_id_max')->first();

    $rs = $self->people_schema()->resultset('SpDataset')->search( {}, { columns => [ { 'sp_dataset_id_max' => { max => 'sp_dataset_id' }} ] } );
    $stats->{datasets} = defined $rs->get_column('sp_dataset_id_max')->first() ? $rs->get_column('sp_dataset_id_max')->first() : 0;

    $rs = $self->people_schema()->resultset('List')->search( {}, { columns => [ { 'list_id_max' => { max => 'list_id' }} ] } );
    $stats->{lists} = $rs->get_column('list_id_max')->first();

    $rs = $self->people_schema()->resultset('ListItem')->search( {}, { columns => [ { 'list_item_id_max' => { max => 'list_item_id' }} ] } );
    $stats->{list_elements} = $rs->get_column('list_item_id_max')->first();

    # count projects
    #
    $rs = $self->bcs_schema()->resultset('Project::Project')->search( {}, { columns => [ { 'project_id_max' => { max => 'project_id' }} ] } );
    $stats->{projects} = $rs->get_column('project_id_max')->first();

    $rs = $self->bcs_schema()->resultset('Project::ProjectRelationship')->search( {}, { columns => [ { 'project_relationship_id_max' => { max => 'project_relationship_id' }} ] } );
    $stats->{project_relationships} = $rs->get_column('project_relationship_id_max')->first();

    $rs = $self->bcs_schema()->resultset('Project::Projectprop')->search( {}, { columns => [ { 'projectprop_id_max' => { max => 'projectprop_id' } } ] } );
    $stats->{projectprops} = $rs->get_column('projectprop_id_max')->first();

    # count phenotypes
    #
    $rs = $self->bcs_schema()->resultset('Phenotype::Phenotype')->search( {}, { columns => [ { 'phenotype_id_max' => { max => 'phenotype_id' }} ] } );
    $stats->{phenotypes} = $rs->get_column('phenotype_id_max')->first();

    # count genotypes
    #
    $rs = $self->bcs_schema()->resultset('Genetic::Genotypeprop')->search( {}, { columns => [ { 'genotypeprop_id_max' => { max => 'genotypeprop_id' }} ] } );
    $stats->{genotypes} = $rs->get_column('genotypeprop_id_max')->first();

    # count locations
    $rs = $self->bcs_schema()->resultset('NaturalDiversity::NdGeolocation')->search( {}, { columns => [ { 'nd_geolocation_id_max' => { max => 'nd_geolocation_id' }} ] } );
    $stats->{locations} = $rs->get_column('nd_geolocation_id_max')->first();

    # count nd_protocols
    $rs = $self->bcs_schema()->resultset('NaturalDiversity::NdProtocol')->search( {}, { columns => [ { 'nd_protocol_id_max' => { max => 'nd_protocol_id' }} ] } );
    $stats->{protocols} = $rs->get_column('nd_protocol_id_max')->first();

    # count nd_experiments
    $rs = $self->bcs_schema()->resultset('NaturalDiversity::NdExperiment')->search( {}, { columns => [ { 'nd_experiment_id_max' => { max => 'nd_experiment_id' }} ] } );    
    $stats->{experiments} = $rs->get_column('nd_experiment_id_max')->first();

    $rs = $self->phenome_schema()->resultset('NdExperimentMdFiles')->search( {}, { columns => [ { 'nd_experiment_md_files_id_max' => { max => 'nd_experiment_md_files_id' }} ] });
    $stats->{experiment_files} = $rs->get_column('nd_experiment_md_files_id_max')->first();

    $rs = $self->phenome_schema()->resultset('NdExperimentMdJson')->search( {}, { columns => [ { 'nd_experiment_md_json_id_max' => { max => 'nd_experiment_md_json_id' }} ] });
    $stats->{experiment_json} = defined $rs->get_column('nd_experiment_md_json_id_max')->first() ? $rs->get_column('nd_experiment_md_json_id_max')->first() : 0;

    # count project_owners
    $rs = $self->phenome_schema()->resultset('ProjectOwner')->search( {}, { columns => [ { 'project_owner_id_max' => { max => 'project_owner_id' }} ] });
    $stats->{project_owners} = defined $rs->get_column('project_owner_id_max')->first() ? $rs->get_column('project_owner_id_max')->first() : 0;

    # count project_md_images
    $rs = $self->phenome_schema()->resultset('ProjectMdImage')->search( {}, { columns => [ { 'project_md_image_id_max' => { max => 'project_md_image_id' }} ] });
    $stats->{project_images} = defined $rs->get_column('project_md_image_id_max')->first() ? $rs->get_column('project_md_image_id_max')->first() : 0;

    # count images
    $rs = $self->metadata_schema()->resultset('MdImage')->search( {}, { columns => [ { image_id_max => { max => 'image_id' }} ] });
    $stats->{images} = defined $rs->get_column('image_id_max')->first() ? $rs->get_column('image_id_max')->first() :0;

    # count dbxrefs
    $rs = $self->bcs_schema()->resultset('General::Dbxref')->search( {}, { columns => [ { 'dbxref_id_max' => { max => 'dbxref_id' }} ] } );
    $stats->{dbxrefs} = $rs->get_column('dbxref_id_max')->first();

    print STDERR "IMAGE STATS : $stats->{images}\n";
    
    # count metadata file entries
    $rs = $self->metadata_schema()->resultset('MdFiles')->search( {}, { columns => [ { 'file_id_max' => { max => 'file_id' }} ] } );
    $stats->{metadata_files} = $rs->get_column('file_id_max')->first();

    # count metadata entries
    $rs = $self->metadata_schema()->resultset('MdMetadata')->search( {}, { columns => [ { 'metadata_id_max' => { max => 'metadata_id' }} ] } );
    $stats->{metadata} = $rs->get_column('metadata_id_max')->first();

    print STDERR "STATS : ".Dumper($stats);

    print STDERR "DONE WITH get_db_stats.\n";
    return $stats;
}

sub get_auditdb_stats {

    my $self = shift;
    my $query = "select relname, n_tup_ins from pg_stat_all_tables WHERE schemaname = 'audit' ORDER BY n_tup_ins;";
    my $h = $self->dbh()->prepare($query);
    $h->execute();

    my $auditresults = {};

    # return only audit tables that are not empty (that have non-zero values)
    while (my ($audittable, $ntupins) = $h->fetchrow_array()) {
	if ($ntupins > 0) {
	    $auditresults->{$audittable} = $ntupins;
	}
    }

    return $auditresults;
}

=head1 FUNCTIONS

=head2 function clean_up_db()

  Usage:   $f->clean_up_db();
  Effects: removes any rows that were added to the database since the 
           currently running test started. Should be called at the end of the test
  Note:    Will not revert deletions or updates occuring during the test

=cut

# for tests that cannot use a transaction, such as unit_mech or selenium tests, this function can be used to bring
# the database back to approx the state before the test. dbstats_start needs to contain the result of the dbstats function
# beginning of the test.

sub clean_up_db {
    my $self = shift;

    my $stats = $self->get_db_stats();

    if (! defined($self->dbstats_start())) { print STDERR "Can't clean up because dbstats were not run at the beginning of the test!\n"; }

    my @deletion_order = ('stock_owners', 'stock_relationships', 'stockprops', 'stocks', 'project_owners', 'project_relationships', 'projectprops', 'project_images', 'projects', 'cvterms', 'cvtermprops', 'datasets', 'list_elements', 'lists', 'phenotypes', 'genotypes', 'locations', 'protocols', 'metadata_files', 'metadata', 'experiment_files', 'experiment_json', 'experiments', 'images', 'dbxrefs');

    foreach my $table (@deletion_order) {
	    print STDERR "CLEANING $table...\n";
	    my $count = $stats->{$table} - $self->dbstats_start()->{$table};
 	    if ($count > 0) {
	        print STDERR "Deleting...\n";
	        $self->delete_table_entries($table, $self->dbstats_start()->{$table}, $stats->{$table});
 	    }
    }
}

sub delete_table_entries {
    my $self = shift;
    my $table = shift;
    my $previous_max_id = shift;
    my $current_max_id = shift;

    print STDERR "DELETING TABLE $table (".($current_max_id - $previous_max_id)." entries)\n";

    my $rs;

    if ($table eq "stock_owners") {
	$rs = $self->phenome_schema()->resultset('StockOwner')->search( { stock_owner_id => { '>' => $previous_max_id }});
    }

    if ($table eq "stockprops") {
	$rs = $self->bcs_schema()->resultset('Stock::Stockprop')->search( { stockprop_id => { '>' => $previous_max_id }});
    }												 

    if ($table eq "stocks") { 
	$rs = $self->bcs_schema()->resultset('Stock::Stock')->search( { stock_id => { '>' => $previous_max_id }}  );
    }

    if ($table eq "stock_relationships") { 
	$rs = $self->bcs_schema()->resultset('Stock::StockRelationship')->search( { stock_relationship_id => { '>' => $previous_max_id }});
    }

    if ($table eq "cvterms") { 
	$rs = $self->bcs_schema()->resultset('Cv::Cvterm')->search( { cvterm_id => { '>' => $previous_max_id }} );
    }

    if ($table eq "cvtermprops") {
	$rs = $self->bcs_schema()->resultset('Cv::Cvtermprop')->search( { cvtermprop_id => { '>' => $previous_max_id }} );
    }
    
    if ($table eq "people") { 
	$rs = $self->people_schema()->resultset('SpPerson')->search( { sp_person_id => { '>' => $previous_max_id } } );
    }

    if ($table eq "datasets") { 
	$rs = $self->people_schema()->resultset('SpDataset')->search( { sp_dataset_id => { '>' => $previous_max_id }} );
    }

    if ($table eq "lists") { 
	$rs = $self->people_schema()->resultset('List')->search( { list_id => { '>' => $previous_max_id }} );
    }	

    if ($table eq "list_elements") { 
	$rs = $self->people_schema()->resultset('ListItem')->search( { list_item_id => { '>' => $previous_max_id }} );
    }

    if ($table eq "project_owners") {
	$rs = $self->phenome_schema()->resultset('ProjectOwner')->search( { project_owner_id => { '>' => $previous_max_id }});
    }

    if ($table eq "project_images") {
        $rs = $self->phenome_schema()->resultset('ProjectMdImage')->search( { project_md_image_id => { '>' => $previous_max_id }});
    }

    if ($table eq "projectprops") {
	$rs = $self->bcs_schema()->resultset('Project::Projectprop')->search( { projectprop_id => { '>' => $previous_max_id }});
    }

    if ($table eq "projects") {
	$rs = $self->bcs_schema()->resultset('Project::Project')->search( { project_id => { '>' => $previous_max_id }} );
    }

    if ($table eq "project_relationships") {
	$rs = $self->bcs_schema()->resultset('Project::ProjectRelationship')->search( { project_relationship_id => { '>' => $previous_max_id }} );
    }

    if ($table eq "phenotypes") { 
	$rs = $self->bcs_schema()->resultset('Phenotype::Phenotype')->search( { phenotype_id => { '>' => $previous_max_id }} );
    }

    if ($table eq "genotypes") { 
	$rs = $self->bcs_schema()->resultset('Genetic::Genotypeprop')->search( { genotypeprop_id => { '>' => $previous_max_id }} );
    }

    if ($table eq "locations") { 
	$rs = $self->bcs_schema()->resultset('NaturalDiversity::NdGeolocation')->search( { nd_geolocation_id => { '>' => $previous_max_id }} );
    }

    if ($table eq "protocols") { 
	$rs = $self->bcs_schema()->resultset('NaturalDiversity::NdProtocol')->search( { nd_protocol_id => { '>' => $previous_max_id } } );
    }

    if ($table eq "experiment_files") {
	$rs = $self->phenome_schema()->resultset('NdExperimentMdFiles')->search( { nd_experiment_md_files_id => { '>' => $previous_max_id }} );
    }

    if ($table eq "experiment_json") {
    $rs = $self->phenome_schema()->resultset('NdExperimentMdJson')->search( { nd_experiment_md_json_id => { '>' => $previous_max_id }} );
    }

    if ($table eq "experiments") { 
	$rs = $self->bcs_schema()->resultset('NaturalDiversity::NdExperiment')->search( { nd_experiment_id => { '>' => $previous_max_id } } );
    }

    if ($table eq "metadata_files") {
	#$rs = $self->metadata_schema()->resultset('MdFiles')->search( { file_id => { '>' => $previous_max_id }});
    }

    if ($table eq "dbxrefs") {
	$rs = $self->bcs_schema()->resultset('General::Dbxref')->search( { dbxref_id => { '>' => $previous_max_id } } );
    }

    if ($table eq "metadata") {
        # delete associated images first
	my $iq = "DELETE FROM phenome.stock_image where metadata_id > ?";
	my $ih = $self->dbh()->prepare($iq);
	$ih->execute($previous_max_id);
	    
        my $rs = undef;
        my $q = "DELETE FROM metadata.md_files where metadata_id > ?";
        my $h = $self->dbh()->prepare($q);
        $h->execute($previous_max_id);

        my $q2 = "DELETE FROM metadata.md_metadata where metadata_id > ? ";
        my $h2 = $self->dbh()->prepare($q2);
        $h2->execute($previous_max_id);
    }

    if ($table eq "images") {
	my $q = "DELETE FROM metadata.md_image where image_id > ?";
	my $h = $self->dbh()->prepare($q);
	$h->execute($previous_max_id);
    }

    my $count = 0;
    print STDERR "rs value: $rs";
    if ($rs) { 
        while (my $row = $rs->next()) {
            $count++;
            print STDERR "Delete $table entries $count  \r";
            $row->delete();
        }
    }
    print STDERR "\n";
}




sub DEMOLISH {
    my $self = shift;

    print STDERR  "####DEMOLISHING THIS OBJECT NOW... AND GETTING DBSTATS AGAIN\n";
    my $stats = $self->get_db_stats();

    print STDERR "# DB STATS AFTER TEST: ".Dumper($stats)."\n";
    foreach my $table (keys %$stats) {
 	if ($self->dbstats_start()->{$table} != $stats->{$table}) {
 	    print STDERR "# $0 FOR TABLE $table ENTRIES CHANGED FROM ".
 		$self->dbstats_start()->{$table} ." TO ".$stats->{$table}.". PLEASE CLEAN UP THIS TEST!\n";
 	}
    }

    $self->auditstats_end($self->get_auditdb_stats());

    print STDERR "# MODIFIED AUDIT TABLES BEFORE TEST: " .Dumper($self->auditstats_start())."\n";
    print STDERR "# MODIFIED AUDIT TABLES AFTER TEST: " .Dumper($self->auditstats_end())."\n";
}

1;
