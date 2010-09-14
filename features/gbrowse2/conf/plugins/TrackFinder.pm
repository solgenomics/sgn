package Bio::Graphics::Browser2::Plugin::TrackFinder;
# $Id: SourceTrackFinder.pm,v 1.2 2009-05-20 21:29:40 lstein Exp $
use strict;
use CGI qw(:standard *table);
use base 'Bio::Graphics::Browser2::Plugin';
use Bio::Graphics::Browser2::Util 'shellwords';
our $VERSION = '0.25';

sub name { "Track Finder" }

sub description {
    return p("The track finder filters the track table by the contents of its key, comments and select fields.");
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
  $current_config->{keywords} = $self->config_param('keywords');
}

sub configure_form {
  my $self = shift;
  my $current_config = $self->configuration;
  my $source         = $self->browser_config;
  my $html = '';

  $html .= div({-class=>'searchbody'}, 
	   	   b('Search: ').textfield(-id         => 'plugin_TrackFinderKeywords',
					   -name       => $self->config_name('keywords'),
 					   -onKeyPress => "if (typeof(timeOutID) != 'undefined') clearTimeout(timeOutID);timeOutID= setTimeout('doPluginUpdate()',1000)",
					   -override   => 1,
					   -value      => $current_config->{keywords},
					   -onChange   => 'doPluginUpdate()',
      		),
      	 input({-type => 'checkbox',
      	        -id => 'stickySearch',
      	        -value => 'Stick to top when scrolled'
      	       }
      	 ),
      	 label({-for => 'stickySearch'}, 'Stick to top when scrolled')
	);
  $html .= button(-value   => 'Clear',
		  -onClick => "\$('plugin_TrackFinderKeywords').clear();doPluginUpdate()",
      );

  return $html;
}

sub filter_tracks {
  my $self          = shift;
  my $track_labels  = shift;
  my $source        = shift;

  my $config  = $self->configuration;
  my @keywords = map {quotemeta($_)} shellwords $config->{keywords};

  my @result;
 LABEL:
  for my $l (@$track_labels) {
      do {push @result,$l; next LABEL} if $l =~ /^(plugin|file|http|das)/;

      my $aggregate_text = join ' ',map {$source->code_setting($l=>$_)} qw(key citation keywords select);
      my $labels         = $source->subtrack_scan_list($l);
      $aggregate_text   .= " @$labels" if $labels && @$labels;

      for my $k (@keywords) {
	  next LABEL unless $aggregate_text =~ /$k/i;
      }
      push @result,$l;
  }
  return @result;
}

sub hilite_terms {
    my $self = shift;
  my $config  = $self->configuration;
    my @keywords = map {quotemeta($_)} shellwords $config->{keywords};    
    return @keywords;
}

# Scripts required by the plugin.
sub scripts {
  return qw(scrollfix.js);
}

# Functions to run once the content has been loaded.
sub onLoads {
  my %loads = (track_page => "scrollfix.setup();");
  return %loads;
}

1;

__END__

=head1 NAME

Bio::Graphics::Browser2::Plugin::TrackFinder - Limit list of tracks to those that mention keywords

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
user to filter the tracks according to typed keywords. The fields to
search are hard-coded to "key", "citation" and "keywords". Simply add
a space-delimited "keywords" field to each stanza in order to make it
findable by this plugin.

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
