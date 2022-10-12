
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
             WHERE lower(first_name) like ? OR lower(last_name) like ?
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
    my $person_roles = CXGN::People::Roles->new({ bcs_schema=>$schema });
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
    my $person_roles = CXGN::People::Roles->new({ bcs_schema=>$schema });
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

    my $schema = $c->dbic_schema("CXGN::People::Schema");

    my %roles;
    my $rs1 = $schema->resultset("SpRole")->search( { } );
    while (my $row = $rs1->next()) {
	$roles{$row->sp_role_id} = $row->name();
    }
    
    my $rs2 = $schema->resultset("SpPerson")->search(
	{ },
	{ join => 'sp_person_roles',
	  '+select' => ['sp_person_roles.sp_role_id', 'sp_person_roles.sp_person_role_id' ],
	  '+as'     => ['sp_role_id', 'sp_person_role_id' ],
	  order_by => 'sp_role_id' });
    
    my @data;
    my %hash;

    my %role_colors = ( curator => 'red', submitter => 'orange', user => 'green' );
    my $default_color = "#0275d8";
    

    while (my $row = $rs2->next()) {
	my $person_name = $row->first_name." ".$row->last_name();
	my $delete_link = "";
	my $add_user_link = '&nbsp;&nbsp;<a href="#" onclick="javascript:add_user_role('.$row->get_column('sp_person_id').", \'".$person_name."\')\"><span style=\"color:darkgrey;width:8px;height:8px;border:solid;border-width:1px;padding:1px;\"><b>+</b></a></span>";
	if ($c->user()->has_role("curator")) {
	    $delete_link = '<a href="javascript:delete_user_role('.$row->get_column('sp_person_role_id').')"><b>X</b></a>';
	}
	
	else {
	    $delete_link = "X";
	}
	
	$hash{$row->sp_person_id}->{userlink} = '<a href="/solpeople/personal-info.pl?sp_person_id='.$row->sp_person_id().'">'.$row->first_name()." ".$row->last_name().'</a>';

	my $role_name = $roles{$row->get_column('sp_role_id')};

	print STDERR "ROLE : $role_name\n";
	
	if (! $c->user()->has_role("curator")) {
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




###
1;

