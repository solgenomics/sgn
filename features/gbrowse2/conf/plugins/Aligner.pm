package Bio::Graphics::Browser2::Plugin::Aligner;
# $Id: Aligner.pm,v 1.13 2008-09-18 15:27:07 lstein Exp $

use strict;
use Bio::Graphics::Browser2::Plugin;
use CGI qw(table a TR td th p popup_menu radio_group checkbox checkbox_group h1 h2 pre);
use Bio::Graphics::Browser2::Realign 'align_segs';
use Bio::Graphics::Browser2::PadAlignment;
use Bio::Graphics::Browser2::Util 'shellwords';

use constant DEBUG => 0;
use constant DEFAULT_RAGGED_ENDS => (0,10,25,50,100,150,500);

use vars '$VERSION','@ISA';
$VERSION = '0.23';
@ISA = qw(Bio::Graphics::Browser2::Plugin);

use constant TARGET    => 0;
use constant SRC_START => 1;
use constant SRC_END   => 2;
use constant TGT_START => 3;
use constant TGT_END   => 4;

sub name { "Alignments" }

sub description {
  p("This plugin prints out a multiple alignment of the selected features.",
    'It was written by',a({-href=>'mailto:lstein@cshl.org'},'Lincoln Stein.')
   );
}

sub init {
  my $self = shift;
  my $browser_conf = $self->browser_config;
  my @alignable       = shellwords($browser_conf->plugin_setting('alignable_tracks'));
  @alignable = grep {$browser_conf->setting($_=>'draw_target') } $browser_conf->labels
    unless @alignable;
  $self->{alignable} = \@alignable;

  my @upcase          = shellwords($browser_conf->plugin_setting('upcase_tracks'));
  $self->{upcase}     = \@upcase;

  my @ragged          = shellwords($browser_conf->plugin_setting('ragged_ends'));
  @ragged             = DEFAULT_RAGGED_ENDS unless @ragged;
  $self->{ragged}     = \@ragged;

  $self->{upcase_default} = $browser_conf->plugin_setting('upcase_default');
  $self->{align_default}  = $browser_conf->plugin_setting('align_default')
                           ? [shellwords($browser_conf->plugin_setting('align_default'))]
			   : \@alignable;
  $self->{ragged_default} = $browser_conf->plugin_setting('ragged_default');

}

sub config_defaults {
  my $self = shift;
  return { align  => @{$self->{align_default}} ? $self->{align_default} : $self->{alignable},
	   upcase => $self->{upcase}[0]
	 };
}

sub configure_form {
  my $self    = shift;
  my $current = $self->configuration;
  my $browser = $self->browser_config;
  my $html;
  if ($self->{upcase}) {
    my %labels = map {$_ => $browser->setting($_=>'key') || $_} @{$self->{upcase}};
    $html .= TR(
		th('Features to render uppercase:'),
		td(radio_group(-name    => $self->config_name('upcase'),
			       -values  => ['none',@{$self->{upcase}}],
			       -default  => $current->{upcase} || $self->{upcase_default} || 'none',
			       -labels   => \%labels,
			       @{$self->{upcase}} > 4 ? (-cols     => 4) : ()
			      ))
	       );
  }
  if ($self->{alignable} && @{$self->{alignable}}) {
    my %labels = map {$_ => $browser->setting($_=>'key') || $_} @{$self->{alignable}};
    $html .= TR(
		th('Features to include in alignment:'),
		td(checkbox_group(-name     => $self->config_name('align'),
				  -values   => $self->{alignable},
				  -defaults => $current->{align},
				  -labels   => \%labels,
				  @{$self->{alignable}} > 4 ? (-cols     => 4) : ()
				 )));
  }
  $html .= TR(
	      th({-colspan=>2,-align=>'left'},
		 'Allow up to',popup_menu(-name     => $self->config_name('ragged'),
					  -values   => $self->{ragged},
					  -default  => $current->{ragged} || $self->{ragged_default} || 0),
		 '&nbsp;bp of unaligned sequence at ends.')
	      );
  return $html ? table({-class=>'searchtitle'},$html) : undef;
}

sub reconfigure {
  my $self = shift;
  my $current = $self->configuration;
  my @align   = $self->config_param('align');
  my $upcase  = $self->config_param('upcase');
  $current->{align}  = \@align;
  $current->{upcase} = $upcase eq 'none' ? undef : $upcase;
  $current->{ragged} = $self->config_param('ragged');
  $current->{flip} = $self->config_param('flip');
}

sub mime_type { 'text/html' }

sub dump {
  my $self    = shift;
  my $segment = shift;

  unless ($segment) {
    print "No sequence specified.\n";
    exit 0;
  }

  my $database      = $self->database;
  my $browser       = $self->browser_config;
  my $configuration = $self->configuration;

#  $configuration->{flip} = $self->page_settings->{flip};

  my $flipped = $configuration->{flip} ? " (reverse complemented)" :'';
  print h1("Alignments for $segment$flipped");

  my $ref_dna = lc $segment->dna;

  if ($segment->strand < 0) {  # don't ask
    $ref_dna    = reversec($ref_dna);
    $configuration->{flip} = 1;
  }

  my ($abs_start,$abs_end) = ($segment->start,$segment->end);

  # do upcasing
  if (my $upcase_track  = $configuration->{upcase}) {
    my @upcase_types    = shellwords($browser->setting($upcase_track=>'feature'));
    my @upcase_features = $segment->features(-types=>\@upcase_types);
    for my $f (@upcase_features) {
      my @segments = $f->segments;
      @segments    = $f unless @segments;
      for my $s (@segments) {
	my $upstart   = $s->low-$abs_start;
	my $uplength  = $s->length;
	$upstart      = 0 if $upstart < 0;
	$uplength     = length($ref_dna) if $uplength > length($ref_dna);
	substr($ref_dna,$upstart,$uplength) =~ tr/a-z/A-Z/;
      }
    }
  }

  # here's where we handle aligned objects
  my @feature_types = map {shellwords($browser->setting($_=>'feature'))} @{$configuration->{align}};
  my @features      = $segment->features(-types=>\@feature_types);

  my (@segments,%strands);

  for my $f (@features) {
    warn "f strand = ",$f->strand if DEBUG;
    my @s = $f->segments;
    @s    = $f unless @s;
    @s    = grep {$abs_start<=$_->abs_end && $abs_end>=$_->abs_start} @s;

    for my $s (@s) {
      my $target = $s->target;
      my ($src_start,$src_end) = ($s->start,$s->end);
      my ($tgt_start,$tgt_end) = ($target->start,$target->end);

      my $flip_bug;

      unless (exists $strands{$target}) {
	my $strand = $f->strand;
	if ($tgt_start > $tgt_end) {
	  $strand    = -1;
	  ($tgt_start,$tgt_end) = ($tgt_end,$tgt_start);
	  $flip_bug++;
	}
	$strands{$target}         = $strand;
	$strands{$target->seq_id} = $strand;
      }

      # Realign the segment a bit
      my ($sdna,$tdna) = ($s->dna,$target->dna);
      if ($flip_bug) {
	$sdna = reversec($sdna);
	$tdna = reversec($tdna);
      }
      warn "raw alignment:\n" if DEBUG;
      warn   $sdna,"\n",$tdna,"\n" if DEBUG;
      warn   "Realigning [$target,$src_start,$src_end,$tgt_start,$tgt_end].\n" if DEBUG;
      my @result = $self->realign($sdna,$tdna);
      foreach (@result) {
	warn "=========> [$target,@$_]\n" if DEBUG;
	my $a = $strands{$target} >= 0 ? [$target->seq_id,$_->[0]+$src_start,$_->[1]+$src_start,$_->[2]+$tgt_start,$_->[3]+$tgt_start]
	                               : [$target->seq_id,$src_end-$_->[1],$src_end-$_->[0],$_->[2]+$tgt_start,$_->[3]+$tgt_start];
	warn "[$target,$_->[0]+$src_start,$_->[1]+$src_start,$tgt_end-$_->[3],$tgt_end-$_->[2]]" if DEBUG;
	warn "=========> [@$a]\n" if DEBUG;
	warn substr($sdna,     $_->[0],$_->[1]-$_->[0]+1),"\n" if DEBUG;
	warn substr($tdna,$_->[2],$_->[3]-$_->[2]+1),"\n"      if DEBUG;
	push @segments,$a;
      }
    }
  }

  # We're now going to do all the alignments
  my %clip;
  for my $seg (@segments) {

    warn "clipping [@$seg]\n" if DEBUG;
    my $target = $seg->[TARGET];

    # left clipping
    if ( (my $delta = $seg->[SRC_START] - $abs_start) < 0 ) {
      warn "clip left $delta" if DEBUG;
      $seg->[SRC_START] = $abs_start;
      if ($strands{$target} >= 0) {
	$seg->[TGT_START] -= $delta;
      }
      warn "Left clipping gives [@$seg]\n" if DEBUG;
    }

    # right clipping
    if ( (my $delta = $abs_end - $seg->[SRC_END]) < 0) {
      warn "clip right $delta" if DEBUG;
      $seg->[SRC_END] = $abs_end;
      if ($strands{$target} < 0) {
	$seg->[TGT_START] -= $delta;
      }
      warn "Right clipping gives [@$seg]\n" if DEBUG;
    }

    my $length = $seg->[SRC_END]-$seg->[SRC_START]+1;
    $seg->[TGT_END] = $seg->[TGT_START]+$length-1;

    warn "Clipping gives [@$seg]\n" if DEBUG;
    $clip{$target}{low} = $seg->[TGT_START]
      if !defined $clip{$target}{low} || $clip{$target}{low} > $seg->[TGT_START];
    $clip{$target}{high} = $seg->[TGT_END]
      if !defined $clip{$target}{high} || $seg->[TGT_END] > $clip{$target}{high};
  }

  my $ragged = $configuration->{ragged} || 0;

  # sort aligned sequences from left to right and store them in the data structure
  # needed by Bio::Graphics::Browser2::PadAlignment
  my @sequences = ($segment->seq_id => $ref_dna);

  my %seqs;
  for my $t (sort {$clip{$a}{low}<=>$clip{$b}{low}} keys %clip) {

    # adjust for ragged ends
    $clip{$t}{low}  -= $ragged;
    $clip{$t}{high} += $ragged;

    $clip{$t}{low}   = 1 if $clip{$t}{low} < 1;

    my @order = $strands{$t}>=0?('low','high'):('high','low');
    my $dna = lc $database->dna($t,@{$clip{$t}}{@order});
    push @sequences,($t => $dna);  # dna() api gives implicit reversec

    # sanity check - needed for adjusting for ragged ends
    warn "$t low = $clip{$t}{low}, dna = $dna\n" if DEBUG;
    warn "expected ",$clip{$t}{high}-$clip{$t}{low}+1," and got ",length($dna) if DEBUG;
    $clip{$t}{high} = $clip{$t}{low}+length($dna)-1 if $clip{$t}{high} > $clip{$t}{low}+length($dna)-1;
  }

  for my $seg (@segments) {
    my ($target,$src_start,$src_end,$tgt_start,$tgt_end) = @$seg;
    warn "clip high = $clip{$target}{high}" if DEBUG;
    warn "was [$target,$src_start,$src_end,$tgt_start,$tgt_end]" if DEBUG;
    $seg->[SRC_START] -= $abs_start;
    $seg->[SRC_END]   -= $abs_start;

    if ($strands{$target} >= 0) {
      $seg->[TGT_START] -= $clip{$target}{low};
      $seg->[TGT_END]   -= $clip{$target}{low};
    } else {
      @{$seg}[TGT_START,TGT_END] = ($clip{$target}{high} - $seg->[TGT_END],
				    $clip{$target}{high} - $seg->[TGT_START]);
    }
    ($target,$src_start,$src_end,$tgt_start,$tgt_end) = @$seg;
    warn "is  [$target,$src_start,$src_end,$tgt_start,$tgt_end]" if DEBUG;
  }

  # remove segments that got clipped out of existence
  @segments = grep { $_->[SRC_START]<=$_->[SRC_END] } @segments;

  if (DEBUG) {
    warn "DEBUG:";
    my %sequences = @sequences;
    foreach (@segments) {
      my ($t,$s,$e,$ts,$te) = @$_;
      warn "[@$_]\n";
      warn substr($sequences{$segment->display_name},$s,$e-$s+1),"\n";
      warn substr($sequences{$t},$ts,$te-$ts+1),"\n";
    }
  }

  my $align = Bio::Graphics::Browser2::PadAlignment->new(\@sequences,\@segments);
  my %offsets = map {$_ => $strands{$_} >= 0 ? $clip{$_}{low} : -$clip{$_}{low}} keys %clip;
  $offsets{$segment->display_name} = $abs_start;

  print pre($align->alignment(\%offsets,{show_mismatches => 1,
					 flip            => $configuration->{flip}}
			     ));
}

sub realign {
  my $self = shift;
  my ($src,$tgt) = @_;
  warn join "\n",Bio::Graphics::Browser2::Realign::align($src,$tgt) if DEBUG;
  return align_segs($src,$tgt);
}

sub reversec {
  my $dna = reverse shift;
  $dna =~ tr/gatcGATC/ctagCTAG/;
  $dna;
}

1;

__END__

=head1 NAME

Bio::Graphics::Browser2::Plugin::Aligner - Dump multiple alignments from GBrowse

=head1 SYNOPSIS

In the appropriate gbrowse configuration file:

 plugins = Aligner

 # and later
 [Aligner:plugin]
 alignable_tracks   = EST
 upcase_tracks      = CDS Motifs
 upcase_default     = CDS

=head1 DESCRIPTION

The Aligner plugin dumps multiple nucleotide-to-nucleotide alignments
in text form.  For it to work properly, the genomic DNA must be
loaded, as well as the DNAs for each of the aligned objects.  In
addition, the GFF load file must represent both the source and the
target of the alignment using the Target notation.  For example:

  ctgA  est  match  1050  3202  .  +  .  Target EST:agt830.5 1 554
  ctgA  est  HSP    1050  1500  .  +  .  Target EST:agt830.5 1 451
  ctgA  est  HSP    3000  3202  .  +  .  Target EST:agt830.5 452 654

=head1 OPTIONS

The following options are recognized.  They must be placed into a
configuration file section named [Aligner:plugin].

 Option             Description

 alignable_tracks   Space-delimited list of tracks to include in
                    the multiple alignment. The genome is always
                    included. If this option is not present, then
                    gbrowse will automatically include any track
                    that has the "draw_target" option set.

 upcase_tracks      Space-delimited list of tracks that will be used
                    to UPCASE the genomic DNA. This is very useful if
                    you want to embed the positions of coding regions
                    or other features inside the multiple alignment.
                    Uppercasing will not be turned on by default. The
                    user must press the "Configure" button, and select
                    which of the uppercase tracks are to be activated
                    from a radiolist.
 upcase_default     A space-delimited list of tracks that will be uppercased
                    by default.


 ragged_default     A small integer indicating that the aligner should
                    include some unaligned bases from the end of each sequence.
                    This is useful for seeing the sequencing primer or cloning
                    site in ESTs.

=head1 BUGS

None known yet.

=head1 SEE ALSO

L<Bio::Graphics::Browser2::Plugin>

=head1 AUTHOR

Lincoln Stein E<lt>lstein@cshl.orgE<gt>.

Copyright (c) 2001 Cold Spring Harbor Laboratory.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
