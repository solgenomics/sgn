
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
use SGN::Schema;

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

has 'metadata_schema' => (isa => 'CXGN::Metadata::Schema', 
			  is => 'rw',
    );

1;
