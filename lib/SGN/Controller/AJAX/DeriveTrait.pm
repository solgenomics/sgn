package SGN::Controller::AJAX::DeriveTrait;

use Moose;
use Data::Dumper;
use List::Util 'max';
use Bio::Chado::Schema;
use List::Util qw | any |;
use DBI;
use DBIx::Class;

BEGIN {extends 'Catalyst::Controller::REST'}

 has 'trial_id' => (isa => 'Int',
		   is => 'rw',
		   reader => 'get_trial_id',
		   writer => 'set_trial_id',
    );

sub compute_derive_traits : Path('/ajax/phenotype/create_derived_trait') Args(0) {

	my $self = shift;
	my $c = shift;
	my $trial_id = $c->req->param('trial_id');
    	my $selected_trait = $c->req->param('trait');

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
  
    my $trial = CXGN::Trial->new( { bcs_schema => $c->dbic_schema("Bio::Chado::Schema"), trial_id => $trial_id });
    
    print "TRIAlllllllllll ID: $trial_id\n";
    my $trait_name;
    my $trait_id;
    my @traits_assayed;
    my $traits_assayed_q = $c->dbc()->dbh()->prepare("SELECT cvterm.name, cvterm.cvterm_id FROM cvterm JOIN phenotype ON (cvterm_id=cvalue_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) WHERE project_id=? and phenotype.value~? GROUP BY cvterm.name, cvterm.cvterm_id;");

    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';
    $traits_assayed_q->execute($self->get_trial_id(), $numeric_regex );
    while ( $trait_name, $trait_id = $traits_assayed_q->fetchrow_array()) { 
	push @traits_assayed, [$trait_id, ucfirst($trait_name)];
    }

    #return \@traits_assayed;
    print STDERR Dumper(@traits_assayed);
    #print "TRAIT NAME: $trait_name\n";
	#print "TRAITtttttttt ID: $traits_assayed_q\n";
	
}


1;
