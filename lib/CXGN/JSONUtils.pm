package CXGN::JSONUtils;

=encoding utf8

=head1 NAME

CXGN::JSONUtils - helpers for JSON text stored in the database

=head1 SYNOPSIS

  use CXGN::JSONUtils qw(decode_stored_json);

  my $additional_info = decode_stored_json($projectprop_row->value());

=head1 DESCRIPTION

The database connections are opened with C<pg_enable_utf8> (see
L<SGN::Role::Site::DBConnector>), so DBD::Pg returns every text and jsonb
value as a Perl character string. A JSON value can therefore come back from
the database in two forms:

=over 4

=item *

JSON that was written as characters (C<to_json()>, C<< JSON->new->encode() >>,
SQL, jsonb built in the database) comes back as the same characters.
C<decode_json()> expects UTF-8 octets, so it dies on these values as soon as
they contain non-ASCII text ("Wide character in subroutine entry" for
characters above U+00FF, "malformed UTF-8 character in JSON string" for
characters such as "é" or "°").

=item *

JSON that was written with C<encode_json()> (UTF-8 octets) is upgraded by
DBD::Pg on the way in, so every octet is stored as one character.
C<decode_json()> returns the original text for these values, while decoding
them as characters returns mojibake ("MÃ¼ller" instead of "Müller").

=back

Checking C<utf8::is_utf8()> does not tell the two apart, because DBD::Pg sets
the flag on both.

=head1 FUNCTIONS

=head2 decode_stored_json

 Usage:   my $data = decode_stored_json($json_text);
 Desc:    decodes JSON text read from the database. It first decodes the
          text as UTF-8 octets, exactly like decode_json(); if that fails,
          it decodes the text as characters.
 Ret:     the decoded data structure
 Args:    a JSON string as returned by DBI or DBIx::Class
 Side Effects: dies, like decode_json(), if the text is not valid JSON
          either way; the error is reported at the caller's line, and $@
          is left untouched by this call when it succeeds.
 Note:    text that was stored as characters, consists only of characters
          below U+0100 and also happens to be valid UTF-8 (for example the
          literal mojibake "Ã©") is decoded as UTF-8 ("é").

=cut

use strict;
use warnings;

use Carp qw(croak);
use JSON;

use base 'Exporter';

our @EXPORT_OK = qw/
    decode_stored_json
/;
our @EXPORT = ();

my $octet_json = JSON->new->utf8();
my $character_json = JSON->new();

sub decode_stored_json {
    my $json_text = shift;
    local $@;

    my $data = eval { $octet_json->decode($json_text) };
    return $data if !$@;
    my $octet_error = $@;

    $data = eval { $character_json->decode($json_text) };
    return $data if !$@;

    # neither decode worked: report the error at the caller's call site
    # (like decode_json() does), not at this line.
    croak $octet_error;
}

1;
