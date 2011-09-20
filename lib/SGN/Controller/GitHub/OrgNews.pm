=head1 NAME

SGN::Controller::GitHub::OrgNews - controller that fetches and makes
HTML showing the latest GitHub activity involving our github org.

=cut

package SGN::Controller::GitHub::OrgNews;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

use Cache::File;
use LWP;
use JSON;
use Storable ();
use URI;
use XML::Atom::Feed;

BEGIN { extends 'Catalyst::Controller' }

=head1 CONFIGURATION

=head2 num_entries

Number of most recent entries to output.  Default 3.

=cut

has 'num_entries' => (
    is => 'ro',
    default => 5,
    );

=head2 title_regex

Quoted regular expression to use for filtering the titles of events.
Default: C<< qr!solgenomics/! >>

=cut

{
    my $tr = subtype as 'RegexpRef';
    coerce $tr, from 'Str',
        via {
            # defend against code injection
            s/;//g; /^qr/ or die "invalid regexp";
            eval $_
        };

    has 'title_regex' => (
        is      => 'ro',
        isa     => $tr,
        coerce  => 1,
        default => sub { qr!solgenomics/! },
    );
}

=head1 PUBLIC ACTIONS

=head2 org_news

Public path: /github/org_news

Display HTML showing the most recent events by people in this organization.

=cut

sub org_news : Path('/github/org_news') Args(1) {
    my ( $self, $c, $orgname ) = @_;
    $orgname =~ s/[^a-z]//g;
    $c->stash->{org_name} = $orgname;
    $c->forward('fetch_org_news') or return;

    $c->stash->{template} = '/github/org_news.mas';
    $c->forward('View::BareMason');
}

sub fetch_org_news : Private {
    my ( $self, $c ) = @_;

    my $orgname = $c->stash->{org_name};

    my $num_entries = $c->req->params->{'num_entries'};
    $num_entries = $self->num_entries unless defined $num_entries;

    # get the members of the org
    my $response    = $c->stash->{org_response} =
        $self->_http_cache->thaw("https://api.github.com/orgs/$orgname/members");
    my $org_members = $c->stash->{org_members}  =
        eval { decode_json( $response->content ) };
    die "Cannot parse response: ".$response->content if $@;

    # TODO: remove this
    #@{ $org_members } = grep { $_->{login} eq 'rbuels' } @$org_members;

    # decorate each user with their feed
    for my $member ( @$org_members ) {
        my $xml  = $self->_http_cache->thaw("https://github.com/$member->{login}.atom")->content;
        my $feed = XML::Atom::Feed->new( \$xml );
        $member->{news_feed} = $feed;
    }

    # make an array of the 5 most recent feed entries
    my $entries = $c->stash->{entries} = [
        ( sort { $b->published cmp $a->published }
          grep { $_->title =~ $self->title_regex }
          map {
             $_->{news_feed}->entries
          } @$org_members
        )[ 0 .. $num_entries-1 ]
    ];

    return 1;
}

has '_http_cache' => (
    is => 'ro',
    lazy_build => 1,
   ); sub _build__http_cache {
       my $self = shift;

       # will cache for no more than 10 minutes, and also has a 5%
       # chance at each access of re-fetching something, which will
       # tend to prevent one person winning the complete 'booby prize'
       # and having to wait for an entire re-fetch.
       my $ua = LWP::UserAgent->new;
       return Cache::File->new(
           cache_root       => $self->_app->path_to( $self->_app->tempfiles_subdir('cache','github_http') ),

           default_expires  => '10 minutes',
           size_limit       => 1_000_000,
           removal_strategy => 'Cache::RemovalStrategy::LRU',
           load_callback => sub {
               my $cache_entry = shift;
               my $url = $cache_entry->key;
               Storable::nfreeze( $ua->get( $url ) );
           },
           validate_callback => sub {
               # 5% of the time, re-update an entry even if it is not expired
               return rand > 0.05 ? 1 : 0
           },
          );
   }


1;
