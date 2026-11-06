package CXGN::TimeUtils;

use strict;
use warnings;
use DateTime::Format::ISO8601;
use Time::Piece;

=head2 normalize_db_timestamp($value)

Normalize an ISO8601 or SQL timestamp to a UTC, timezone-free database value.
Naive legacy timestamps are interpreted as UTC. Empty values remain absent;
invalid nonempty values are refused rather than losing their timezone.
Sub-microsecond instants are refused because PostgreSQL cannot retain them;
trailing zero precision is accepted without changing the instant.

=cut

sub normalize_db_timestamp {
    my $value = shift;
    return undef if !defined($value) || $value eq ''; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    die "Timestamp must be a scalar value.\n" if ref($value);
    $value =~ s/^\s+|\s+$//g;
    return undef if $value eq ''; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    my $iso = $value;
    $iso =~ s/^(\d{4})(\d{2})(\d{2})$/$1-$2-$3/;
    $iso =~ s/^(\d{4}-\d{2}-\d{2})(?:\s+|_)/$1T/;
    $iso =~ s/([+-]\d{2})(\d{2})$/$1:$2/;
    die "Invalid timestamp '$value'; use a full ISO8601 date or timestamp.\n" if $iso !~ /^\d{4}-\d{2}-\d{2}(?:$|T\d{2}:\d{2})/;
    # Check the original digits before the parser's numeric conversion can
    # round a tiny nonzero tail away. The dependency refuses fractional minutes.
    die "Timestamp precision exceeds the database's microsecond resolution.\n"
        if $iso =~ /T\d{2}:\d{2}:\d{2}[.,]\d{6}(\d+)/ && $1 =~ /[^0]/;
    $iso .= 'Z' if $iso =~ /T/ && $iso !~ /(?:Z|[+-]\d{2}:\d{2})$/i;
    my $dt = eval { DateTime::Format::ISO8601->parse_datetime($iso) };
    die "Invalid timestamp '$value'; use an ISO8601 date or timestamp.\n" if !$dt || $@;
    die "Timestamp precision exceeds the database's microsecond resolution.\n" if $dt->nanosecond % 1000;
    $dt->set_time_zone('UTC');
    my $result = $dt->strftime('%Y-%m-%d %H:%M:%S');
    if ($dt->nanosecond) {
        my $fraction = sprintf('%09d', $dt->nanosecond);
        $fraction =~ s/0+$//;
        $result .= '.'.$fraction;
    }
    return $result;
}

sub db_time_to_iso {
    my $value = normalize_db_timestamp(shift);
    return $value if !defined($value);
    $value =~ s/ /T/;
    return $value.'Z';
}

sub date_to_iso_timestamp {
    my $value = shift;
    return $value if !defined($value) || $value eq '';
    my $time = Time::Piece->strptime($value, '%Y-%B-%d');
    return $time->datetime.'Z';
}

sub db_time_to_iso_utc { return db_time_to_iso(@_); }

1;
