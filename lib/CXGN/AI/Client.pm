package CXGN::AI::Client;

use Moose;
use JSON qw(encode_json decode_json);
use LWP::UserAgent;
use HTTP::Request;
use Try::Tiny;

has 'service_url' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'timeout' => (
    is      => 'ro',
    isa     => 'Num',
    default => 120,
);

has 'delegation_token' => (
    is        => 'ro',
    isa       => 'Maybe[Str]',
    predicate => 'has_delegation_token',
);

has 'request_id' => (
    is        => 'ro',
    isa       => 'Maybe[Str]',
    predicate => 'has_request_id',
);

has 'development_user_context' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {} },
);

sub chat {
    my ($self, $payload) = @_;
    return $self->_post('/api/v1/agent/chat', $payload || {});
}

sub command {
    my ($self, $payload) = @_;
    return $self->_post('/api/v1/agent/command', $payload || {});
}

sub approve_action {
    my ($self, $pending_action_id) = @_;
    die "pending_action_id is required" if !$pending_action_id;
    return $self->_post('/api/v1/actions/'.$pending_action_id.'/approve', {});
}

sub reject_action {
    my ($self, $pending_action_id) = @_;
    die "pending_action_id is required" if !$pending_action_id;
    return $self->_post('/api/v1/actions/'.$pending_action_id.'/reject', {});
}

sub memory {
    my ($self) = @_;
    return $self->_get('/api/v1/memory');
}

sub _ua {
    my ($self) = @_;
    return LWP::UserAgent->new(timeout => $self->timeout);
}

sub _url {
    my ($self, $path) = @_;
    my $base = $self->service_url;
    $base =~ s/\/$//;
    return $base.$path;
}

sub _headers {
    my ($self) = @_;
    my @headers = (
        'Accept'       => 'application/json',
        'Content-Type' => 'application/json',
    );
    push @headers, ('X-Request-ID' => $self->request_id) if $self->has_request_id;
    if ($self->has_delegation_token && defined $self->delegation_token && length $self->delegation_token) {
        push @headers, ('X-Breedbase-AI-Delegation' => $self->delegation_token);
    }
    else {
        my $ctx = $self->development_user_context || {};
        push @headers, ('X-Breedbase-User-Id' => $ctx->{user_id}) if $ctx->{user_id};
        push @headers, ('X-Breedbase-Username' => $ctx->{username}) if $ctx->{username};
        push @headers, ('X-Breedbase-Roles' => join(',', @{$ctx->{roles} || []})) if $ctx->{roles};
        push @headers, ('X-Breedbase-Scopes' => join(',', @{$ctx->{scopes} || []})) if $ctx->{scopes};
    }
    return @headers;
}

sub _post {
    my ($self, $path, $payload) = @_;
    my $request = HTTP::Request->new(POST => $self->_url($path));
    $request->header($self->_headers);
    $request->content(encode_json($payload || {}));
    return $self->_execute($request);
}

sub _get {
    my ($self, $path) = @_;
    my $request = HTTP::Request->new(GET => $self->_url($path));
    $request->header($self->_headers);
    return $self->_execute($request);
}

sub _execute {
    my ($self, $request) = @_;
    my $response = $self->_ua->request($request);
    if (!$response->is_success) {
        my $safe_status = $response->code . ' ' . $response->message;
        die "Breedbase AI service request failed: $safe_status";
    }
    my $decoded;
    try {
        $decoded = decode_json($response->decoded_content || '{}');
    }
    catch {
        die "Breedbase AI service returned malformed JSON";
    };
    return $decoded;
}

sub redacted_headers {
    my ($self, $headers) = @_;
    my %copy = %{$headers || {}};
    for my $name (keys %copy) {
        if ($name =~ /authorization|token|cookie|secret|delegation/i) {
            $copy{$name} = '[REDACTED]';
        }
    }
    return \%copy;
}

__PACKAGE__->meta->make_immutable;
1;
