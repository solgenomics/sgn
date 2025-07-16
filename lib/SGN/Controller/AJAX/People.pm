
=head1 NAME

SGN::Controller::AJAX::People - a REST controller class to provide the
backend for the sgn_people schema

=head1 DESCRIPTION

REST interface for searching people, getting user data, etc.

=head1 AUTHOR

Naama Menda <nm249@cornell.edu>


=cut

package SGN::Controller::AJAX::People;

use Moose;

use Data::Dumper;
use List::MoreUtils qw /any /;
use Try::Tiny;
use CXGN::People::Schema;
use CXGN::People::Roles;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );



=head2 autocomplete

Public Path: /ajax/people/autocomplete

Autocomplete a person name.  Takes a single GET param,
    C<person>, responds with a JSON array of completions for that term.

=cut

sub autocomplete : Local : ActionClass('REST') { }

sub autocomplete_GET :Args(1) {
    my ( $self, $c , $print_id ) = @_;

    my $person = $c->req->param('term');
    # trim and regularize whitespace
    $person =~ s/(^\s+|\s+)$//g;
    $person =~ s/\s+/ /g;
    my $q = "SELECT sp_person_id, first_name, last_name FROM sgn_people.sp_person
             WHERE lower(first_name) like ? OR lower(last_name) like ? and censor =0 and disabled IS NULL
             LIMIT 20";

    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute( lc "$person\%" , lc "$person\%" );
    my @results;
    while (my ($sp_person_id, $first_name, $last_name) = $sth->fetchrow_array ) {
        $sp_person_id = $print_id ? "," . $sp_person_id : undef;
        push @results , "$first_name, $last_name $sp_person_id";
    }
    $c->stash->{rest} = \@results;
}

sub people_and_roles : Path('/ajax/people/people_and_roles') : ActionClass('REST') { }

sub people_and_roles_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $person_roles = CXGN::People::Roles->new({ people_schema=>$people_schema });
    my $sp_persons = $person_roles->get_sp_persons();
    my $sp_roles = $person_roles->get_sp_roles();
    my %results = ( sp_persons => $sp_persons, sp_roles => $sp_roles );
    $c->stash->{rest} = \%results;
}

sub add_person_role : Path('/ajax/people/add_person_role') : ActionClass('REST') { }

sub add_person_role_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $user = $c->user();
    if (!$user){
        $c->stash->{rest} = {error=>'You must be logged in first!'};
        $c->detach;
    }
    if (!$user->check_roles("curator")) {
        $c->stash->{rest} = {error=>'You must be logged in with the correct role!'};
        $c->detach;
    }
    my $sp_person_id = $c->req->param('sp_person_id');
    my $sp_role_id = $c->req->param('sp_role_id');
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $person_roles = CXGN::People::Roles->new({ people_schema=>$people_schema });
    my $add_role = $person_roles->add_sp_person_role($sp_person_id, $sp_role_id);
    $c->stash->{rest} = {success=>1};
}

sub roles :Chained('/') PathPart('ajax/roles') CaptureArgs(0) {
    my $self = shift;
    my $c = shift;

    print STDERR "ajax/roles...\n";

    $c->stash->{message} = "processing";
}

sub list_roles :Chained('roles') PathPart('list') Args(0) {
    my $self = shift;
    my $c = shift;

    print STDERR "roles list\n";
    if (! $c->user()) {
	$c->stash->{rest} = { error => "You must be logged in to use this function." };
	return;
    }
    
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $r = CXGN::People::Roles->new( { people_schema => $people_schema });
    
    my %roles = $r->role_hash();

    print STDERR "ROLE HASH: ".Dumper(\%roles);
    
    my @rows = $r->list_roles();
    my ($user_role) = $c->user->get_object()->get_roles();
    my @data = $self->format_role_results($user_role, \@rows, \%roles);
    
    $c->stash->{rest} = { data => \@data };
}

sub list_roles_for_user :Chained('roles') PathPart('list') Args(1) {
    my $self = shift;
    my $c = shift;
    my $sp_person_id = shift;

    print STDERR "roles list\n";
    if (! $c->user()) {
	$c->stash->{rest} = { error => "You must be logged in to use this function." };
	return;
    }

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    #my $bcs_schema = $c->dbic_schema("Bio::Chado::Schema");
    my $r = CXGN::People::Roles->new( { people_schema => $people_schema });

    my %roles = $r->role_hash();
    my @rows = $r->list_roles( $c->user->get_object()->get_sp_person_id() );

    my ($user_role) = $c->user->get_object()->get_roles();

    my @data = $self->format_role_results($user_role, \@rows, \%roles);

    $c->stash->{rest} = { data => \@data };
}


sub format_role_results {
    my $self = shift;
    my $user_role = shift;
    my $rows = shift;
    my $roles = shift;

    my @data;
    my @rows;
    my %hash;
    my %roles;

    if (ref($rows)) { @rows = @$rows; }
    if (ref($roles)) { %roles = %$roles; }

    my %role_colors = ( curator => 'red', submitter => 'orange', user => 'green' );
    my $default_color = "#0275d8";

    foreach my $row (@rows) { 
	my $person_name = $row->first_name." ".$row->last_name();
	my $delete_link = "";
	my $add_user_link = '&nbsp;&nbsp;<a href="#" onclick="javascript:add_user_role('.$row->get_column('sp_person_id').", \'".$person_name."\')\"><span style=\"color:darkgrey;width:8px;height:8px;border:solid;border-width:1px;padding:1px;\"><b>+</b></a></span>";

	if ($user_role eq "curator") {
	    $delete_link = '<a href="javascript:delete_user_role('.$row->get_column('sp_person_role_id').')"><b>X</b></a>';
	}

	else {
	    $delete_link = "X";
	}

	$hash{$row->sp_person_id}->{userlink} = '<a href="/solpeople/personal-info.pl?sp_person_id='.$row->sp_person_id().'">'.$row->first_name()." ".$row->last_name().'</a>';

	my $role_name = $roles{$row->get_column('sp_role_id')};

	if ($user_role ne "curator") {
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

    #$c->stash->{rest} = { data => \@data };
    return @data;

}



# sub add_user :Chained('roles') PathPart('add/association/user') CaptureArgs(1) {
#     my $self = shift;
#     my $c = shift;
#     my $user_id = shift;

#     $c->stash->{sp_person_id} = $user_id;
# }


# sub add_user_role :Chained('add_user') PathPart('role') CaptureArgs(1) {
#     my $self = shift;
#     my $c = shift;
#     my $role_id = shift;

#     if (! $c->user()) {
# 	$c->stash->{rest} = { error => "You must be logged in to use this function." };
# 	return;
#     }

#     if (! $c->user()->has_role("curator")) {
# 	$c->stash->{rest} = { error => "You don't have the necessary privileges for maintaining user roles." };
# 	return;
#     }


# }


sub delete :Chained('roles') PathPart('delete/association') Args(1) {
    my $self = shift;
    my $c = shift;
    my $sp_person_role_id = shift;

    if (! $c->user()) {
	$c->stash->{rest} = { error => "You must be logged in to use this function." };
	return;
    }

    if (! $c->user()->has_role("curator")) {
	$c->stash->{rest} = { error => "You don't have the necessary privileges for maintaining user roles." };
	return;
    }

    my $schema = $c->dbic_schema("CXGN::People::Schema");

    my $row = $schema->resultset("SpPersonRole")->find( { sp_person_role_id => $sp_person_role_id } );

    if (!$row) {
	$c->stash->{rest} = { error => 'The relationship does not exist.' };
	return;
    }
    $row->delete();

    $c->stash->{rest} = { message => "Role associated with user deleted." };
}


sub teams :Chained('/') PathPart('ajax/teams') CaptureArgs(0) {
    my $self = shift;
    my $c = shift;
}

sub list_teams :Chained('teams') PathPart('list') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user()) {
	$c->stash->{rest} = { error => "You must be logged in to use this function." };
	return;
    }

    my $schema = $c->dbic_schema("CXGN::People::Schema");

#    my %teams;
#    my $rs1 = $schema->resultset("SpRole")->search( { } );
#    while (my $row = $rs1->next()) {
#	$roles{$row->sp_role_id} = $row->name();
#    }

    my $rs2 = $schema->resultset("SpTeam")->search(
	{ },
	{ join => 'sp_person_teams',
	  '+select' => ['sp_person_teams.sp_person_id', 'sp_person_teams.sp_person_team_id' ],
	  '+as'     => ['sp_person_id', 'sp_person_team_id' ],
	  order_by => 'sp_person_id' });

    my @data;
    my %hash = ();

    my $default_color = "#0275d8";

    while (my $row = $rs2->next()) {
	my $team_name = $row->name();
	my $sp_team_id = $row->get_column('sp_team_id');
	my $team_description = $row->description();
	my $delete_link = "";

	print STDERR "TEAM NAME = $team_name ($sp_team_id)\n";

	$hash{$row->sp_team_id}->{add_user_link} = '&nbsp;&nbsp;<a href="#" onclick="javascript:open_add_team_member_dialog('.$sp_team_id.', \''.$team_name.'\')"><span style="color:darkgrey;width:8px;height:8px;border:solid;border-width:1px;padding:1px;"><b>+</b></a></span>';
#	if ($c->user()->has_role("curator")) {
#	    $delete_link = '<a href="javascript:delete_user_role('.$row->get_column('sp_person_role_id').')"><b>X</b></a>';
#	}

#	else {
	    $delete_link = "X";
#	}

#	$hash{$row->sp_person_id}->{userlink} = '<a href="/solpeople/personal-info.pl?sp_person_id='.$row->sp_person_id().'">'.$row->first_name()." ".$row->last_name().'</a>';

#	my $role_name = $roles{$row->get_column('sp_role_id')};

	my $sp_person_id = $row->get_column('sp_person_id');
	print STDERR "PERSON ID: $sp_person_id\n";

	my $person = $schema->resultset("SpPerson")->find( { sp_person_id => $sp_person_id });


	if ($person) {
	    my $first_name = $person->first_name();
	    my $last_name = $person->last_name();

	    my $username = $first_name." ".$last_name;

	    print STDERR "Adding $username...\n";
#	if (! $c->user()->has_role("curator")) {
#	    # only show breeding programs
#	    if ($role_name !~ /curator|user|submitter/) {
#		$hash{$row->sp_person_id}->{userroles} .= '<span style="border-radius:16px;color:white;border-style:solid;border:1px;padding:8px;margin:10px;background-color:'.$default_color.'"><b>'.$role_name."</b></span>";
#	    }
#	}
#	else {
	    my $color =  $default_color;
	    $hash{$row->sp_team_id}->{team_members} .= '<span style="border-radius:16px;color:white;border-style:solid;border:1px;padding:8px;margin:6px;background-color:'.$color.'"><b>'. $delete_link."&nbsp;&nbsp; ".$username."</b></span>";

	    #	}
	}
	$hash{$row->sp_team_id}->{team_name} = $row->name();
	$hash{$row->sp_team_id}->{team_description} = $row->description();
	$hash{$row->sp_team_id}->{team_stage_gate} = "[not yet]";
	$hash{$row->sp_team_id}->{team_delete} = 'X';
    }


    foreach my $k (keys %hash) {
	print STDERR "Building info for index $k...\n";
	$hash{$k}->{team_members} = $hash{$k}->{team_members}." ".$hash{$k}->{add_user_link};
	push @data, [ $hash{$k}->{team_name}, $hash{$k}->{team_description}, $hash{$k}->{team_stage_gate}, $hash{$k}->{team_members}, $hash{$k}->{team_delete} ];
    }

    print STDERR "DATA: ".Dumper(\@data);

    $c->stash->{rest} = { data => \@data };
}


sub add_team :Path('/ajax/people/add_team') Args(0) {
    my $self = shift;
    my $c = shift;

     if (! $c->user()) {
	$c->stash->{rest} = { error => "You must be logged in to use this function." };
	return;
    }

    my $name = $c->req->param("name");
    my $description = $c->req->param("description");
    my $stage_gate_id = $c->req->param("stage_gate_id");

    my $schema = $c->dbic_schema("CXGN::People::Schema");

    eval {
	my $rs = $schema->resultset("SpTeam")->find_or_create(
	    {
		name => $name,
		description => $description,
		sp_stage_gate_id => $stage_gate_id,
	    });

    };

    if ($@) {
	$c->stash->{rest} = { error =>  "An error occurred! $@\n" };
	return;
    }

    $c->stash->{rest} = { success => 1 };

}

sub add_team_member :Path('/ajax/teams/add_member') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user()) {
	$c->stash->{rest} = { error => "You must be logged in to use this function." };
	return;
    }

    my $team_member_name = $c->req->param('team_member_name');
    my $management_role = $c->req->param('management_role');
    my $sp_team_id = $c->req->param("sp_team_id_for_member");

    print STDERR "RECEIVED INFO: $team_member_name, $management_role, $sp_team_id!\n";

    my $schema = $c->dbic_schema("CXGN::People::Schema");

    eval {
	my($first_name, $last_name) = split /\s*\,\s*|\s*$/, $team_member_name;

	print STDERR "Searching name: $first_name, $last_name.\n";

	my $prs = $schema->resultset("SpPerson")->search( { first_name => $first_name, last_name => $last_name });
	if ($prs->count() > 1) {
	    die "Too many people with name $team_member_name in the database.";
	}
	elsif ($prs->count() == 0) {
	    die "No such person $team_member_name in the database.";
	}
	else {
	    my $row = $prs->next();
	    my $rs = $schema->resultset("SpPersonTeam")->find_or_create(
		{
		    sp_team_id => $sp_team_id,
		    sp_person_id => $row->sp_person_id(),
		});
	}
    };

    if ($@) {
	$c->stash->{rest} = { error => "An error occurred trying to add a team member ($@)" };
    }
    else {
	$c->stash->{rest} = { message => "success" };
    }



}

sub remove_team_member :Chained('teams') PathPart('delete/association') Args(1) {
    my $self = shift;
    my $c = shift;
    my $sp_person_team_id = shift;

    if (! $c->user()) {
	$c->stash->{rest} = { error => "You must be logged in to use this function." };
	return;
    }

    if (! $c->user()->has_role("curator")) {
	$c->stash->{rest} = { error => "You don't have the necessary privileges for maintaining user roles." };
	return;
    }

    my $schema = $c->dbic_schema("CXGN::People::Schema");

    my $row = $schema->resultset("SpPersonTeam")->find( { sp_person_team_id => $sp_person_team_id } );

    if (!$row) {
	$c->stash->{rest} = { error => 'The relationship does not exist.' };
	return;
    }
    $row->delete();

    $c->stash->{rest} = { message => "Member associated with team has been deleted." };
}

sub delete_team :Chained('teams') PathPart('delete') Args(0) {
    my $self = shift;
    my $c = shift;
    my $sp_team_id = shift;

    if (! $c->user()) {
	$c->stash->{rest} = { error => "You must be logged in to use this function." };
	return;
    }

    if (! $c->user()->has_role("curator")) {
	$c->stash->{rest} = { error => "You don't have the necessary privileges for maintaining user roles." };
	return;
    }

    my $schema = $c->dbic_schema("CXGN::People::Schema");

    my $row = $schema->resultset("SpTeam")->find( { sp_team_id => $sp_team_id } );

    if (!$row) {
	$c->stash->{rest} = { error => 'The specified team does not exist.' };
	return;
    }
    $row->delete();



}


sub add_stage_gate :Path('/ajax/people/add_stage_gate') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user()) {
        $c->stash->{rest} = { error => "You must be logged in to use this function." };
        return;
    }

    my $name = $c->req->param("name");
    my $description = $c->req->param("description");
    my $schema = $c->dbic_schema("CXGN::People::Schema");

    eval {
        my $rs = $schema->resultset("SpStageGate")->find_or_create({
            name => $name,
            description => $description,
        });
#        my $stage_gate_id = $rs->sp_stage_gate_id();
#        print STDERR "STAGE GATE ID =".Dumper($stage_gate_id)."\n";
    };

    if ($@) {
        $c->stash->{rest} = { error =>  "An error occurred! $@\n" };
        return;
    }

    $c->stash->{rest} = { success => 1 };

}


sub list_stage_gates :Path('/ajax/stage_gates/list') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user()) {
        $c->stash->{rest} = { error => "You must be logged in to use this function." };
        return;
    }

    if (! $c->user()->has_role("curator")) {
        $c->stash->{rest} = { error => "You don't have the necessary privileges for maintaining stage gate." };
        return;
    }

    my $schema = $c->dbic_schema("CXGN::People::Schema");
    my $rs = $schema->resultset("SpStageGate")->search( { } );

    my @data;
    while (my $row = $rs->next()) {
        my $name = $row->name();
        my $description = $row->description();
        my $sp_stage_gate_id = $row->sp_stage_gate_id();
        #push @data, [ $name."[$sp_stage_gate_id]", $description ];
        push @data, [ $name, $description ];
    }
    #print STDERR "STAGE GATES: ".Dumper(\@data);

    $c->stash->{rest} =  { data => \@data };
}




###
1;
