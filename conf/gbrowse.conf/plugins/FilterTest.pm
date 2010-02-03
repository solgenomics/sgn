package Bio::Graphics::Browser::Plugin::FilterTest;

# $Id: FilterTest.pm,v 1.2 2004/02/03 22:40:35 marclogghe Exp $
# Filter plugin to filter features from the ORFs track

use strict;
use vars qw($VERSION @ISA);
use constant DEBUG => 0;

use Bio::Graphics::Browser::Plugin;
use CGI qw(:standard *pre);

$VERSION = '0.O1';

@ISA = qw(Bio::Graphics::Browser::Plugin);

my @FILTERS = (
    [
        'Only ORFs on Watson strand', q{ $_[0]->name =~ /w$/i}
    ],
    [
        'Only ORFs on Crick strand', q{ $_[0]->name =~ /c$/i}
    ],
    [
        'ORF length < ', q{ $_[0]->length < $value }
    ],
    [
        'ORF length >= ', q{ $_[0]->length >= $value }
    ],
);
my %LABELS = map { $_ => $FILTERS[$_][0] } ( 0 .. $#FILTERS );

sub new
{
    my $class = shift;
    bless { original_key => undef }, $class;
}

sub name
{
    'ORFs';
}

sub type
{
    'filter';
}


sub description
{
    my $key = shift ()->name;
    p("This Filter plugin filters the features from the ORFS track ($key)")
      . p("This plugin was written by Marc Logghe.");
}

sub filter
{
    my $self    = shift;
    my $config  = $self->configuration;
    my $browser = $self->browser_config
      or return;    # need a browser object for filtering !

    my $feature_file = $browser->config;
    my $name         = $self->name;
    my $value        = $config->{filter_value};

    # save the orignal key
    my $key = $browser->setting( $name => 'key' );
    $self->{original_key} ||= $key;

    if ( $config->{filter_on} eq 'yes' )
    {
        # pass closure to browser object for filtering
        my $filter = eval "sub { $FILTERS[$config->{filter}][1] }";
        $feature_file->set( $name, filter => $filter );

        # change key so that filtering (or failing) is clearly indicated
        # also remove value in key when it is not needed for filtering
        my $new_key =
          $@ ? "$self->{original_key} (filter incorrect)"
          : ( $FILTERS[ $config->{filter} ][1] =~ m/\$value/
            ? "$self->{original_key} ($FILTERS[$config->{filter}][0] $value)"
            : "$self->{original_key} ($FILTERS[$config->{filter}][0])" );
        $feature_file->set( $name, key => $new_key );
    }
    else
    {
        # put original key back if changed
        $feature_file->set( $name, key => $self->{original_key} )
          if ( $self->{original_key} ne $key );

        # set filtering off
        $feature_file->set( $name, filter => undef );
    }
}

sub config_defaults
{
    my $self = shift;
    return {
        filter_on    => 'no',
        filter       => 0,
        filter_value => 150
    };
}

sub reconfigure
{
    my $self           = shift;
    my $current_config = $self->configuration;

    my $objtype = $self->objtype();

    foreach my $p ( param() )
    {
        my ($c) = ( $p =~ /$objtype\.(\S+)/ ) or next;
        $current_config->{$c} = param($p);
    }
}

sub configure_form
{
    my $self           = shift;
    my $current_config = $self->configuration;
    my $objtype        = $self->objtype();
    my @choices        = TR(
        { -class => 'searchtitle' },
        th(
            { -align => 'RIGHT', -width => '25%' },
            'Filter on',
            td(
                radio_group(
                    -name     => "$objtype.filter_on",
                    -values   => [qw(yes no)],
                    -default  => $current_config->{'filter_on'},
                    -override => 1
                )
            )
        )
    );
    push @choices,
      TR(
        { -class => 'searchtitle' },
        th(
            { -align => 'RIGHT', -width => '25%' },
            'Filter',
            td(
                popup_menu(
                    -name    => "$objtype.filter",
                    -values  => [ 0 .. $#FILTERS ],
                    -labels  => \%LABELS,
                    -default => $current_config->{'filter'}
                ),
                textfield(
                    -name    => "$objtype.filter_value",
                    -default => $current_config->{filter_value}
                )
            )
        )
      );

    my $html = table(@choices);
    $html;
}

sub objtype
{
    ( split ( /::/, ref(shift) ) )[-1];
}

1;
