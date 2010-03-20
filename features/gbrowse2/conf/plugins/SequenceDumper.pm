# $Id: SequenceDumper.pm,v 1.18 2009-01-02 20:57:37 lstein Exp $
#
# BioPerl module for Bio::Graphics::Browser2::Plugin::SequenceDumper
#
# Cared for by Jason Stajich <jason@bioperl.org>
#
# Copyright Jason Stajich and Cold Spring Harbor Laboratories 2002
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Graphics::Browser2::Plugin::SequenceDumper - A plugin for dumping sequences in various formats

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

This is a plugin to the Generic Model Organism Database browse used by
Bio::Graphics::Browser to dump out an annotated region in a requested
flatfile format.  Currently the feature formats are 

=head1 FEEDBACK

See the GMOD website for information on bug submission http://www.gmod.org.

=head1 AUTHOR - Jason Stajich

Email jason@bioperl.org

Describe contact details here

=head1 CONTRIBUTORS

Additional contributors names and emails here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::Graphics::Browser2::Plugin::SequenceDumper;
# $Id: SequenceDumper.pm,v 1.18 2009-01-02 20:57:37 lstein Exp $
# Sequence Dumper plugin

use strict;
use Bio::Graphics::Browser2::Plugin;
use Bio::SeqIO;
use Bio::Seq::RichSeq;
use POSIX qw(strftime);
use Bio::Location::Fuzzy;
use CGI qw(:standard *pre);
use Bio::SeqFeature::Generic;
use vars qw($VERSION @ISA);
use constant DEBUG => 0;

             # module        label           is xml?
my @FORMATS = ( 'fasta'   => ['Fasta',        undef],
		'genbank' => ['Genbank',      undef],
		'embl'    => ['EMBL',         undef],
		'gcg'     => ['GCG',          undef],
		'raw'     => ['Raw sequence', undef],
		'game'    => ['GAME (XML)',   'xml'],
		'bsml'    => ['BSML (XML)',   'xml'],
		'gff'     => ['GFF',          undef],
	      );

# initialize @ORDER using the even-numbered elements of the array
# and grepping for those that load successfully (some of the
# modules depend on optional XML modules).
my @ORDER = grep {
  my $module = "Bio::SeqIO::$_";
  warn "trying to load $module\n" if DEBUG;
  eval "require $module; 1";
}
  grep { ! /gff/i } map { $FORMATS[2*$_] } (0..@FORMATS/2-1);

unshift @ORDER,'gff';

# initialize %FORMATS and %LABELS from @FORMATS
my %FORMATS = @FORMATS;
my %LABELS  = map { $_ => $FORMATS{$_}[0] } keys %FORMATS;

$VERSION = '0.12';

@ISA = qw(Bio::Graphics::Browser2::Plugin);

sub name { "Sequence File" }
sub description {
  p("The Sequence dumper plugin dumps out the currently displayed genomic segment",
    "in the requested format.").
  p("This plugin was written by Lincoln Stein and Jason Stajich.");
}

sub dump {
  my $self = shift;
  my $segment = shift;
  
  my $config  = $self->configuration;  
  my $wantsorted = $config->{'wantsorted'} || 0; 
  my $browser = $self->browser_config();
  my @markup;
  my %markuptype;

  # special case for GFF dumping
  if ($config->{'fileformat'} eq 'gff') {
    $self->gff_dump($segment);
    return;
  }
  my @filter    = $self->selected_features;
  my $seq  = new Bio::Seq::RichSeq(-display_id       => $segment->display_id,
				   -desc             => $segment->desc,
				   -accession_number => $segment->accession_number,
				   
				   -alphabet         => $segment->alphabet || 'dna',
			  );
  $seq->add_date(strftime("%d-%b-%Y",localtime));
  $seq->primary_seq($segment->primary_seq);
  $segment->absolute(1);
  my $offset     = $segment->start - 1;
  my $segmentend = $segment->length;
  $seq->add_SeqFeature( map {
      my $nf = new Bio::SeqFeature::Generic(-primary_tag => $_->primary_tag,
					    -source_tag  => $_->source_tag,
					    -frame       => eval{$_->phase}||eval{$_->frame}||undef,
					    -score       => $_->score,
					    );
      for my $tag ( $_->get_all_tags ) {
	  my %seen;
	  $nf->add_tag_value($tag, grep { ! $seen{$_}++ } 
			     grep { defined } $_->get_tag_values($tag));
      }
      my $loc = $_->location;
      my @locs = $loc->each_Location;
      for my $sl (@locs ) {
	  $sl->start($sl->start() - $offset);
	  $sl->end  ($sl->end() - $offset );
	  my ($startstr,$endstr);

	  if( $sl->start() < 1) {
	      $startstr = "<1";
	      $endstr   = $sl->end;
	  }
	  
	  if( $sl->end() > $segmentend) {
	      $endstr = ">$segmentend";
	      $startstr = $sl->start unless defined $startstr;
	  }
	  if( defined $startstr || defined $endstr ) {
	      $sl = Bio::Location::Fuzzy->new(-start         => $startstr,
					      -end           => $endstr,
					      -strand        => $sl->strand,
					      -location_type => '..');
	      # warn $sl->to_FTstring();
	  }
      }
      if( @locs > 1 ) { 
	  # let's insure they are sorted
          if( $wantsorted ) {  # for VectorNTI
	      @locs = sort { $a->start <=> $b->start } @locs;
          }
	  $nf->location( new Bio::Location::Split(-locations => \@locs,
						  -seq_id    =>
						  $segment->display_id));
      } else { 
	  $nf->location(shift @locs);
      }
      $nf;
  } $segment->features(-types => \@filter) );

  my $out = new Bio::SeqIO(-format => $config->{fileformat});
  my $mime_type = $self->mime_type;
  if ($mime_type =~ /html/) {
    print start_html($segment->desc),h1($segment->desc), start_pre;
    $out->write_seq($seq);
    print end_pre();
    print end_html;
  } else {
    $out->write_seq($seq);
  }
  undef $out;
}

sub mime_type {
  my $self = shift;
  my $config = $self->configuration;
  return 'text/plain' if $config->{format} eq 'text';
  return 'text/xml'   if $config->{format} eq 'html' && $FORMATS{$config->{fileformat}}[1]; # this flag indicates xml
  return 'text/html'  if $config->{format} eq 'html';
  return wantarray ? ('application/octet-stream','dumped_region') : 'application/octet-stream'
    if $config->{format} eq 'todisk';
  return 'text/plain';
}

sub config_defaults {
  my $self = shift;
  return { format           => 'html',
	   fileformat       => 'fasta',
           wantsorted       => 0,
       };
}

sub reconfigure {
  my $self = shift;
  my $current_config = $self->configuration;

  foreach my $param ( $self->config_param() ) {
      $current_config->{$param} = $self->config_param($param);
  }
}

sub configure_form {
  my $self = shift;
  my $current_config = $self->configuration;
  my @choices = TR({-class => 'searchtitle'},
			th({-align=>'RIGHT',-width=>'25%'},"Output",
			   td(radio_group(-name     => $self->config_name('format'),
					  -values   => [qw(text html todisk)],
					  -default  => $current_config->{'format'},
					  -labels   => {html => 'html/xml',
							'todisk' => 'Save to Disk',
						       },
					  -override => 1))));
  my $browser = $self->browser_config();
  # this to be fixed as more general

  push @choices, TR({-class => 'searchtitle'}, 
			th({-align=>'RIGHT',-width=>'25%'},"Sequence File Format",
			   td(popup_menu('-name'   => $self->config_name('fileformat'),
					 '-values' => \@ORDER,
					 '-labels' => \%LABELS,
					 '-default'=> $current_config->{'fileformat'} ))));
  push @choices, TR({-class => 'searchtitle'}, 
			th({-align=>'RIGHT',-width=>'25%'},
			   "Sorted SubLocations (for VectorNTI input of GenBank)",
			   td(popup_menu('-name'   => $self->config_name('wantsorted'),
					 '-values' => [qw(0 1)],
					 '-labels' => { '0' => 'No',
							'1' => 'Yes'},
					 '-default'=> $current_config->{'wantsorted'} ))));
  
  my $html= table(@choices);
  $html;
}

sub gff_dump {
  my $self          = shift;
  my $segment       = shift;
  my $page_settings = $self->page_settings;
  my $conf          = $self->browser_config;
  my $date = localtime;

  my $mime_type = $self->mime_type;
  my $html      = $mime_type =~ /html/;
  print start_html($segment) if $html;
  
  print h1($segment),start_pre() if $html;
  print "##gff-version 2\n";
  print "##date $date\n";
  print "##sequence-region ",join(' ',$segment->ref,$segment->start,$segment->stop),"\n";
  print "##source gbrowse SequenceDumper\n";
  print "##See http://www.sanger.ac.uk/Software/formats/GFF/\n";
  print "##NOTE: Selected features dumped.\n";
  my @feature_types = $self->selected_features;
  $segment->absolute(0);
  my $iterator = $segment->get_seq_stream(-types => \@feature_types) or return;
  while (my $f = $iterator->next_seq) {
    print $f->gff_string,"\n";
    for my $s ($f->sub_SeqFeature) {
      print $s->gff_string,"\n";
    }
  }
  print end_pre() if $html;
  print end_html() if $html;
}

1;
