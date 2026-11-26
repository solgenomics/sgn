package CXGN::Pedigree::Upload;
use strict;
use warnings;
use JSON;
use Cwd qw(abs_path);
use File::Spec;
use CXGN::Login;
use CXGN::People::Person;
use CXGN::Pedigree::Parentage;

=head1 NAME

CXGN::Pedigree::Upload - standard authorization and input checks for pedigree uploads

=cut

=head2 authorize($context, %options)

Require a curator or submitter before parsing files or JSON: the signed-in
user, or the owner of a current sgn_session_id token. When both are given they
must be the same person. With require_user => 1 a token alone is not enough.
Nobody may upload while logins are not allowed.

=cut

sub authorize {
    my ($class, $c, %options) = @_;
    if ($c->req->method ne 'POST') {
        $c->stash->{rest} = {error => 'Use POST to upload pedigree information.'};
        return;
    }
    my $denied = sub {
        $c->stash->{rest} = {error => 'Log in as a submitter or curator to upload pedigree information.'};
        return;
    };
    # the conditions of CXGN::Login::login_allowed
    my $config = $c->config;
    return $denied->() if $config->{disable_login} || $config->{is_mirror}
        || ( ( $config->{dbname} // '' ) =~ /sandbox/ && $config->{production_server} );
    return $denied->() if $options{require_user} && !$c->user;
    my ($token_id, $token_role);
    my $session = $c->req->param('sgn_session_id');
    if (defined($session) && length($session)) {
        my ($user, $type, undef, $expired) = CXGN::Login->new($c->dbc->dbh)->query_from_cookie($session);
        return $denied->() if !$user || $expired;
        ($token_id, $token_role) = ($user, $type // '');
    }
    my ($id, $name, $role);
    if (my $user = $c->user) {
        $role = $user->check_roles('curator') ? 'curator' : $user->check_roles('submitter') ? 'submitter' : undef;
        my $person = $user->get_object;
        $id = $person->get_sp_person_id;
        $name = $person->get_username;
        return $denied->() if defined($token_id) && $token_id != $id;
    } elsif (defined $token_id) {
        $role = $token_role if $token_role eq 'curator' || $token_role eq 'submitter';
        $id = $token_id;
        $name = CXGN::People::Person->new($c->dbc->dbh, $id)->get_username if $role;
    }
    return $denied->() if !$id || !$role;
    return {id => $id, name => $name, role => $role};
}

=head2 pedigree_rows($text)

Decode request JSON correctly whether Catalyst has already decoded UTF-8, then
validate its shape before constructing pedigree objects.

=cut

sub pedigree_rows {
    my ($class, $text) = @_;
    die "Pedigree JSON is required.\n" unless defined($text) && !ref($text) && length($text);
    my $data = eval {JSON->new->utf8(!utf8::is_utf8($text))->decode($text)};
    die "Invalid pedigree JSON.\n" if $@ || ref($data) ne 'HASH' || ref($data->{pedigrees}) ne 'ARRAY';
    my $rows = $data->{pedigrees};
    die "No pedigree rows were supplied.\n" unless @$rows;
    for my $row (@$rows) {
        die "Each pedigree row must be an object.\n" unless ref($row) eq 'HASH';
        for my $field ('progeny name', 'female parent accession', 'type') {
            die "A non-empty $field is required in each pedigree row.\n"
                unless defined($row->{$field}) && !ref($row->{$field}) && length($row->{$field});
        }
        die "Male parent must be a stock name.\n" if ref($row->{'male parent accession'});
        die "Invalid source row number.\n" if defined($row->{_row}) && $row->{_row} !~ /^[1-9][0-9]*$/;
    }
    return $rows;
}

=head2 cross_archive($context, $path, $user_id)

Accept a readable verified cross-upload file of this user under the configured
archive, resolving symlinks and traversal before opening it. The verification
step archives the file with CXGN::UploadFile, which keeps the files of each
user in archive_path/user_id/cross_upload.

=cut

sub cross_archive {
    my ($class, $c, $path, $user_id) = @_;
    die "Verified cross upload was not found in the archive.\n" unless defined($user_id) && $user_id =~ /^[0-9]+$/;
    my $root = abs_path(File::Spec->catdir($c->config->{archive_path}, $user_id, 'cross_upload'));
    my $file = defined($path) && !ref($path) ? abs_path($path) : undef;
    die "Verified cross upload was not found in the archive.\n"
        unless $root && $file && index($file, $root.'/') == 0 && -f $file && -r $file && $file =~ /\.xlsx?$/i;
    return $file;
}

1;
