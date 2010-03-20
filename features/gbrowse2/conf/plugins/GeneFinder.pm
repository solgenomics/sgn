package Bio::Graphics::Browser2::Plugin::GeneFinder;

# $Id: GeneFinder.pm,v 1.3 2005-12-09 22:19:09 mwz444 Exp $
# test plugin
use strict;
use File::Temp 'tempfile';
use File::Spec;
use Bio::Graphics::Browser2::Plugin;
use Bio::SeqFeature::Generic;
use CGI qw(:standard *table);

use vars '$VERSION','@ISA';
$VERSION = '0.2';

use constant GENEFINDER => 'gfcode';   # must be in the path somewhere
use constant GFTABLES   => 'gftables'; # must be in the gbrowse.conf directory

@ISA = qw(Bio::Graphics::Browser2::Plugin);

sub name { "GeneFinder Features" }

sub description {
  p("This plugin is a front end to Phil Green's GeneFinder program.").
  p("It is an early work in progress.").
  p("Please build and install the 'gfcode' program (located in the contrib directory) before using this plugin.");
}

sub type { 'annotator' }

sub init { }

sub config_defaults {
  my $self = shift;
  return { };
}

sub reconfigure {
  my $self = shift;
  return;
}



sub configure_form {
  my $self = shift;
  return;
}

sub annotate {
  my $self    = shift;
  my $segment = shift;
  my $dna     = $segment->seq;
  my $abs_start = $segment->start;

  # write DNA out into a tempfile
  my ($fh,$filename) = tempfile('gfXXXXXXX',
				SUFFIX => '.fa',
				UNLINK => 1,
				DIR    => File::Spec->tmpdir,
			       );
  print $fh ">segment\n";
  print $fh $dna;
  close $fh;

  my $gftables = File::Spec->catfile($self->config_path(),GFTABLES);
  my $command = join ' ',GENEFINDER,$gftables,$filename;

  open (F,"$command |") or die "Couldn't open genefinder. Did you install the gfcode program and the gftables config file?: $!";
  my $atgheight = sub {
    my $f = shift;
    return int($f->score/5 * 20);
  };

  my $atgtop  = sub {
    return (20-$atgheight->(@_));
  };

  my $feature_list = Bio::Graphics::FeatureFile->new;
  $feature_list->add_type(splice => {glyph => 'splice_site',
				     key   => 'GF splice acceptor/donor',
				     bump      => 0,
				     direction => sub {
				       my $f = shift;
				       my $method = $f->primary_tag;
				       return 'right' if $method eq 'splice5';
				       return 'left'  if $method eq 'splice3';
				     },
				     height    => 30,
				     height_fraction => sub { 
				       my $f = shift;
				       my $score = abs($f->score);
				       $score = 4 if $score > 4;
				       return $score/4;
				     },
				     fgcolor   => sub {
				       my $f      = shift;
				       my $method = $f->primary_tag;
				       return 'red'   if $method eq 'splice5';
				       return 'blue'  if $method eq 'splice3';
				     }
				    }
			 );
  $feature_list->add_type(startplus => {glyph => 'generic',
					key   => 'GF start site (+)',
					height => $atgheight,
					pad_top => $atgtop,
					bump    => 0,
					bgcolor => 'red',
					fgcolor => 'red'}
			 );
  $feature_list->add_type(codingplus => {glyph        => 'generic',
					 key          => 'GF coding segment (+)',
					 strand_arrow => 1,
					 bgcolor      => 'yellow'});
  $feature_list->add_type(startminus => {glyph => 'generic',
					 key   => 'GF start site (-)',
					 bump    => 0,
					 height => $atgheight,
					 pad_top => $atgtop,
					 bgcolor => 'blue',
					 fgcolor => 'blue'}
			 );
  $feature_list->add_type(codingminus => {glyph        => 'generic',
					 key          => 'GF coding segment (-)',
					 strand_arrow => 1,
					 bgcolor      => 'yellow'});

  while (<F>) {
    next if /^\#/;
    my (undef,$source,$method,$start,$end,$score,$strand) = split "\t";
    next unless defined $method;
    my $type = $method =~ /splice/ ? 'splice'
             : $method eq 'atg'    && $strand eq '+' ? 'startplus'
             : $method eq 'atg'    && $strand eq '-' ? 'startminus'
	     : $method =~ /coding/ && $strand eq '+' ? 'codingplus'
	     : $method =~ /coding/ && $strand eq '-' ? 'codingminus'
	     : '';
    next unless $type;
    my $f = Bio::SeqFeature::Generic->new(-start  => $abs_start + $start,
					  -end    => $abs_start + $end,
					  -strand => $strand eq '-' ? -1 : +1,
					  -source => $source,
					  -score  => $score,
					  -primary=> $method);
    $feature_list->add_feature($f,$type);    
  }
  close F;

  return $feature_list;
}

1;

