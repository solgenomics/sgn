package Bio::Graphics::Browser2::Plugin::SimpleTrackFinder;
# $Id: SimpleTrackFinder.pm,v 1.2 2009-05-20 21:29:40 lstein Exp $
use strict;
use CGI qw(:standard *table);
use base 'Bio::Graphics::Browser2::Plugin';
our $VERSION = '0.25';

sub name { "Simple Track Finder" }

sub description {
    return p("The simple track finder filters the track table by the name of the track.");
}

sub type { 'trackfilter' }

sub init { }

sub config_defaults {
  my $self = shift;
  return {
      track_name => undef,
  };
}

sub reconfigure {
  my $self = shift;
  my $current_config = $self->configuration;
  $current_config->{track_name} = $self->config_param('track_name');
}

sub configure_form {
  my $self = shift;
  my $current_config = $self->configuration;
  my $name           = $current_config->{track_name};
  return 
      b('Partial or full track name:').
      textfield(-id       => 'track_name_filter',
		-name     => $self->config_name('track_name'),
		-default  => $name,
		-override => 1,
		-onKeyDown=>'if (event.keyCode==13) doPluginUpdate()',
      ).
      button(-value     => 'Clear',
	     -onClick   => "\$('track_name_filter').clear(); doPluginUpdate()");
}

sub filter_tracks {
  my $self    = shift;
  my $tracks  = shift;
  my $source  = shift;

  my $config  = $self->configuration;
  my $name    = $config->{track_name} or return @$tracks;

  my @filtered = grep {
      my $key = $source->setting($_=>'key') || $_;
      $key    =~ m/$name/i
      } @$tracks;
  warn "name = $name, filtered = @filtered";
  return @filtered;
}

1;

__END__

=head1 NAME

Bio::Graphics::Browser2::Plugin::SimpleTrackFinder - Limit list of tracks to those that match a name pattern

=head1 SYNOPSIS

In the appropriate gbrowse configuration file:

 plugin = SimpleTrackFinder

=head1 DESCRIPTION

This plugin activates a panel above the tracks table that allows the
user to filter the tracks according to a name or part of a name. The
user is shown a textfield in which he or she can type a search
string. When the user presses the "Configure" button, the tracks table
is filtered to show only tracks that match the search string.

Note that this only affects the display of track names. Tracks that
were previously turned on will stay on, but their entries will be
invisible in the tracks table. The user can still turn them off by
clicking on the individual track's configure or (-) buttons.

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
