package Bio::Graphics::Browser2::Plugin::SourceTrackFinder;
# $Id: SourceTrackFinder.pm,v 1.2 2009-05-20 21:29:40 lstein Exp $
use strict;
use CGI qw(:standard *table);
use base 'Bio::Graphics::Browser2::Plugin';
use Bio::Graphics::Browser2::Util 'shellwords';
our $VERSION = '0.25';

sub name { "Source Track Finder" }

sub description {
    return p("The source track finder filters the track table by the data and config source the track.");
}

sub type { 'trackfilter' }

sub init { }

sub config_defaults {
  my $self   = shift;

  # this line gets all the options defined in the "[SourceTrackFinder:plugin]" stanza
  my %fields = map {$_=>undef} $self->get_fields;

  return \%fields;
}


# this method gets all the options defined in the "[SourceTrackFinder:plugin]" stanza
sub get_fields {
    my $self = shift;
    return $self->browser_config->plugin_setting;
}

sub reconfigure {
  my $self = shift;
  my $current_config = $self->configuration;

  for my $f ($self->get_fields) {
      $current_config->{lc $f} = $self->config_param($f);
  }
}

sub configure_form {
  my $self = shift;
  my $current_config = $self->configuration;
  my $source         = $self->browser_config;

  my @fields         = $self->get_fields;
  my @elements;

  for my $f (@fields) {
      my @options = ('',shellwords($source->plugin_setting($f)));
      push @elements,b(ucfirst $f.':');
      push @elements,
        popup_menu(
	    -id       => "plugin_$f",
	    -class    => "SourceTrackFinderPopup",
	    -name     => $self->config_name($f),
	    -values   => \@options,
	    -default  => $current_config->{$f},
	    -override => 1,
	    -onChange => 'doPluginUpdate()',
	    )
  }
  push @elements,
      button(-value     => 'Clear',
	     -onClick   => q($$('.SourceTrackFinderPopup').each(function(m) {m.selectedIndex=0}); doPluginUpdate();)
	  );
  return join '&nbsp;',@elements;


}

sub filter_tracks {
  my $self          = shift;
  my $track_labels  = shift;
  my $source        = shift;

  my $config  = $self->configuration;
  my @fields  = $self->get_fields;
  my %filters = map {lc $_ => $config->{lc $_}} @fields;
  
  my @result;

 LABEL:
  for my $l (@$track_labels) {
      do {push @result,$l; next LABEL} if $l =~ /^(plugin|file|http|das)/;

      for my $f (keys %filters) {
	  my %values = map {lc $_=>1} shellwords $source->fallback_setting($l=>$f);
	  next LABEL if length $filters{$f} && !$values{lc $filters{$f}};
      }

      push @result,$l;
  }
  return @result;
}

1;

__END__

=head1 NAME

Bio::Graphics::Browser2::Plugin::SourceTrackFinder - Limit list of tracks to those that contain arbitrary fields

=head1 SYNOPSIS

In the appropriate gbrowse configuration file:

 plugin = SourceTrackFinder

 [SourceTrackFinder:plugin]
 tissue source = brain pancreas kidney
 gender        = male female

 [track1]
 (usual config options)
 tissue source = brain
 gender        = male

 [track2]
 (usual config options)
 tissue source = pancreas
 gender        = female

=head1 DESCRIPTION

This plugin activates a panel above the tracks table that allows the
user to filter the tracks according to combinations of fields that you
define. The fields are defined in the [SourceTrackFinder:plugin]
stanza of the configuration file and consist of one or more field
names followed by their allowable values, separated by spaces using
the usual GBrowse config rules. For filtering to work, each track must
also have a similarly-named set of fields, each with one or more
values.

GBrowse will prompt the user to select field values using a series of
popup menus located above the tracks table. When the user changes the
popups, the tracks table will be filtered to show only the tracks that
match the selected field values. The user can press the "clear" button
to turn off filtering.

Note that this only affects the display of track names. Tracks that
were previously turned on will stay on, but their entries will be
invisible in the tracks table. The user can still turn them off by
clicking on the individual track's configure or (-) buttons.

=head1 OPTIONS

None

=head1 BUGS

None known yet.

=head1 SEE ALSO

L<Bio::Graphics::Browser2::Plugin>

=head1 AUTHOR

Lincoln Stein E<lt>lincoln.stein@gmail.comE<gt>.

Copyright (c) 2009 Ontario Institute for Cancer Research

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
