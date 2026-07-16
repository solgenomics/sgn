package CXGN::AI::Delegation;

use Moose;
use Carp qw(croak);

has 'private_key_file' => (
    is        => 'ro',
    isa       => 'Maybe[Str]',
    predicate => 'has_private_key_file',
);

has 'issuer' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'breedbase',
);

has 'audience' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'breedbase-ai',
);

has 'ttl' => (
    is      => 'ro',
    isa     => 'Int',
    default => 300,
);

has 'algorithm' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'RS256',
);

sub create_token {
    my ($self, %args) = @_;
    croak 'ai_delegation_private_key_file is not configured' if !$self->has_private_key_file;

    my $user_id = $args{user_id} || croak 'user_id is required';
    my $now = time;
    my $payload = {
        iss => $self->issuer,
        aud => $self->audience,
        sub => 'user:'.$user_id,
        iat => $now,
        exp => $now + $self->ttl,
        scope => $args{scopes} || [],
    };
    $payload->{username} = $args{username} if defined $args{username};
    $payload->{roles} = $args{roles} if $args{roles};
    $payload->{request_id} = $args{request_id} if defined $args{request_id};
    $payload->{conversation_id} = $args{conversation_id} if defined $args{conversation_id};

    my $private_key = _read_text($self->private_key_file);
    require Crypt::JWT;
    Crypt::JWT->import('encode_jwt');
    return encode_jwt(
        payload => $payload,
        key => \$private_key,
        alg => $self->algorithm,
        extra_headers => { typ => 'JWT' },
    );
}

sub _read_text {
    my ($path) = @_;
    open(my $fh, '<', $path) or croak "Could not read AI delegation private key file: $!";
    local $/;
    my $content = <$fh>;
    close($fh);
    return $content;
}

__PACKAGE__->meta->make_immutable;
1;
