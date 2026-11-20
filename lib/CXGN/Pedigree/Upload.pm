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

=head2 authorize($context)

Authorize the actual session as a curator or submitter before parsing files or
JSON. The existing sgn_session_id transport is supported and expired sessions
are rejected. Client-supplied user IDs are never an authority or audit identity.

=cut

sub authorize {
    my ($class, $c) = @_;
    if ($c->req->method ne 'POST') {
        $c->stash->{rest} = {error => 'Use POST to upload pedigree information.'};
        return;
    }
    my ($id, $name, $role);
    my $session = $c->req->param('sgn_session_id');
    if (defined($session) && length($session)) {
        my ($user, $type, undef, $expired) = CXGN::Login->new($c->dbc->dbh)->query_from_cookie($session);
        if ($user && !$expired && ($type eq 'curator' || $type eq 'submitter')) {
            ($id, $role) = ($user, $type);
            $name = CXGN::People::Person->new($c->dbc->dbh, $id)->get_username;
        }
    } elsif ($c->user) {
        my @roles = $c->user->roles;
        $role = grep({$_ eq 'curator'} @roles) ? 'curator' : grep({$_ eq 'submitter'} @roles) ? 'submitter' : undef;
        if ($role) {
            $id = $c->user->get_object->get_sp_person_id;
            $name = $c->user->get_object->get_username;
        }
    }
    if (!$id || !$role) {
        $c->stash->{rest} = {error => 'Log in as a submitter or curator to upload pedigree information.'};
        return;
    }
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
