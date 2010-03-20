package Bio::Graphics::Browser2::Plugin::FilterTest;

# $Id: FilterTest.pm,v 1.3 2009-05-22 21:37:09 lstein Exp $
# Filter plugin to filter features from the ORFs track

use strict;
use vars qw($VERSION @ISA);
use constant DEBUG => 0;

use Bio::Graphics::Browser2::Plugin;
use CGI qw(:standard *pre);

$VERSION = '0.O1';

@ISA = qw(Bio::Graphics::Browser2::Plugin);

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

sub filter {
    my $self  = shift;
    my $track = shift;  # track label
    my $key   = shift;

    my $config  = $self->configuration;
    my $source  = $self->browser_config;

    return unless $source;
    return unless $track eq $self->name;
    return unless $config->{filter_on} eq 'yes';
    my $value        = $config->{filter_value};

    # pass closure to browser object for filtering
    my $filter = eval "sub { $FILTERS[$config->{filter}][1] }";

    warn $@ if $@;
    return $filter,"$key (filter incorrect)" if $@;  # error occurred
    
    my $new_key = $FILTERS[ $config->{filter} ][1] =~ m/\$value/
	          ? "$key ($FILTERS[$config->{filter}][0] $value)"
                  : "$key ($FILTERS[$config->{filter}][0])" ;
    return $filter,$new_key;
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
