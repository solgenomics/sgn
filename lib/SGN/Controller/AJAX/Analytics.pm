package SGN::Controller::AJAX::Analytics;

use Moose;

use File::Slurp;
use Data::Dumper;
use URI::FromHash 'uri';
use JSON;
use CXGN::BreederSearch;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default => 'application/json',
    stash_key => 'rest',
    map => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub list_analytics_protocols_by_user_table :Path('/ajax/analytics_protocols/by_user') Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $protocol_type = $c->req->param('analytics_protocol_type');

    my $protocol_type_where = '';
    if ($protocol_type) {
        my $protocol_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $protocol_type, 'protocol_type')->cvterm_id();
        $protocol_type_where = "nd_protocol.type_id = $protocol_type_cvterm_id AND ";
    }

    my $protocolprop_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analytics_protocol_properties', 'protocol_property')->cvterm_id();

    my %available_types = (
        SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_imagery_analytics_env_simulation_protocol', 'protocol_type')->cvterm_id() => 'Drone Imagery Environment Simulation'
    );

    my $q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.type_id, nd_protocol.description, nd_protocol.create_date, nd_protocolprop.value
        FROM nd_protocol
        JOIN nd_protocolprop USING(nd_protocol_id)
        WHERE $protocol_type_where nd_protocolprop.type_id=$protocolprop_type_cvterm_id;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    my @table;
    while (my ($nd_protocol_id, $name, $type_id, $description, $create_date, $props_json) = $h->fetchrow_array()) {
        push @table, [
            '<a href="/analytics_protocols/'.$nd_protocol_id.'">'.$name."</a>",
            $description,
            $available_types{$type_id},
            $create_date
        ];
    }

    #print STDERR Dumper(\@table);
    $c->stash->{rest} = { data => \@table };
}

sub list_analytics_protocols_result_files :Path('/ajax/analytics_protocols/result_files') Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $people_schema = $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $analytics_protocol_id = $c->req->param('analytics_protocol_id');

    if (!$analytics_protocol_id) {
        $c->stash->{rest} = { error => "No ID given!" };
        $c->detach();
    }

    my $analytics_experiment_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'analytics_protocol_experiment', 'experiment_type')->cvterm_id();

    my $q = "SELECT nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocol.description, basename, dirname, md.file_id, md.filetype, nd_protocol.type_id, nd_experiment.type_id
        FROM metadata.md_files AS md
        JOIN metadata.md_metadata AS meta ON (md.metadata_id=meta.metadata_id)
        JOIN phenome.nd_experiment_md_files using(file_id)
        JOIN nd_experiment using(nd_experiment_id)
        JOIN nd_experiment_protocol using(nd_experiment_id)
        JOIN nd_protocol using(nd_protocol_id)
        WHERE nd_protocol.nd_protocol_id=$analytics_protocol_id AND nd_experiment.type_id=$analytics_experiment_type_cvterm_id;";
    print STDERR $q."\n";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my @table;
    while (my ($model_id, $model_name, $model_description, $basename, $filename, $file_id, $filetype, $model_type_id, $experiment_type_id, $property_type_id, $property_value) = $h->fetchrow_array()) {
        # $result{$model_id}->{model_id} = $model_id;
        # $result{$model_id}->{model_name} = $model_name;
        # $result{$model_id}->{model_description} = $model_description;
        # $result{$model_id}->{model_type_id} = $model_type_id;
        # $result{$model_id}->{model_type_name} = $schema->resultset("Cv::Cvterm")->find({cvterm_id => $model_type_id })->name();
        # $result{$model_id}->{model_experiment_type_id} = $experiment_type_id;
        # $result{$model_id}->{model_files}->{$filetype} = $filename."/".$basename;
        # $result{$model_id}->{model_file_ids}->{$file_id} = $basename;
        push @table, [$basename, $filetype, "<a href='/breeders/phenotyping/download/$file_id'>Download</a>"];
    }

    $c->stash->{rest} = { data => \@table };
}

sub _check_user_login {
    my $c = shift;
    my $role_check = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to do this!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to do this!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    if ($role_check && $user_role ne $role_check) {
        $c->stash->{rest} = {error=>'You must have permission to do this! Please contact us!'};
        $c->detach();
    }
    return ($user_id, $user_name, $user_role);
}

1;
