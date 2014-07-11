

package SGN::Test::Fixture;

use Moose;
use DBI;
use DBIx::Class;
use Config::Any;
use Data::Dumper;
use File::Slurp qw | read_file |;
use Bio::Chado::Schema;

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

    $self->dbh(DBI->connect($dsn, $self->config->{dbuser}, $self->config->{dbpass}));

    $self->bcs_schema(Bio::Chado::Schema->connect($dsn, $self->config->{dbuser}, $self->config->{dbpass}));
    
    $self->phenome_schema(Phenome::Schema->connect($dsn, $self->config->{dbuser}, $self->config->{dbpass}));
    

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

has 'phenome_schema' => (isa => 'Phenome::Schema', 
			 is ='rw',
    );


1;
