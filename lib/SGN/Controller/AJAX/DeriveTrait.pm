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
    my $trait_list_ref = $c->req->param('selected_trait');
    my $trait = $c->req->param('trait');

print "TRAIT NAME: $trait\n";

    if (!$c->user()) { 
	print STDERR "User not logged in... not computing trait.\n";
	$c->stash->{rest} = {error => "You need to be logged in to compute trait." };
	return;
    }
    
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
	$c->stash->{rest} = {error =>  "You have insufficient privileges to compute trait." };
	return;
    }

    my $time = DateTime->now();
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $timestamp = $time->ymd()."_".$time->hms();


}

1;
