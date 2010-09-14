package Bio::Graphics::Browser2::Plugin::FastaDumper;
# $Id: FastaDumper.pm,v 1.11 2005-12-09 22:19:09 mwz444 Exp $
# test plugin
use strict;
use Bio::Graphics::Browser2::Plugin;
use Bio::Graphics::Browser2::Markup;

use CGI qw(:standard );

use constant DEBUG => 0;

use vars qw($VERSION @ISA @MARKUPS %LABELS 
	    $BACKGROUNDUPPER %COLORNAMES $PANEL);

my @COLORS = qw(red brown magenta maroon pink orange
		yellow tan teal cyan lime green blue
		lightgrey grey darkgrey
	       );

BEGIN {
    $BACKGROUNDUPPER = 'YELLOW';
    @MARKUPS = ( undef,  # none
		 "UPPERCASE",  # for uppercase
		 'Font-weight: bold',
		 'Text-decoration: underline',
		 'Font-style: italic',
		 'FGCOLOR %s',
		 'BGCOLOR %s',
	       );

    %LABELS =  ( 0 => 'None',
		 1 => 'CAPS',
		 2 => '<b>Bold</b>',
		 3 => '<u>Underline</u>',
		 4 => '<i>Italics</i>',
		 5 => '<span style="Color: red">Font</span>',
		 6 => '<span style="Background-color: red">Bkg</span>',
	       );
}

$VERSION = '0.20';

@ISA = qw(Bio::Graphics::Browser2::Plugin);

sub name { "Decorated FASTA File" }
sub description {
  p("The marked-up FASTA dumper plugin dumps out the currently displayed genomic segment",
    "in FASTA format.").
  p("This plugin was written by Lincoln Stein and Jason Stajich.");
}

sub dump {
    my $self = shift;
    my $segment = shift;

    unless ($segment) {
      my $mime_type = $self->mime_type;
      print start_html($self->name) if $mime_type =~ /html/;
      print "No sequence specified.\n";
      print end_html if $mime_type =~ /html/;
      exit 0;
    }

    my $config  = $self->configuration;
    my $dna = lc $segment->dna;
    my $browser = $self->browser_config();
    warn("====== beginning dump =====\n") if DEBUG;
    warn "length of dna = ",length($dna) if DEBUG;

    my %types;

    my $flip   = defined $config->{flip} ? $config->{flip}
                                         : $self->page_settings->{flip};
    if ($flip) {
      $dna = reverse $dna;
      $dna =~ tr/gatcGATC/ctagCTAG/;
    }
    my $markup = Bio::Graphics::Browser2::Markup->new;

    while( my ($type,$val) = each %{$config} ) {


      next unless $val;
      next if $type =~ /\.(f|b)gcolor$/i;
      next if $type =~ /format$/;
      next if $type =~ /orientation$/;

      warn "configuring $type => $val\n" if DEBUG;

      my $style = $MARKUPS[$val] || '';
      if ($style =~ /^(F|B)GCOLOR/) {
	$style = sprintf($style,$config->{"$type.\L$1\Egcolor"});
      }
      next if $config->{format} eq 'text' && $style ne 'UPPERCASE';

      (my $feature_type = $type) =~ s/^[^.]+\.//;
      # there may be several feature types defined for each track
      my @types = $browser->label2type($feature_type) or next;
      for my $t (@types) {
	$markup->add_style($t => $style);
	warn "adding style $t => $style\n" if DEBUG
      }

      foreach (@types) { $types{$_}++ };
    }

    my @regions_to_markup = $self->make_markup($segment,[keys %types],$markup,$flip) if %types;

    # add a newline every 60 positions
    $markup->add_style('newline',"\n");
    push @regions_to_markup,map {['newline',60*$_]} (1..length($dna)/60);
    $markup->markup(\$dna,\@regions_to_markup);

    my $label = "$segment";
    $label .= " (reverse complemented)" if $flip;

    # HTML formatting
    if ($config->{format} eq 'html') {
	
      print start_html($segment); #,h1($label);
      print pre(">$label\n$dna");
      print end_html;
    }

    # text/plain formatting
    else {
	print ">$label\n";
	print $dna;
    }
    warn("====== end of dump =====\n") if DEBUG;
}

sub mime_type {
  my $self = shift;
  my $config = $self->configuration;
  return $config->{format} eq 'html' ? 'text/html' : 'text/plain';
}

sub config_defaults {
    my $self = shift;
    return { format           => 'html' };
}

sub reconfigure {
  my $self = shift;
  my $current_config = $self->configuration;
  %$current_config = ();

  foreach my $param ( $self->config_param() ) {
    warn "param = $param\n" if DEBUG;
    next if $param =~/\.(f|b)gcolor$/;
    my $value = $self->config_param($param) or next;
    $current_config->{$param} = $value;
    warn "current_config($param) = $current_config->{$param}\n" if DEBUG;
  }
  # handle colors specially
  for my $type (keys %$current_config) {
    next unless $current_config->{$type} =~ /^\d+$/;
    next unless $MARKUPS[$current_config->{$type}] =~ /^(F|B)GCOLOR/;
    my $color_key = lc("$1gcolor");
    $current_config->{"$type.$color_key"} = $self->config_param("$type.$color_key");
    warn "current_config($type.$color_key) = ",$current_config->{"$type.$color_key"},"\n" if DEBUG;
  }
}

sub configure_form {
    my $self = shift;
    my $current_config = $self->configuration;
    my @choices = TR({-class => 'searchtitle'},
		     th({-align=>'RIGHT',-width=>'25%'},"Output",
			td(radio_group(-name     => $self->config_name('format'),
				       -values   => [qw(text html)],
				       -default  => $current_config->{'format'},
				       -override => 1))
		       )
		    );
  push @choices,TR({-class=>'searchtitle'},
		   th({-align=>'RIGHT',-width=>'25%'},"Orientation",
		      td(checkbox(-name    => $self->config_name('flip'),
				  -label   => 'Flip',
				  -checked => $self->page_settings->{flip},
				  -override => 1))));

    my $browser = $self->browser_config();
    # this to be fixed as more general
    my @labels;
    foreach ( $browser->labels() ) {
	push @labels, $_ unless ! defined $browser->setting($_,'feature');
    }

    autoEscape(0);
    my %selected = map {$_=>1} ($self->selected_tracks);

    foreach my $featuretype ( @labels ) {
        next if ! $selected{$featuretype};
	my $realtext = $browser->setting($featuretype,'key') || $featuretype;
	push @choices, TR({-class => 'searchtitle'}, 
			  th({-align=>'RIGHT',-width=>'25%'}, $realtext,
			     td(join ('&nbsp;',
				      radio_group(-name     => $self->config_name($featuretype),
						  -values   => [ (sort keys %LABELS)[0..4] ],
						  -labels   => \%LABELS,
						  -default  => $current_config->{$featuretype} || 0),
				      radio_group(-name     => $self->config_name($featuretype),
						  -values   => 5,
						  -labels   => \%LABELS,
						  -default  => $current_config->{$featuretype} || 0),
				      popup_menu(-name      => $self->config_name("$featuretype.fgcolor"),
						 -values    => \@COLORS,
						 -default    => $current_config->{"$featuretype.fgcolor"}),
				      radio_group(-name     => $self->config_name($featuretype),
						  -values   => 6,
						  -labels   => \%LABELS,
						  -default  => $current_config->{$featuretype} || 0),
				      popup_menu(-name      => $self->config_name("$featuretype.bgcolor"),
						 -values    => \@COLORS,
						 -default    => $current_config->{"$featuretype.bgcolor"}
						),
				     ))));
    }
    autoEscape(1);
    my $html= table(@choices);
    $html;
}


sub make_markup {
  my $self = shift;
  my ($segment,$types,$markup,$flip) = @_;

  my @regions_to_markup;

  warn("segment length is ".$segment->length()."\n") if DEBUG;
  my $iterator = $segment->get_seq_stream(-types=>$types,
					  -automerge=>1) or return;
  my $segment_start = $segment->start;
  my $segment_end   = $segment->end;
  my $segment_length = $segment->length;

  while (my $markupregion = $iterator->next_seq) {

    warn "got feature $markupregion\n" if DEBUG;

    # handle both sub seqfeatures and split locations...
    # somebody rescue me from this insanity!
    my @parts = eval { $markupregion->sub_SeqFeature } ;
    @parts = eval { my $id   = $markupregion->location->seq_id;
		    my @subs = $markupregion->location->sub_Location;
		    grep {$id eq $_->seq_id} @subs } unless @parts;
    @parts = ($markupregion) unless @parts;

    for my $p (@parts) {
      my $start = $p->start - $segment_start;
      my $end   = $start + $p->length;

      ($start,$end) = map {$segment_length-$_} ($end,$start) if $flip;

      warn("$p ". $p->location->to_FTstring() . " type is ".$p->primary_tag) if DEBUG;
      $start = 0                   if $start < 0;  # this can happen
      $end   = $segment->length    if $end > $segment->length;
      warn "annotating $p $start..$end" if DEBUG;

      my $style_symbol;
      foreach ($p->type,$p->method,$markupregion->type,$markupregion->method) {
	$style_symbol ||= $markup->valid_symbol($_) ? $_ : undef;
      }
      warn "style symbol for $p is $style_symbol, and style is ",$markup->style($style_symbol),"\n" if DEBUG;
      next unless $style_symbol;

      warn "[$style_symbol,$start,$end]\n" if DEBUG;
      push @regions_to_markup,[$style_symbol,$start,$end];
    }
  }
  @regions_to_markup;
}

1;
