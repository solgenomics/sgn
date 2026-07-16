package SGN::Controller::AJAX::AI;

use Moose;
use JSON qw(decode_json);
use Scalar::Util qw(looks_like_number);
use Try::Tiny;
use Catalyst::Controller::REST;

use CXGN::AI::Client;
use CXGN::AI::Delegation;
use CXGN::Dataset;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub chat : Path('/ajax/ai/chat') Args(0) {
    my ($self, $c) = @_;
    return $self->_json_error($c, 405, 'POST is required') if $c->req->method ne 'POST';
    $self->_require_enabled($c);
    $self->_require_login($c);

    my $payload = $self->_request_payload($c);
    $self->_reject_browser_identity($c, $payload);
    $self->_validate_context($c, $payload->{context});

    my $request_id = $self->_request_id;
    my $client = $self->_client($c, $request_id, [qw(dataset:read phenotype:read)]);

    my $response;
    try {
        $response = $client->chat({
            conversation_id => $payload->{conversation_id},
            message         => $payload->{message} || 'Analyze these Quality Control results.',
            context         => $payload->{context},
            qc_result       => $payload->{qc_result},
        });
    }
    catch {
        return $self->_json_error($c, 503, 'Breedbase AI is currently unavailable. The Quality Control analysis is still available.');
    };

    $c->stash->{rest} = $response;
}

sub command : Path('/ajax/ai/command') Args(0) {
    my ($self, $c) = @_;
    return $self->_json_error($c, 405, 'POST is required') if $c->req->method ne 'POST';
    $self->_require_enabled($c);
    $self->_require_login($c);

    my $payload = $self->_request_payload($c);
    $self->_reject_browser_identity($c, $payload);
    return $self->_json_error($c, 400, 'message is required')
        if !defined($payload->{message}) || ref($payload->{message}) || $payload->{message} !~ /\S/;
    return $self->_json_error($c, 400, 'message is too long') if length($payload->{message}) > 4000;
    $self->_validate_context($c, $payload->{context}, 1);
    my $command_context = { %{ $payload->{context} } };
    $self->_add_dataset_id_from_name($c, $payload->{message}, $command_context);

    if (exists $payload->{confirmed} && !$self->_is_boolean($payload->{confirmed})) {
        return $self->_json_error($c, 400, 'confirmed must be a boolean');
    }
    if (exists $payload->{action_type} && ($payload->{action_type} || '') ne 'create_filtered_dataset') {
        return $self->_json_error($c, 400, 'Unsupported AI command action');
    }

    my $request_id = $self->_request_id;
    my $client = $self->_client($c, $request_id, [qw(dataset:read phenotype:read)]);
    my $response;
    try {
        $response = $client->command({
            conversation_id => $payload->{conversation_id},
            message         => $payload->{message},
            context         => $command_context,
            confirmed       => $payload->{confirmed} ? 1 : 0,
            action_type     => $payload->{action_type},
        });
    }
    catch {
        return $self->_json_error($c, 503, 'Breedbase AI is currently unavailable. Existing Quality Control tools remain available.');
    };

    $c->stash->{rest} = $response;
}

sub approve_action : Path('/ajax/ai/action/approve') Args(0) {
    my ($self, $c) = @_;
    return $self->_json_error($c, 405, 'POST is required') if $c->req->method ne 'POST';
    $self->_require_enabled($c);
    $self->_require_login($c);

    my $payload = $self->_request_payload($c);
    my $pending_action_id = $payload->{pending_action_id} || $c->req->param('pending_action_id');
    return $self->_json_error($c, 400, 'pending_action_id is required') if !$pending_action_id;

    my $request_id = $self->_request_id;
    my $client = $self->_client($c, $request_id, [qw(dataset:read phenotype:read phenotype:write dataset:write)]);
    my $response;
    try {
        $response = $client->approve_action($pending_action_id);
    }
    catch {
        return $self->_json_error($c, 503, 'Breedbase AI could not approve or execute the pending action. No Breedbase changes were made by this request.');
    };

    $c->stash->{rest} = $response;
}

sub reject_action : Path('/ajax/ai/action/reject') Args(0) {
    my ($self, $c) = @_;
    return $self->_json_error($c, 405, 'POST is required') if $c->req->method ne 'POST';
    $self->_require_enabled($c);
    $self->_require_login($c);

    my $payload = $self->_request_payload($c);
    my $pending_action_id = $payload->{pending_action_id} || $c->req->param('pending_action_id');
    return $self->_json_error($c, 400, 'pending_action_id is required') if !$pending_action_id;

    my $request_id = $self->_request_id;
    my $client = $self->_client($c, $request_id, [qw(dataset:read phenotype:read)]);
    my $response;
    try {
        $response = $client->reject_action($pending_action_id);
    }
    catch {
        return $self->_json_error($c, 503, 'Breedbase AI could not reject the pending action.');
    };

    $c->stash->{rest} = $response;
}

sub memory : Path('/ajax/ai/memory') Args(0) {
    my ($self, $c) = @_;
    return $self->_json_error($c, 405, 'GET is required') if $c->req->method ne 'GET';
    $self->_require_enabled($c);
    $self->_require_login($c);

    my $request_id = $self->_request_id;
    my $client = $self->_client($c, $request_id, [qw(memory:read)]);
    my $response;
    try {
        $response = $client->memory();
    }
    catch {
        return $self->_json_error($c, 503, 'Breedbase AI memory is currently unavailable.');
    };
    $c->stash->{rest} = $response;
}

sub _require_enabled {
    my ($self, $c) = @_;
    return if $c->config->{enable_ai_agent};
    return $self->_json_error($c, 403, 'Breedbase AI is not enabled for this instance.');
}

sub _require_login {
    my ($self, $c) = @_;
    return if !$c->config->{ai_require_login};
    return if $c->user();
    return $self->_json_error($c, 401, 'You must be logged in to use Breedbase AI.');
}

sub _request_payload {
    my ($self, $c) = @_;
    my $data = $c->request->data;
    return $data if ref($data) eq 'HASH';

    my $body = $c->req->body;
    if ($body) {
        my $decoded = eval { decode_json($body) };
        return $decoded if ref($decoded) eq 'HASH';
    }
    return { %{ $c->req->params || {} } };
}

sub _reject_browser_identity {
    my ($self, $c, $payload) = @_;
    if (exists $payload->{user_id} || exists $payload->{user_context}) {
        return $self->_json_error($c, 400, 'Browser-provided user identity is not accepted.');
    }
}

sub _validate_context {
    my ($self, $c, $context, $allow_empty_quality_control) = @_;
    return $self->_json_error($c, 400, 'context is required') if ref($context) ne 'HASH';

    my %allowed = map { $_ => 1 } qw(page_type dataset_id trial_id study_id trait_id trait_name workflow project_names traits);
    for my $key (keys %$context) {
        return $self->_json_error($c, 400, "Invalid context field: $key") if !$allowed{$key};
    }

    my $page_type = $context->{page_type} || '';
    my %allowed_type = map { $_ => 1 } qw(quality_control dataset trial);
    return $self->_json_error($c, 400, 'Invalid AI context type') if !$allowed_type{$page_type};

    return $self->_json_error($c, 400, 'project_names must be a list of names') if exists $context->{project_names} && !$self->_string_array($context->{project_names});
    return $self->_json_error($c, 400, 'traits must be a list of names') if exists $context->{traits} && !$self->_string_array($context->{traits});

    if ($page_type eq 'quality_control') {
        my $has_dataset = $self->_positive_int($context->{dataset_id});
        my $has_validated_projects = ref($context->{project_names}) eq 'ARRAY' && @{ $context->{project_names} };
        return $self->_json_error($c, 400, 'dataset_id or project_names is required for Quality Control AI context')
            if !$allow_empty_quality_control && !$has_dataset && !$has_validated_projects;
    }
    if ($page_type eq 'dataset' && !$self->_positive_int($context->{dataset_id})) {
        return $self->_json_error($c, 400, 'dataset_id is required for dataset AI context');
    }
    if ($page_type eq 'trial' && !$self->_positive_int($context->{trial_id})) {
        return $self->_json_error($c, 400, 'trial_id is required for trial AI context');
    }
}

sub _add_dataset_id_from_name {
    my ($self, $c, $message, $context) = @_;
    return if $context->{dataset_id};

    my $dataset_name = $self->_extract_dataset_name($message);
    return if !defined $dataset_name;

    my $user = $c->user();
    return if !$user;
    my $sp_person_id = $user->get_object()->get_sp_person_id();
    my $datasets = CXGN::Dataset->get_datasets_by_user(
        $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id),
        $sp_person_id,
    );
    my $dataset_id = $self->_dataset_id_for_name($datasets, $dataset_name);
    $context->{dataset_id} = $dataset_id if $dataset_id;
}

sub _extract_dataset_name {
    my ($self, $message) = @_;
    return if !defined $message || ref($message);
    return $1 if $message =~ /\bdataset\s+["\x27]([^"\x27]+)["\x27]/i;
    return $1 if $message =~ /\bdataset\s+([A-Za-z][A-Za-z0-9_.:-]*)\b/i && lc($1) !~ /^(?:id|page|this)$/;
    return;
}

sub _dataset_id_for_name {
    my ($self, $datasets, $dataset_name) = @_;
    return if ref($datasets) ne "ARRAY" || !defined $dataset_name;

    my $wanted = lc($dataset_name);
    $wanted =~ s/^\s+|\s+$//g;
    my %matches;
    for my $row (@$datasets) {
        next if ref($row) ne "ARRAY" || !defined($row->[0]) || !defined($row->[1]);
        my $name = $row->[1];
        $name =~ s/^public\s+-\s+//i;
        $name =~ s/^\s+|\s+$//g;
        $matches{$row->[0]} = 1 if lc($name) eq $wanted;
    }
    my @ids = keys %matches;
    return @ids == 1 ? $ids[0] : undef;
}

sub _string_array {
    my ($self, $value) = @_;
    return 0 if ref($value) ne 'ARRAY';
    for my $item (@$value) {
        return 0 if ref($item) || !defined($item) || $item eq '';
    }
    return 1;
}

sub _positive_int {
    my ($self, $value) = @_;
    return defined $value && looks_like_number($value) && int($value) == $value && $value > 0;
}

sub _is_boolean {
    my ($self, $value) = @_;
    return 0 if !defined $value;
    return 1 if !ref($value) && ($value eq '0' || $value eq '1');
    return 1 if ref($value) =~ /Boolean$/;
    return 0;
}

sub _client {
    my ($self, $c, $request_id, $scopes) = @_;
    my $service_url = $c->config->{ai_service_url} || 'http://localhost:8000';
    my $timeout = $c->config->{ai_service_timeout} || 120;
    my $user_context = $self->_user_context($c, $scopes);
    my $delegation_token;

    if ($c->config->{ai_delegation_private_key_file}) {
        my $delegation = CXGN::AI::Delegation->new(
            private_key_file => $c->config->{ai_delegation_private_key_file},
            issuer           => $c->config->{ai_delegation_issuer} || 'breedbase',
            audience         => $c->config->{ai_delegation_audience} || 'breedbase-ai',
            ttl              => $c->config->{ai_delegation_token_ttl} || 300,
            algorithm        => $c->config->{ai_delegation_algorithm} || 'RS256',
        );
        $delegation_token = $delegation->create_token(
            %$user_context,
            request_id => $request_id,
        );
    }

    return CXGN::AI::Client->new(
        service_url              => $service_url,
        timeout                  => $timeout,
        request_id               => $request_id,
        delegation_token         => $delegation_token,
        development_user_context => $user_context,
    );
}

sub _user_context {
    my ($self, $c, $scopes) = @_;
    my $user = $c->user()->get_object();
    my @roles = $c->user()->roles;
    return {
        user_id  => $user->get_sp_person_id(),
        username => $user->get_username(),
        roles    => \@roles,
        scopes   => $scopes || [],
    };
}

sub _request_id {
    my ($self) = @_;
    my $uuid = eval {
        require Data::UUID;
        Data::UUID->new->create_str;
    };
    return $uuid || time.'-'.$$;
}

sub _json_error {
    my ($self, $c, $status, $message) = @_;
    $c->response->status($status);
    $c->stash->{rest} = { error => $message };
    $c->detach;
}

__PACKAGE__->meta->make_immutable;
1;
