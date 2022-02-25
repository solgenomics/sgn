
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

    return undef;
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
    my $rs = $self->bcs_schema()->resultset('Stock::Stock')->search( {} );
    $stats->{stocks} = $rs->count();

    my $rs = $self->bcs_schema()->resultset('Stock::StockRelationship')->search( {} );
    $stats->{stock_relationships} = $rs->count();

    # count cvterms
    #
    $rs = $self->bcs_schema()->resultset('Cv::Cvterm')->search( {} );
    $stats->{cvterms} = $rs->count();

    # count users
    #
    $rs = $self->people_schema()->resultset('SpPerson')->search( {} );
    $stats->{people} = $rs->count();

    $rs = $self->people_schema()->resultset('SpDataset')->search( {} );
    $stats->{datasets} = $rs->count();
    
    $rs = $self->people_schema()->resultset('List')->search( {} );
    $stats->{lists} = $rs->count();

    $rs = $self->people_schema()->resultset('ListItem')->search( {} );
    $stats->{list_elements} = $rs->count();
    
    # count projects
    #
    $rs = $self->bcs_schema()->resultset('Project::Project')->search( {} );
    $stats->{projects} = $rs->count();

    $rs = $self->bcs_schema()->resultset('Project::ProjectRelationship')->search( {} );
    $stats->{project_relationships} = $rs->count();

    # count phenotypes
    #
    $rs = $self->bcs_schema()->resultset('Phenotype::Phenotype')->search( {} );
    $stats->{phenotypes} = $rs->count();

    # count genotypes
    #
    $rs = $self->bcs_schema()->resultset('Genetic::Genotypeprop')->search( {} );
    $stats->{genotypes} = $rs->count();
    
    # count locations
    $rs = $self->bcs_schema()->resultset('NaturalDiversity::NdGeolocation')->search( {} );
    $stats->{locations} = $rs->count();

    # count nd_protocols
    $rs = $self->bcs_schema()->resultset('NaturalDiversity::NdProtocol')->search( {} );
    $stats->{protocols} = $rs->count();

    # count nd_experiments
    $rs = $self->bcs_schema()->resultset('NaturalDiversity::NdExperiment')->search( {} );
    $stats->{nd_experiments} = $rs->count();

    # count metadata entries
    $rs = $self->metadata_schema()->resultset('MdMetadata')->search( {} );
    $stats->{md_metadata} = $rs->count();
    
    print STDERR "STATS : ".Dumper($stats);

    print STDERR "DONE WITH get_db_stats.\n";
    return $stats;
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
    
}



1;
