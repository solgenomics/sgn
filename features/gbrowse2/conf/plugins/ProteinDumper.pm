# $Id: ProteinDumper.pm,v 1.5 2006-08-30 02:37:07 lstein Exp $
#
# BioPerl module for Bio::Graphics::Browser2::Plugin::ProteinDumper
#
# Cared for by Aaron Mackey <amackey@pcbi.upenn.edu>
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Graphics::Browser2::Plugin::ProteinDumper - A plugin for dumping translated protein sequences in various formats

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

This is a plugin to the Generic Model Organism Database browse used by
Bio::Graphics::Browser to dump protein translations of genes from an
annotated region in the requested flatfile format.  Currently the
feature formats are

=head1 FEEDBACK

See the GMOD website for information on bug submission http://www.gmod.org.

=head1 AUTHOR - Aaron Mackey

Email amackey@pcbi.upenn.edu

=head1 CONTRIBUTORS

Based on the SequenceDumper plugin written by Jason Stajich

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::Graphics::Browser2::Plugin::ProteinDumper;
# $Id: ProteinDumper.pm,v 1.5 2006-08-30 02:37:07 lstein Exp $
# Protein Dumper plugin

use strict;
use Bio::Graphics::Browser2::Plugin;
use Bio::SeqIO;
use Bio::Tools::CodonTable;
use CGI qw(:standard *pre);
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
	      );

# initialize @ORDER using the even-numbered elements of the array
# and grepping for those that load successfully (some of the
# modules depend on optional XML modules).
my @ORDER = grep {
  my $module = "Bio::SeqIO::$_";
  warn "trying to load $module\n" if DEBUG;
  eval "require $module; 1";
} grep { ! /gff/i } map { $FORMATS[2*$_] } (0..@FORMATS/2-1);

# initialize %FORMATS and %LABELS from @FORMATS
my %FORMATS = @FORMATS;
my %LABELS  = map { $_ => $FORMATS{$_}[0] } keys %FORMATS;

$VERSION = '1.00';

@ISA = qw(Bio::Graphics::Browser2::Plugin);

sub name { "Protein Sequence File" }
sub description {

  p("The protein sequence dumper plugin dumps out translated protein
  sequences of genes found in the currently displayed genomic segment
  in the requested format.") .

  p("This plugin was originally written by Lincoln Stein and Jason
  Stajich, modified by Aaron Mackey.");
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

  my $ct = Bio::Tools::CodonTable->new;
  $ct->id($config->{geneticcode});

  my @filter  = grep { m/^(?:coding|CDS|transcript):/ } $self->selected_features;
  $segment->absolute(1);

  my @seqs;
  for my $f ($segment->features(-types => \@filter)) {
    my @cds = grep { $_->method =~ m/^CDS$/i } $f->sub_SeqFeature;
    next unless @cds;

    my $cds = join("", map { $_->seq } @cds);
    if ( (my $phase = $cds[0]->phase) > 0) {
      # some genefinders will predict incomplete genes, wherein
      # initial exons may not be in phase 0; in which case, we have to
      # turn the first incomplete codon into NNN
      substr($cds, 0, $phase, "NNN");
    }

    push @seqs, Bio::Seq->new(-display_id => $f->display_id,
			      -descr => $f->location->to_FTstring,
			      -seq => $ct->translate($cds)
			     );
  }

  my $out = new Bio::SeqIO(-format => $config->{fileformat});
  my $mime_type = $self->mime_type;
  if ($mime_type =~ /html/) {
    print start_html($segment->desc),h1($segment->desc), start_pre;
    $out->write_seq(@seqs);
    print end_pre();
    print end_html;
  } else {
    $out->write_seq(@seqs);
  }
  undef $out;
}

sub mime_type {
  my $self = shift;
  my $config = $self->configuration;

  return 'text/plain' if $config->{format} eq 'text';
  return 'text/xml'   if $config->{format} eq 'html' &&
    $FORMATS{$config->{fileformat}}[1]; # this flag indicates xml
  return 'text/html'  if $config->{format} eq 'html';
  return wantarray ? ('application/octet-stream','dumped_region')
                   : 'application/octet-stream'
		      if $config->{format} eq 'todisk';
  return 'text/plain';
}

sub config_defaults {
  my $self = shift;
  my $browser_config = $self->browser_config;

  # try to get the codon table to use
  # first priority is the geneticcode or codontabe setting in the plugin config section
  my $default_code = $browser_config->plugin_setting('geneticcode') || $browser_config->plugin_setting('codontable');

  # second priority is the setting in any "translation" track.
  unless (defined $default_code) { # search config file for a translation track
    for my $label ($browser_config->labels) {
      next unless $browser_config->setting($label => 'glyph') eq 'translation';
      $default_code ||= $browser_config->setting($label => 'geneticcode')
	|| $browser_config->setting($label => 'codontable');
      last if $default_code;
    }
  }

  # last try, set to 1
  $default_code ||= 1;

  return { format           => 'html',
	   fileformat       => 'fasta',
           geneticcode      => $default_code,
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
				     -override => 1,
				    )
			)
		     )
		  );

  push @choices, TR({-class => 'searchtitle'},
		    th({-align=>'RIGHT',-width=>'25%'},"Sequence File Format",
		       td(popup_menu('-name'   => $self->config_name('fileformat'),
				     '-values' => \@ORDER,
				     '-labels' => \%LABELS,
				     '-default'=> $current_config->{'fileformat'},
				    )
			 )
		      )
		   );

  push @choices, TR({-class => 'searchtitle'},
		    th({-align=>'RIGHT',-width=>'25%'},"Genetic Code",
		       td(popup_menu('-name'   => $self->config_name('geneticcode'),
				     '-values' => [
						   grep {
						     $Bio::Tools::CodonTable::NAMES[$_-1]
						   } 1..@Bio::Tools::CodonTable::NAMES
						  ],
				     '-labels' => {
						   map {
						     ( $_ => $Bio::Tools::CodonTable::NAMES[$_-1] )
						   } grep {
						     $Bio::Tools::CodonTable::NAMES[$_-1]
						   } 1..@Bio::Tools::CodonTable::NAMES
						  },
				     '-default'=> $current_config->{'geneticcode'},
				    )
			 )
		      )
		   );

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
  print "##sequence-region ",join(' ',$segment->ref,$segment->start,$segment->end),"\n";
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
