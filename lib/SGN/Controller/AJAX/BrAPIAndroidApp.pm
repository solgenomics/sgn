
=head1 NAME

SGN::Controller::AJAX::BrAPIAndroidApp - a REST controller class to provide additional functionality required for Android app

=head1 DESCRIPTION


=head1 AUTHOR

Nicolas Morales <nm529@cornell.edu>

=cut

package SGN::Controller::AJAX::BrAPIAndroidApp;

use Moose;
use Data::Dumper;
use JSON;
use CXGN::People::Login;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub new_database : Path('/brapiapp/new_database') : ActionClass('REST') { }

sub new_database_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $name = $c->req->param('databaseName');
    my $url = $c->req->param('databaseURL');
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $previous_name_search = $bcs_schema->resultset('General::Db')->search({name=>$name});
    if ($previous_name_search->count > 0){
        $c->stash->{rest} = {error => "The given database name already exists and cannot be added!"};
        $c->detach();
    }
    my $previous_url_search = $bcs_schema->resultset('General::Db')->search({url=>$url});
    if ($previous_url_search->count > 0){
        $c->stash->{rest} = {error => "The given database URL already exists and cannot be added!"};
        $c->detach();
    }

    my $new_entry = $bcs_schema->resultset('General::Db')->create({
        name=>$name,
        url=>$url,
        description=>'BrAPI_App_Database_Display'
    });
    if ($new_entry->db_id){
        $c->stash->{rest} = {success => 1};
    } else {
        $c->stash->{rest} = {error => 'The new database entry was not saved!'};
    }
    
}

sub list_databases : Path('/brapiapp/list_databases') : ActionClass('REST') { }

sub list_databases_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my @db_list;

    my $db_rs = $bcs_schema->resultset('General::Db')->search({description=>'BrAPI_App_Database_Display'});
    while(my $r = $db_rs->next()){
        push @db_list, [$r->name, $r->url];
    }
    $c->stash->{rest} = {database_list=>\@db_list};
}

sub register : Path('/brapiapp/register') : ActionClass('REST') { }

sub register_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $username = $c->req->param('username');
    my $password = $c->req->param('password');
    my $email = $c->req->param('email');
    my $organization = $c->req->param('organization');
    my $first_name  = $c->req->param('first_name');
    my $last_name = $c->req->param('last_name');

    my $new_user = CXGN::People::Login->new($c->dbc->dbh);
    $new_user -> set_username($username);
    $new_user -> set_password($password);
    $new_user -> set_pending_email($email);
    #$new_user -> set_confirm_code($confirm_code);
    #$new_user -> set_disabled('unconfirmed account');
    $new_user -> set_organization($organization);
    $new_user -> store();

    #this is being added because the person object still uses two different objects, despite the fact that we've merged the tables
    my $person_id=$new_user->get_sp_person_id();
    my $new_person=CXGN::People::Person->new($c->dbc->dbh,$person_id);
    $new_person->set_first_name($first_name);
    $new_person->set_last_name($last_name);
    $new_person->store();

    $c->stash->{rest} = {success => 1};
}

1;
