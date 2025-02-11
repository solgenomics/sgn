
package SGN::Controller::AJAX::Access;

use Moose;
use Data::Dumper;
use List::Util 'any';
use CXGN::Access;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub access :Path('/ajax/access/privileges/') :Args(2) {
    my $self = shift;
    my $c = shift;
    my $resource = shift;
    my $role = shift;

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    
    my @privileges = $c->stash->{access} -> check_role($role, $resource);

    $c->stash->{rest} = { privileges => \@privileges };
}

sub access_by_user :Path('/ajax/access/by_user_id/') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $resource = shift;

    my $sp_person_id;
    if (!$c->user()) {
	print STDERR "Not logged in!\n";
	$sp_person_id = undef;
    }
    else {
        $sp_person_id = $c->user()->get_object()->get_sp_person_id();
    }
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $access = CXGN::Access->new( { people_schema => $people_schema });

    my @privileges = $access -> check_user($resource, $sp_person_id);

    $c->stash->{rest} = { privileges => \@privileges };
}

sub access_table :Path('/ajax/access/table') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! (my $user = $c->user())) {
	$c->stash->{rest} = { error => "You must be logged in to use this resource" };
	return;
    }

    print STDERR "USER ID: ".$c->stash->{user_id}."\n";
    if (! $c->stash->{access}->grant($c->stash->{user_id}, "read", "access_table_page")) { 
	$c->stash->{rest} = { error => "You do not have the privileges required to access this page." };
	return;
    }

    my @raw_table = $c->stash->{access}->privileges_table();

    print STDERR Dumper(\@raw_table);

    my @table;
    foreach my $line (@raw_table) {
	
	push @table, [ $line->{resource}, $line->{role_name}, $line->{access_level} ];
    }
    
    $c->stash->{rest} = { data => \@table }; 
}
	

1;
