
=head1 NAME

CXGN::RespectfulWords - find disrespectful words in a text written by the public

=head1 SYNOPSIS

  use CXGN::RespectfulWords;
  my $checker = CXGN::RespectfulWords->new(allowed => [ 'saco' ], blocked => [ 'bad phrase' ]);
  my @words = $checker->find($text);   # the words found, as written in the lists

=head1 DESCRIPTION

Used for the texts that people without a Breedbase account write (variety
votes of decision meetings: names, notes). No word list is kept in the code
or on disk: each checker fetches the lists when it is first used (one fetch
per language for the life of the object, normally one web request) from

=over

=item * the "List of Dirty, Naughty, Obscene, and Otherwise Bad Words"
(https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words,
CC BY 4.0), one list per language. Only the lists are fetched: the text being
checked never leaves the server.

=item * Regexp::Common::profanity (English), always, also when the lists cannot be fetched.

=item * C<blocked>: words or phrases a site adds.

=back

The lists include everyday words (in farming too: "saco", "pau", "comer",
"aborto", "pinto", "martillo"...), and surnames: C<allowed> words are never
reported. A default allowed list is used unless C<allowed_default> is false.
Words match whole words only, ignoring case and accents; repeated letters in
the text are also tried squeezed ("MERDAAA"). C<lists> (language => text) can
be given instead of fetching (tests).

=head1 AUTHOR

Chris Simoes

=cut

package CXGN::RespectfulWords;

use strict;
use warnings;
use Text::Unidecode qw(unidecode);
use Regexp::Common qw(profanity);

my $SOURCE = 'https://raw.githubusercontent.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/master';

# everyday words, plant biology terms and surnames that the fetched lists include
my @ALLOWED_DEFAULT = (
    'aborto', 'amador', 'aranha', 'burro', 'cerveja', 'chupar', 'comer', 'dar', 'fecal', 'frango assado', 'grelho',
    'inferno', 'mama', 'pau', 'pinto', 'saco', 'torneira', 'sexo', 'asno', 'caca', 'concha', 'drogas', 'infierno',
    'maldito', 'martillo', 'orina', 'pis', 'trio', 'semen', 'butt', 'domination', 'intercourse', 'sex', 'sexual',
    'sexually', 'suck', 'sucks', 'escort', 'nude',
);

# a few seconds at most: the checks run inside web requests
my $TIMEOUT = 4;

sub new {
    my ($class, %args) = @_;
    return bless {
        languages => $args{languages} || [ 'en', 'pt', 'es' ],
        source => $args{source} || $SOURCE,
        allowed => $args{allowed} || [],
        blocked => $args{blocked} || [],
        allowed_default => $args{allowed_default} // 1,
        lists => $args{lists},
    }, $class;
}

# lower case, no accents, only letters, digits and single spaces
sub normalize {
    my $t = lc(unidecode(shift // ''));
    $t =~ s/[^a-z0-9]+/ /g;
    $t =~ s/^ | $//g;
    return $t;
}

sub _squeeze { my $w = shift; $w =~ tr/a-z//s; return $w; }

# the list of a language, fetched now (undef when the source cannot be reached)
sub _fetch {
    my ($self, $lang) = @_;
    return $self->{lists}->{$lang} if $self->{lists};
    return if $lang !~ /^[a-z]{2,3}$/;
    my $content = eval {
        require LWP::UserAgent;
        my $ua = LWP::UserAgent->new(timeout => $TIMEOUT, agent => 'word-list-client');
        my $r = $ua->get("$self->{source}/$lang");
        $r->is_success() ? $r->decoded_content() : undef;
    };
    print STDERR "CXGN::RespectfulWords: cannot fetch the $lang word list from $self->{source}\n" if !defined $content;
    return $content;
}

# { words => {normalized => as listed}, phrases => [[normalized, as listed]], allowed => {normalized => 1} },
# built once per object
sub _lists {
    my $self = shift;
    return $self->{built} if $self->{built};
    my %allowed = map { normalize($_) => 1 } (@{ $self->{allowed} }, ($self->{allowed_default} ? @ALLOWED_DEFAULT : ()));
    my @entries = map { s/^\s+|\s+$//gr } map { split /\r?\n/, ($self->_fetch($_) // '') } @{ $self->{languages} };
    my (%words, @phrases);
    foreach my $e (@entries, @{ $self->{blocked} }) {
        my $n = normalize($e);
        next if $n eq '' || $allowed{$n};
        if ($n =~ / /) { push @phrases, [ $n, $e ]; }
        else { $words{$n} //= $e; }
    }
    $self->{built} = { words => \%words, phrases => \@phrases, allowed => \%allowed };
    return $self->{built};
}

# the disrespectful words of a text (as written in the lists), each once
sub find {
    my ($self, $text) = @_;
    return () if !defined $text || $text !~ /\S/;
    my $l = $self->_lists();
    my $norm = normalize($text);
    my (@found, %seen);
    my $add = sub { my $w = lc(shift); push @found, $w if !$seen{$w}++; };
    foreach my $w (split / /, $norm) {
        next if $l->{allowed}->{$w};
        my $s = _squeeze($w);
        if (exists $l->{words}->{$w}) { $add->($l->{words}->{$w}); }
        elsif (exists $l->{words}->{$s} && !$l->{allowed}->{$s}) { $add->($l->{words}->{$s}); }
        elsif ($w =~ /^$RE{profanity}$/ || ($s =~ /^$RE{profanity}$/ && !$l->{allowed}->{$s})) { $add->($w); }
    }
    my $padded = " $norm ";
    foreach my $p (@{ $l->{phrases} }) {
        $add->($p->[1]) if index($padded, " $p->[0] ") >= 0;
    }
    return @found;
}

1;
