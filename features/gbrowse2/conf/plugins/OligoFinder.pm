package Bio::Graphics::Browser2::Plugin::OligoFinder;
# $Id: OligoFinder.pm,v 1.9 2004-08-23 15:56:31 lstein Exp $
# test plugin
use strict;
use Bio::Graphics::Browser2::Plugin;
use Bio::Graphics::Feature;
use Text::Shellwords;
use DBI;
use CGI qw(:standard *table);

use vars '$VERSION','@ISA';
$VERSION = '0.15';

@ISA = qw(Bio::Graphics::Browser2::Plugin);

sub name { "Short Oligos" }

sub description {
  p("The oligo finder plugin finds oligos between 11 and 50 bp in length.",
    "It does a slow search, making it suitable only for small (<150 MB) genomes.",
    "[NOTE TO SYSADMINS: The browser must use the Bio::DB::GFF schema for this plugin to work.]").
  p("This plugin was written by Lincoln Stein.");
}

sub type { 'finder' }

sub config_defaults {
  my $self = shift;
  return { };
}

# we have no stable configuration
# sub reconfigure { }

sub configure_form {
  my $self = shift;
  my $oligo = $self->config_param('searcholigo');
  my $msg  =  $oligo && !$self->valid_oligo($oligo)
              ? font({-color=>'red'},"Invalid oligo: either too short or not DNA")
	      : '';
  return $msg .
    table(TR({-class=>'searchtitle'},
	     th({-colspan=>2,-align=>'LEFT'},
		'Enter an oligonucleotide between 12 and 50 bp in length.',
		'The browser will identify all genomic regions that contain',
		'this oligo.  This is NOT a fast algorithm, so have patience.')),
	  TR({-class=>'searchbody'},
	     th('Enter oligo:'),
	     td(textfield(-name=>$self->config_name('searcholigo'),
			  -size=>50,-width=>50))
	    )
	 );
}

# find() returns undef unless the OligoFinder.searcholigo parameter
# is specified and valid.  Returning undef signals the browser to invoke the
# configure_form() method.
# If successful, it returns an array ref of Bio::SeqFeatureI objects.
sub find {
  my $self     = shift;
  my $segments = shift; # current segments - can search inside them or ignore
                        # In this example we do a global search.

  my $oligo = lc $self->config_param('searcholigo');
  $self->auto_find($oligo);
}

# auto_find() does the actual work
# It is also called by the main page as a last resort when the user
# types something into the search box that isn't recognized.
sub auto_find {
  my $self  = shift;
  my $oligo = lc shift;

  $self->valid_oligo($oligo) or return;

  (my $reversec = $oligo) =~ tr/gatcGATC/ctagCTAG/;
  $reversec = reverse $reversec;
  my $length = length $oligo;

  my $db    = $self->database or die "I do not have a database";
  my $dbi   = $db->features_db;

  my @chroms = $self->get_chroms($db);
  my $in     = join ',',map {$dbi->quote($_)} @chroms;
  my $sth =
    $dbi->prepare("select fref,foffset,fdna from fdna where fref in ($in) order by fref,foffset",
		  { 'mysql_use_result' => 1}) or die "Couldn't prepare ",$db->errstr;
  $sth->execute or die "Couldn't execute ",$db->errstr;

  my $bit_to_keep = length($oligo) - 1;
  my ($current_ref,$offset,$dna,@results);
  
  while (my ($ref,$off,$d) = $sth->fetchrow_array) {
    if (!defined($current_ref) or $current_ref ne $ref) {
      $offset = 0;
      $dna    = '';
    }
    $current_ref = $ref;

    # truncate all but the last length(oligo)-1 bases
    substr($dna,0,length($dna)-$bit_to_keep) = '';
    $offset  = $off - length($dna);
    $dna    .= lc $d;

    my @forward = $self->exact_matches($dna,$oligo);
    my @reverse = $self->exact_matches($dna,$reversec);

    for ([$oligo=>\@forward],[$reversec=>\@reverse]) {
      my ($name,$pos) = @$_;
      for my $p (@$pos) {
	push @results, Bio::Graphics::Feature->new(-ref   => $ref,
						   -type  => 'oligo',
						   -name  => $name,
						   -start => $offset+$p+1,
						   -score => '100%',
						   -end   => $offset+$p+length($oligo),
						   -factory=> $db,
						  )
      }
    }
  }
  return \@results;
}

sub exact_matches {
  my $self   = shift;
  my ($dna,$oligo) = @_;
  my @results;
  my $offset = 0;
  while ((my $i = index($dna,$oligo,$offset)) >= 0) {
    push @results,$i;
    $offset = $i+length($oligo);
  }
  @results;
}

# This is a slowish query, so cache the results per-source.
# Bio::DB::GFF has no concept of the reference DNA, so we just look
# inside segments of DNA that are more than 20K in length and hence
# likely to represent genomic.
sub get_chroms {
  my $self = shift;
  my $db   = shift;
  my $dbi  = $db->features_db;
  my $source = $self->browser_config();
  my $chroms;
  my @chroms = shellwords($self->browser_config->plugin_setting('search_segments'));
  if (@chroms) {
    $chroms = \@chroms;
  }
  else {
    return @{$self->{chroms}{$source}} if ref($self->{chroms}{$source});
    $chroms = $dbi->selectcol_arrayref('select fref from fdna group by fref having count(fref)>10');
  }
  $self->{chroms}{$source} = $chroms;
  return @$chroms;
}

# return true if a valid oligo
sub valid_oligo {
  my $self = shift;
  my $oligo = shift or return;
  return $oligo =~ /^[gatcn]{11,50}$/i
}

1;
