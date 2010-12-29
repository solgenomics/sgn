package SGN::SiteFeatures::CrossReference;
use Moose;
use namespace::autoclean;

use MooseX::Types::URI 'Uri';

has 'url' => ( documentation => <<'',
the absolute or relative URL where the full resource can be accessed, e.g. /unigenes/search.pl?q=SGN-U12

    is  => 'ro',
    isa => Uri,
    required => 1,
    coerce => 1,
   );


has 'text' => ( documentation => <<'',
a short text description of the contents of the resource referenced, for example "6 SGN Unigenes"

    is  => 'ro',
    isa => 'Str',
    required => 1,
   );


has 'is_empty' => ( documentation => <<'',
true if the cross reference is empty, may be used as a rendering hint

    is  => 'ro',
    isa => 'Bool',
    default => 0,
   );

has 'feature' => ( documentation => <<'',
the site feature object this cross reference points to

    is => 'ro',
    required => 1,
   );

sub TO_JSON {
    my ( $self ) = @_;
    return {
        map { $_ => "$self->{$_}" }
        qw( url is_empty text )
    };
}

sub cr_cmp {
    my ( $a, $b ) = @_;
    no warnings 'uninitialized';
    return
        $a->feature->feature_name cmp $b->feature->feature_name
     || $a->is_empty <=> $b->is_empty
     || $a->text cmp $b->text
     || $a->url.'' cmp $b->url.'';
}

sub cr_eq {
    my ( $a, $b ) = @_;

    no warnings 'uninitialized';
    return !($a->is_empty xor $b->is_empty)
        && $a->text eq $b->text
        && $a->url.'' eq $b->url.''
        && $a->feature->feature_name eq $b->feature->feature_name;
}

sub uniq {
    my %seen;
    grep !$seen{ _uniq_str($_) }++, @_;
}
sub _uniq_str {
    my ( $self ) = @_;
    return join ',', (
        $self->feature->feature_name,
        $self->url,
        $self->text,
       );
}

{ no warnings 'once';
  *distinct = \&uniq;
}


1;



