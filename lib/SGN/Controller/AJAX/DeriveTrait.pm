package SGN::Controller::AJAX::DeriveTrait;

use Moose;
use Data::Dumper;
use List::Util 'max';
use Bio::Chado::Schema;
use List::Util qw | any |;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);


sub compute_derive_traits : Path('/ajax/phenotype/create_derived_trait') Args(0) {

    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");   
    my $trial_id = $c->req->param('trial_id');
    my $selected_trait = $c->req->param('trait');
    $c->stash->{trial_id} = $trial_id;
    $c->stash->{trial} = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $trial_id });

print "TRAIT NAME: $selected_trait\n";
print "TRIAl ID: $trial_id\n";

    if (!$c->user()) { 
	print STDERR "User not logged in... not computing trait.\n";
	$c->stash->{rest} = {error => "You need to be logged in to compute trait." };
	return;
    }
    
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
	$c->stash->{rest} = {error =>  "You have insufficient privileges to compute trait." };
	return;
    }

   
    has 'trial_id' => (isa => 'Int',
		   is => 'rw',
		   reader => 'get_trial_id',
		   writer => 'set_trial_id',
    );


    my $dbh = $c->dbc->dbh();
    my $trait_sql = shift;
    my $traits_measured = CXGN::BreederSearch->new(
	{
	    dbh=>$dbh, 
	    schema => $schema,
	    #trial_id =>$c->stash->{trial_id}
	    trial_id =>$c->req->param('trial_id')
	});
	
	my $pheno_info = $traits_measured-> get_phenotype_info();

	
	print STDERR Dumper($pheno_info);
}

1;
