package Bio::Graphics::Browser::Plugin::TextDumper;

use strict;
use Bio::Graphics::Browser::Plugin;
use CGI qw(param url header p a);

use Data::Dumper;

use vars '$VERSION','@ISA';
$VERSION = '0.10';

@ISA = qw(Bio::Graphics::Browser::Plugin);

sub name { "Tab-delimited Text File" }

sub description {
  p("Tab-delimited dumper plugin: dumps out the currently selected features in tab-delimited text format"),
  p("This plugin was modified by Don Jackson from the GFF Dumper written by Lincoln Stein.");
}

my @attrs = qw(group source method ref start stop score strand notes aliases);

sub dump {
  my $self = shift;
  my $segment       = shift;
  my $page_settings = $self->page_settings;
  my $conf          = $self->browser_config;

  my @labels   = @{$page_settings->{tracks}};
  my @active_tracks = $self->active_tracks(\@labels, $page_settings->{features});

  my @active_attribs = $self->active_attribs();

  print "Sequence features in  ", $segment->ref, ' ', $segment->start,' to ',
  $segment->stop,"\n";  
  print join("\t", @active_attribs), "\n";

  my @feature_types = map {$conf->config->label2type($_)} @active_tracks;
      

  my $iterator = $segment->get_seq_stream(-types=>\@feature_types) or return;
  while (my $f = $iterator->next_seq) {
      foreach my $attr (@active_attribs) {
	  if (defined $f->$attr) {
	      print $f->$attr;
	  }
	  else {
	      print "NA";
	  }
	  print "\t";
      }
      print "\n";
  }
}

sub mime_type {
  my $self = shift;
  my $config = $self->configuration;

  if ( param('textdump_format') eq 'excel') {
      return 'application/vnd.ms-excel';
  }
  else {
      return 'text/plain';
  }
}

sub active_tracks {
    my ($self, $tracklist, $featdata) = @_;


    my @active;

    foreach my $track (@$tracklist) {
	push(@active, $track) if ($featdata->{$track}->{'visible'});
    }
    return @active;
			      
}


sub configure_form {
    my ($self) = shift;
    # select which attributes are shown
    my @choices = TR( th({-colspan => 2, -align => 'CENTER'}, 'Select columns to include from the list below.  Only tracks displayed in the browser will be included.') );

    foreach my $attrib ( $self->attributes ) {
	push(@choices, 
	     TR({-class => 'searchtitle'},
		th({-align => 'RIGHT'}, $attrib),
  		td( checkbox( -name 	=> "show_$attrib",
  			      -override => 1,
			      -label	=> '',
			      -checked 	=> 1,
  			      ),
		    ),
		)
	     );
    }
    # offer choice of output
    push(@choices, TR( th({-align => 'RIGHT'}, 'Return results to:'),
		       td( popup_menu( -name	=> 'textdump_format',
				       -values	=> [qw(browser excel)],
				       -override=> 1, ) ),
		       ) );

    return table({-cellpadding=>2}, @choices);
}

sub attributes {
    return @attrs;
}

sub active_attribs {
    my ($self) = shift;

    my @active_attribs;
    
    foreach my $att ($self->attributes) {
	push(@active_attribs, $att) if ( param("show_$att") );
    }
    # are any attribs active? if not, return all
    if (@active_attribs) {
	return @active_attribs;
    }
    else {
	return $self->attributes;
    }
}

1;
