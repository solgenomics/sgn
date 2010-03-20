package Bio::Graphics::Browser2::Plugin::SinWave;
# $Id: SinWave.pm,v 1.2 2008-12-02 23:56:53 lstein Exp $
# test plugin
use strict;
use Bio::Graphics::Browser2::Plugin;
use Bio::Graphics::Feature;
use CGI qw(:standard *table);

use vars '$VERSION','@ISA';
$VERSION = '0.1';
use constant RADIANS_PER_CYCLE  => 2*3.14159265; # pi
use constant BINS_PER_SEGMENT   => 1000;         # number of data points

@ISA = qw(Bio::Graphics::Browser2::Plugin);

sub name { "Sine Wave" }

sub description {
  p("The sine wave plugin generates a sine wave ",
    "on the current view.").
  p("It was written to illustrate how to create quantitative features for the xyplot.");
}

sub type { 'annotator' }

sub init { }

sub config_defaults {
  my $self = shift;
  return { cycles   => 10,
  };
}

sub reconfigure {
  my $self = shift;
  my $current_config = $self->configuration;
  my $defaults       = $self->config_defaults;

  my $new_cycles = $self->config_param('cycles');
    if ($new_cycles >= 1 and $new_cycles < 100) { # sanity check
	$current_config->{cycles} = $new_cycles;
    } else { # doesn't pass check, so go to defaults
	$current_config->{cycles} = $defaults->{cycles};
    }
}



sub configure_form {
  my $self = shift;
  my $current_config = $self->configuration;
  return
    "Cycles per window: ".textfield(-name=>$self->config_name('cycles'),
				    -default=>$current_config->{cycles}
    );
}

sub annotate {
  my $self    = shift;
  my $segment = shift;

  my $chr       = $segment->seq_id;
  my $segstart  = $segment->start;
  my $length    = $segment->length;

  my $cycles          = $self->configuration->{cycles};
  my $radians_per_bin = RADIANS_PER_CYCLE * $cycles/BINS_PER_SEGMENT;
  my $bases_per_bin   = $length/BINS_PER_SEGMENT;

  my $feature_list   = Bio::Graphics::FeatureFile->new;
  $feature_list->add_type('wave' => {glyph     => 'xyplot',
				     key       => "$cycles cycles",
				     bgcolor   => 'blue',
				     height    => 50,
				     min_score => -1.0,
				     max_score => +1.0,
			  });

  my $curve = Bio::Graphics::Feature->new();

  for (0..BINS_PER_SEGMENT-1) {
      my $start = $segstart + int($_ * $bases_per_bin);
      my $end   = int($start + $bases_per_bin);
      my $score = sin($_ * $radians_per_bin);
      
      $curve->add_SeqFeature(Bio::Graphics::Feature->new(-seq_id=>$chr,
							 -start => $start,
							 -end   => $end,
							 -score => $score));
    }
  $feature_list->add_feature($curve,'wave');
  return $feature_list;
}

1;

