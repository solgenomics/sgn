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

print "TRAIT NAME: $selected_trait\n";

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


    sub total_phenotypes { 
    my $self = shift;
    
    my $pt_rs = $self->bcs_schema()->resultset("Phenotype::Phenotype")->search( { });
    return $pt_rs;

    }


}

1;
