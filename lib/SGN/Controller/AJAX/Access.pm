
package SGN::Controller::AJAX::Access;

use Moose;
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
    my $access = CXGN::Access->new( { people_schema => $people_schema });

    my @privileges = $access -> check_role($role, $resource);

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

sub manage_access :Path('/ajax/access/manage') :Args(0) {
    my $self = shift;
    my $c = shift;

    print STDERR "manage access\n";
    if (! $c->user()) {
	$c->stash->{rest} = { error => "You must be logged in to use this function." };
	return;
    }

    my $schema = $c->dbic_schema("CXGN::People::Schema");

    my %roles;
    my $rs1 = $schema->resultset("SpRole")->search( { } );
    while (my $row = $rs1->next()) {
	$roles{$row->sp_role_id} = $row->name();
    }
    
    my @data;
    my %hash;

    my %role_colors = ( curator => 'red', submitter => 'orange', user => 'green' );
    my $default_color = "#0275d8";

    my @access_table = $c->stash->{access}->get_access_table();

    foreach $row (@access_table) {
	my $delete_link = "";
	my $add_resource_link = '&nbsp;&nbsp;<a href="#" onclick="javascript:add_role_to_resource('.$row->{role_id}.", \'".$row->{role_name}."\')\"><span style=\"color:darkgrey;width:8px;height:8px;border:solid;border-width:1px;padding:1px;\"><b>+</b></a></span>";
	if ($c->user()->has_role("curator")) {
	    $delete_link = '<a href="javascript:delete_user_role('.$row->{sp_resource_id}.')"><b>X</b></a>';
	}
	
	else {
	    $delete_link = "X";
	}
	
	my $role_name = $row->{role_name};

	print STDERR "ROLE : $role_name\n";
	
	if (! $c->user()->has_role("admin")) {
	    # only show breeding programs
	    if ($role_name !~ /curator|user|submitter/) {
		$hash{$row->sp_person_id}->{userroles} .= '<span style="border-radius:16px;color:white;border-style:solid;border:1px;padding:8px;margin:10px;background-color:'.$default_color.'"><b>'.$role_name."</b></span>";
	    }
	}
	else {
	    my $color = $role_colors{$role_name} || $default_color;
	    $hash{$row->sp_person_id}->{userroles} .= '<span style="border-radius:16px;color:white;border-style:solid;border:1px;padding:8px;margin:6px;background-color:'.$color.'"><b>'. $delete_link."&nbsp;&nbsp; ".$role_name."</b></span>";
	    $hash{$row->sp_person_id}->{add_user_link} = $add_user_link;
	}
	    
    }

    foreach my $k (keys %hash) {
	$hash{$k}->{userroles} .= $hash{$k}->{add_user_link};
	push @data, [ $hash{$k}->{userlink}, $hash{$k}->{userroles} ];
    }
    
    $c->stash->{rest} = { data => \@data };
}



1;
