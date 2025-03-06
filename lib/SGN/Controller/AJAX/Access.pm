
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

    my @privileges = $c->stash->{access}->check_user($resource, $c->stash->{user_id});

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
    if (! $c->stash->{access}->grant($c->stash->{user_id}, "read", "privileges")) { 
	$c->stash->{rest} = { error => "You do not have the privileges required to access this page." };
	return;
    }

    my @raw_table = $c->stash->{access}->privileges_table();

    print STDERR Dumper(\@raw_table);

    my @table;
    my %table;
    foreach my $line (@raw_table) {
	push @{ $table{$line->{role_name}}->{$line->{access_level}} }, { name => $line->{resource}, id => $line->{privilege_id} };
    }

    my $html = "<table border=\"1\" ><tr><th style=\"padding: 10px\">Role</th><th style=\"padding: 10px\">Access level</th><th style=\"padding: 10px\">Resource</th></tr>";
    my $count = 0;
    foreach my $role (sort(keys(%table))) {
	$count++;
	my $rowspan;
	my $rowspan_count = keys(%{$table{$role}});
	    
	$rowspan = " rowspan=\"$rowspan_count\" ";
	$html .= "<tr ><td  $rowspan style=\"padding: 10px\">$role</td>";
	foreach my $level (sort(keys(%{$table{$role}}))) {
	    $html .= "<td style=\"padding: 10px\">$level</td>";
	    $html .= "<td style=\"padding: 10px\">";
	    foreach my $resource (@{ $table{$role}->{$level} }) {
		$html .= "<span class=\"chip\"><a href=\"javascript:delete_privilege(".$resource->{id}.")\">X</a> ".$resource->{name}."</span>  ";
	    }
	    $html .= "";
	    $html .= "</td></tr>";
	}

    }
    	$html .= "</table>";


    
    
    $c->stash->{rest} = { data => $html }; #\@table }; 
}

sub add_privilege :Path('/ajax/access/add_privilege') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->stash->{access}->grant( $c->stash->{user_id}, "write", "privileges" )) {
	$c->stash->{rest} = { error => 'You do not have sufficient privileges to change privileges.' };
	return;
    }
    
    my $resource = $c->req->param('resource');
    my $role = $c->req->param('role');
    my $level = $c->req->param('level');

    my $r = $c->stash->{access}->add_privilege($resource, $role, $level);

    $c->stash->{rest} = $r;
}

sub delete_privilege :Path('/ajax/access/delete_privilege') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->stash->{access}->grant( $c->stash->{user_id}, "write", "privileges" )) {
	$c->stash->{rest} = { error => 'You do not have sufficient privileges to change privileges.' };
	return;
    }
    
    my $privilege_id = $c->req->param('privilege_id');

    my $r = $c->stash->{access}->delete_privilege($privilege_id);

    $c->stash->{rest} = $r;
}


1;
