# $Id: Spectrogram.pm,v 1.9 2009-01-08 16:42:29 lstein Exp $
# bioperl module for Bio::Graphics::Browser2::Plugin::Spectrogram
# cared for by Sheldon McKay mckays@cshl.edu
# Copyright (c) 2006 Cold Spring Harbor Laboratory.

=head1 NAME

Bio::Graphics::Browser2::Plugin::Spectrogram

=head1 SYNOPSIS

This module is not used directly.  It is an 'annotator'
plugin for tehe Generic Genome Browser.

=head1 DESCRIPTION

The Spectrogram plugin builds up a spectrogram for
digitized DNA sequence using the short-time fourier
transform (STFT) method, adapted from classical digital signal
processing methods.  A sliding window of variable size and overlap
is used to calculate each "column" of the spectrogram, where the column
width is equal to the step, or overlap between windows.

For each window, we: 

1) digitize the DNA by creating four binary indicator
sequences:

    G A T C C T C T G A T T C C A A
  G 1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0
  A 0 1 0 0 0 0 0 0 0 1 0 0 0 0 1 1
  T 0 0 1 0 0 1 0 1 0 0 1 1 0 0 0 0
  C 0 0 0 1 1 0 1 0 0 0 0 0 1 1 0 0

2) take the discrete fourier transform (DFT) for each of the 
four indicator sequences and square the values to get 
the magnitude.  

3) create a Bio::Graphics::Feature object that contains
the spectrogram data as attributes.  The features are passed
back to gbrowse as parts of a Bio::Graphics::Featurefile object.

The calculations for the real DFT are handled by
the xs module Math::FFT.  The actual algorithm
used is the fast fourier transfrom (FFT), which is much
faster than the original DFT algorithm but is limited in that
only base2 numbers (128, 256, 512, etc) can be used for window
sizes.  This is necessary to make the spectrogram calculation
fast enough for real-time use.  It should be noted, however,
that calculating spectrograms dynamically is computationally 
intensive and will increase latency when the spectrogram
track is turned on in gbrowse.

The graphical rendering of the spectrogram depends on the
glyph module Bio::Graphics::Glyph::spectrogram.  

The plugin is discussed in more detail in the plugin's help
links.

=head1 FEEDBACK

See the GMOD website for information on bug submission http://www.gmod.org.

=head1 AUTHOR - Sheldon McKay

Email E<lt>mckays@cshl.eduE<gt>

=cut
;

package Bio::Graphics::Browser2::Plugin::Spectrogram;
use strict;
use Bio::Graphics::Browser2::Plugin;
use Bio::Graphics::Browser2::Util qw/error/;
use CGI ':standard';
use CGI::Carp 'fatalsToBrowser';
use CGI::Toggle;
use GD;

use Math::FFT;
use Statistics::Descriptive;
use List::Util qw/shuffle max/;

use Data::Dumper;

use vars qw/@ISA $CONFIG $VERSION/;

use constant IMAGE_DIR   => '/gbrowse2/images/help';
use constant BUTTONS_DIR => '/gbrowse2/images/buttons'; 

$VERSION = 1.1;
@ISA = qw/ Bio::Graphics::Browser2::Plugin /;

sub init {
  my $self = shift;
  $CONFIG = $self->browser_config;
}

sub name { 
  'DNA spectrogram';
}

sub type {
  'annotator';
}

sub verb {
 'Draw';
}

sub mime_type {
  'text/html';
}

sub config_defaults {
  { win       => 512,
    inc       => 256,
    binsize   => 1,
    y_unit    => 1,
    quantile  => 99.99, 
    filter_01 => 1,
    min       => 2,
    max       => 4,
    type      => 'period'}
}

sub reconfigure {
  my $self = shift;
  my $conf = $self->configuration;
  $conf->{win}  = $self->config_param('win');
  $conf->{inc}  = $self->config_param('inc');
  $conf->{min}  = $self->config_param('min') || 0;
  $conf->{max}  = $self->config_param('max') || $conf->{win} - 1;
  $conf->{type} = $self->config_param('measure');
  $conf->{filter_01} = $self->config_param('filter_01');
  $conf->{quantile}  = $self->config_param('quantile') || 99.99;
  $conf->{y_unit}    = $self->config_param('y_unit')   || 1;
  $self->configuration($conf);
}

sub annotate {
  my $self    = shift;
  my $segment = shift or die "No segment";
  my $conf    = $self->configuration;

  my $win     = $conf->{win};
  my $inc     = $conf->{inc};
  my $ltype   = $conf->{ltype};

  # sanity check for window size
  if ($inc >= $win) {
    error("Spectrogram.pm error: window size must be greater than the overlap");
    return;
  }
  
  # and for maximum period or frequency
  if ($conf->{max} && $conf->{max} > $win) {
    error("maximum $conf->{type} can not exceed ".
	     " the window size: resetting to $win.");
    $conf->{max} = $win;
  }

  my $slide_offset = 0;
  my $db = $segment->factory;
  unless ($segment->start == 1) {
    my $original_start = $segment->start;
    ($segment) = $db->segment( $segment->ref, ($segment->start - $win), ($segment->end + $win) );
    $slide_offset = $original_start - $segment->start - $inc;
  }
  else {
    ($segment) = $db->segment( $segment->ref, $segment->start, ($segment->end + $win) );
  }

  my $seq_obj = $segment->seq;
  my $seq;
  if ($seq_obj && ref $seq_obj) {
    $seq = lc eval{$seq_obj->seq};
  }
  elsif ($seq_obj) {
    $seq = lc $seq_obj;
  }
  $seq ||  die "No sequence found for $segment $@";

  my $offset  = $segment->start;
  my $end     = $segment->length;
 
  my (@g,@a,@t,@c,@offsets,@meta_array,@coords);

  my ($min_f,$max_f);
  if ( $conf->{min} || $conf->{max} ) {
    my $max  = $conf->{max} || $win;
    my $min  = $conf->{min} || 0;
    my $type = $conf->{type}; 

    if ($type eq 'period') {
      $min_f = $min && $max && $max > 1 ? int(2*$win/($max)) - 1 : $win - 1;
      $max_f = $min ? int(2*$win/($min)) - 1  : $win - 1;
    }
    else {
     unless (int $min == $min) {
       error("minimum frequency value should be an integer between",
		"0 and ".($win-2));
       return;
     }
     unless (int $max == $max) {
       error("maximum frequency value should be an integer between",
		"1 and ".($win-1));
       return;
     }
      $min_f = $min;
      $max_f = $max || $win-1;
    }
  }
  else {
    $min_f = 0;
    $max_f = $win-1;
  }

  $min_f-- unless $min_f == 0;
  $max_f++ unless $max_f == $win-1;

  my $key = join('; ',"window size $win", "overlap $inc", 
		 "saturation $conf->{quantile}th percentile");
  if ($conf->{min}) {
    $key .= "; $conf->{type} range $conf->{min}-$conf->{max}";
  }
  if ($conf->{filter_01}) {
    $key .="; 0-1 Hz filter ON";
  }

  my $feature_list = $self->new_feature_list;
  my $link = sub { shift->url || 0 };
  $feature_list->add_type( spectrogram => { glyph  => 'spectrogram',
					    bump   => 0, # must be zero
					    height => $conf->{y_unit} * ($max_f - $min_f + 1),
					    key    => $key,
					    win    => $win,
					    link   => $link } );

  my $start = 0;

  my $skipped;

  until ( $start > ( $end - $win ) ) {
    my $sub_seq = substr $seq, $start, $win;

    # runs of N's will screw things up.
    $sub_seq =~ s/[^gatcGATC]/N/g;
    my $has_Ns = $sub_seq =~ tr/N/a/;

    unless ( $has_Ns > $win/10 ) {
      # Digitize the DNA
      my ($g,$a,$t,$c) = make_numeric($sub_seq);

      # take the magnitude of the DFT
      dft(\$_) for ($g,$a,$t,$c);

      # get rid of DC 'component'
      if ($conf->{filter_01} ) {
	for ($g,$a,$t,$c) {
	  $_->[0] = 0;
	  $_->[1] = 0;
	}
      }
      
      push @g, [@{$g}[$min_f..$max_f]];
      push @a, [@{$a}[$min_f..$max_f]];
      push @t, [@{$t}[$min_f..$max_f]];
      push @c, [@{$c}[$min_f..$max_f]];
      push @coords, [$start + $offset + 1, $start + $offset + $inc];
    }
    else {
      $skipped++;
    }

    $start += $inc;
  }


  # warn if there are a lot of 'N's
  if ($skipped) {
    error("Spectrogram: blank areas correspond to ambiguous sequence regions  with > 10% 'N's");
  }


  # max out the intensity range at the nth
  # percentile to avoid saturation of color intensity 
  my $stat = Statistics::Descriptive::Full->new;
  my @data = grep {defined $_} map {@$_} @g,@a,@t,@c;

  $stat->add_data(@data);
  my $max = $stat->percentile($conf->{quantile});
  my @labels = $min_f .. $max_f;
  @labels = map {$_ ? 2*$win/$_ : $win} @labels if $conf->{type} eq 'period';
  my $first = 1;
  for my $coords (@coords) {
    my ($start, $end) = @$coords;
    
    # make a link for zooming in
    (my $url = self_url) =~ s/\?.+//;;
    my $pad = int $segment->length/20;
    my $z_start = $start - $pad;
    my $z_stop  = $end   + $pad;
    my $name = $segment->ref .":$z_start..$z_stop";
    $url .= "?name=$name";
    
    my $G = shift @g;
    my $A = shift @a;
    my $T = shift @t;
    my $C = shift @c;
    
    my $atts = { g   => $G,
		 a   => $A,
		 t   => $T,
		 c   => $C,
		 max => $max };
    
    # y-axis labels for first column
    if ($first) {
      $atts->{labels} = [$conf->{type},@labels];
      $first = 0;
    }
    
    # create a column for the spectrogram.  Offset the seuquence
    # coordinates so that features in the specrogam are directly below
    # the corresponding DNA 
    my $sf = Bio::Graphics::Feature->new( -type   => 'spectrogram',
					  -source => 'calculated',
					  -start  => $start + $slide_offset,
					  -end    => $end   + $slide_offset,
					  -ref    => $segment->ref,
					  -url    => $url,
					  -attributes    => $atts );
    
    $feature_list->add_feature($sf);
    
  }
  
  return $feature_list;
}

sub configure_form {
  my $self    = shift;
  my $conf    = $self->configuration;
  my $segment = ($self->segments)[0];

  my $state       = { on => 0, override => 1 };
  my $description = p(
      $self->_help_message($state,
			   span({-class=>'searchtitle'},
				'What is a DNA spectrogram?'),
			   $self->long_description)
      );

  my $form = $description;
 
  my $msg = $self->_help_message( $state, 'Sliding window size', split "NL", <<'END;');
Window size is the number of bases to include in each calculation.NL
Overlap is the increment by which the window slides (amount of overlap).NL
<font color=red>Note: </font>larger window sizes and/or smaller
overlaps increase computation time.
END;

  $form .= h4({-class => 'searchtitle'}, $msg) .
      p( 'Window: size ',
	 popup_menu( -name  => $self->config_name('win'),
		     -values => [8,16,32,64,128,256,512,1024,2048,4096,8192],
		     -default => $conf->{win} ),
	 ' bp' . br. br . ' overlap ',
	 textfield( -name  => $self->config_name('inc'),
		    -value => $conf->{inc},
		    -size  => 4 ),
	 'bp' );
  
  $msg = $self->_help_message( $state, 'Display options', split "NL", <<'END;');
The allowed range of periods or frequencies controls spectrogram height
and calculation time.NL 
period = size (bp) of structure or repeat unit, calculated as 
2*(window size)/frequency.NL
row height = the height (pixels) of each frequency row in the spectrogram.
END;
  
  $form .= br .  h4({-class => 'searchtitle'}, $msg) .
      p( 'Restrict ',
	 popup_menu( -name   => $self->config_name('measure'),
		     -values => [qw/period frequency/],
		     -default => $conf->{type} ),
	 ' to between ',
	 textfield( -name  => $self->config_name('min'),
		    -value => $conf->{min},
		    -size  => 4 ),
	 ' and ',
	 textfield( -name  => $self->config_name('max'),
		    -value => $conf->{max},
		    -size  => 4 ),
	 br . br . 'Row height',
         textfield( -name => $self->config_name('y_unit'),
                    -value => $conf->{y_unit},
                    -size  => 2 ),
         ' px ' );	 


  $msg = $self->_help_message( $state, 'Image saturation', split "NL", <<'END;');
Lowering the saturation value will reduce the dominance of very bright
colors on the spectrogram by setting an arbitrary maximum value
(expressed as a percentile rank).NL
Setting a lower saturation will reduce the effects of very high 
amplitude signals elsewhere in the spectrogram and help to 
emphasize less intense features.NL
The higher the saturation value is set, the darker the "background"
of the spectrogram.NL
There is a very large amplitude signal at frequency 0 Hz
(the very top of the spectrogram), with some bleed over to 1 Hz.NL
Filtering out these frequencies will help make the fainter
spots more visible by decreasing the overall range of signal
magnitudes.
END;

  $form .=  br . h4({-class => 'searchtitle'}, $msg) .
     p( 'Saturate color intensity at the ',
        textfield( -name   => $self->config_name('quantile'),
	 	  -value  => $conf->{quantile},
		   -size   => 5 ),
       'th percentile' );

  my @checked = (checked => 'checked') if $conf->{filter_01};
  $form .=    p( checkbox( -name => $self->config_name('filter_01'),
			   @checked,
			   -label => 'Filter out 0-1 Hz' ));

  return $form;
}

sub _help_message {
  my $self    = shift;
  my $state   = shift;
  my $section = shift;
  my @items = map li($_).br, @_;
  
  my $details = table( {-width => 800},
		      Tr( td( {-class => 'databody'}, ul(@items))));
  
  $self->toggle( $state, $section, $details );
}
  
sub make_numeric {
  my $seq = lc shift;
  my @seq = split q{}, $seq;

  my @G = map { $_ eq 'g' ? 1 : 0 } @seq;
  my @A = map { $_ eq 'a' ? 1 : 0 } @seq;
  my @T = map { $_ eq 't' ? 1 : 0 } @seq;
  my @C = map { $_ eq 'c' ? 1 : 0 } @seq;

  return (\@G,\@A,\@T,\@C);
}

sub dft {
#  my $self = shift;
#  my $conf = $self->configuration;
#  my $remove_DC = $conf->{remove_DC};
  my $array = shift;
  my $fft   = Math::FFT->new($$array);

  # this is a call to the 'real' DFT (no imaginary numbers)
  # algorithm, which is actually implented via the FFT 
  # algorithm
  my $dft = $fft->rdft;
  $dft = magnitude(@$dft);
  $$array = $dft;
}

sub magnitude {
  $_ = $_**2 for @_;
  return \@_;
}

sub _process_msg {
  my $msg = shift;
  $msg =~ s/\\n|\n\n/BREAK/gm;
  $msg =~ s/\n/ /gm;
  $msg =~ s/BREAK/\\n/g;
  $msg;
}

sub description {
    my $self = shift;
    return p(<<END);
The DNA Spectrogram plugin builds a spectrogram for digitized DNA sequence using
the short-time fourier transform (STFT) method. The plugin was written by 
Sheldon McKay (mckays\@cshl.edu).
END
}

sub long_description {
  my $image_dir = IMAGE_DIR;
  return table( {-width => 800}, Tr( td({-class => 'databody'},
	   p(<<END) . 
The Spectrogram plugin builds up a spectrogram for digitized DNA sequence using the short-time fourier transform (STFT) method,
adapted from classical digital signal processing.
Spectrogram analysis of DNA can help uncover non-random structures in DNA sequences, some examples of which are coding DNA
and repeats  (For example, see <a href="http://www.hindawi.com/GetPDF.aspx?doi=10.1155/S1110865704310048"> this article</a>).
</p>
<h3>Coding DNA examples</h3>
<p>
This is an example of a spectrogram of a genic region of yeast chromosome I.  Note the linear feature at period 3 (codon size).
<img border=1 src="$image_dir/yeast_I_genes_spec.png">
</p>
<br>
<p>
This is an example of a portion of <i>C. elegans</i> predicted gene Y38C1AB.4.  Note the differences between exons and introns.
<img border=1 src="$image_dir/worm_exons_spec.png"> 
</p>

<h3>Repeats</h3>
<p>
Repeats cause a ladder-like series of horizontal lines.  Short repeats, such as telomeric repeats, are most visible with small
window sizes.  Longer repeats, such as minisatellites, are best seen with larger window sizes.
</p>
<p>
This is an example of telomeric repeats on <i>C. elegans</i> chromosome I.
<img border=1 src="$image_dir/worm_telomeric_spec.png"> 
</p>
END

	   p(<<END) .
<h3>How is the DNA spectrogram calculated?</h3>
<p>
A sliding window of variable size and overlap is used to calculate the spectrogram, which is displayed graphically as a track in the
genome browser.  Each window is a subsegment of DNA and corresponds to a 'column' in the graphical display of the spectrogram.  The 
window slides along the sequence, from left to right, at a set increment, which corresponds to the column width.
</p>
<p>
The spectrogram refers collectively to all of the rows and columns seen in the graphical display.
</p>
<p>
The spectrogram has <i>n</i> rows, where <i>n</i> is the number of bases in the window. Each row corresponds
to a discrete 'frequency' from 0 -> <i>n</i>-1.
</p>
<p>
An arguably more intuitive way to relate this to DNA sequence to calculate the 'period' (<i>n</i>/frequency*2).
If we see a feature in the spectrogram at period <i>x</i>, there is a non-random structure
with a periodicity of <i>x</i> nucleotides.  The chief example of this would be coding DNA at period 3.  
</p>
<br>
The DNA sequence is converted from analog to digital by creating four binary indicator sequences:

<pre>
           G A T C C T C T G A T T C C A A
         G 1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0
         A 0 1 0 0 0 0 0 0 0 1 0 0 0 0 1 1
         T 0 0 1 0 0 1 0 1 0 0 1 1 0 0 0 0
         C 0 0 0 1 1 0 1 0 0 0 0 0 1 1 0 0
</pre>
<br>
<p>
The magnitude of the discrete fourier transform (DFT) is calculated seperately for each of the four indicator sequences.
The algorithm used is the fast fourier transfrom (FFT; via Math::FFT), which is much faster than the original DFT algorithm 
but is limited in that only base2 numbers (128, 256, 512, etc) can be used for window sizes.  This is necessary to make the
spectrogram calculation fast enough for real-time use.
</p>

<p>
For graphical rendering, each transformed sequence is assigned a color (A=blue; T=red; C=green; G=yellow).  The colors for each
base are superimposed on the image.  In a given spot on the spectrogram, the brightness corresponds to the magnitide (signal intensity)
and the color corresponds to the dominant base at that frequency/period.  If no single base predominates, an intermediate color 
is calculated based on the relative magnitudes.
</p>
<p>
The spectrogram is visible as a track in the generic genome browser.  Please note that the calculations and graphical rendering are computationally
intensive, so the image will take a while to load, especially with larger sequence regions and/or small increments for the sliding
window.
</p>
<p>
After you have launched this plugin, the spectrogram will continue to be calculated in the main gbrowse display until you turn off the 'Spectrogram' track. 
</p>
END

    p("The plugin was written by Sheldon McKay (mckays\@cshl.edu)"))));

}

sub toggle {
    my $self = shift;
    my ($state,$section_head,@body) = @_;
    my $buttons_dir = $CONFIG->globals->button_url || BUTTONS_DIR;
    $state ||= {};
    $state->{plus_img}  = "$buttons_dir/query.png";
    $state->{minus_img} = "$buttons_dir/minus12.png";

    my ($label) = $self->language->tr($section_head) || $section_head;
    return toggle_section($state,$label,b($label),@body);
}

1;

