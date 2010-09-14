package Bio::Graphics::Browser2::Plugin::TrackDumper;
# $Id: TrackDumper.pm,v 1.3 2009-01-30 22:06:19 lstein Exp $
# test plugin
use strict;
use Bio::Graphics::Browser2::Plugin;
use Bio::Graphics::Browser2::TrackDumper;
use CGI qw(:standard *sup);

use vars '$VERSION','@ISA';
$VERSION = '1.00';

@ISA = qw/ Bio::Graphics::Browser2::Plugin /;

sub name { "Track Data" }
sub description {
  p("The Track dumper plugin dumps out the currently selected tracks and their configuration in",
    a({-href=>'http://www.sequenceontology.org/gff3.shtml'},'GFF Version 3 format.'),
    "The information can be edited and then uploaded to this, or another GBrowse instance to create new tracks.",
    "This plugin was written by Lincoln Stein &amp; Sheldon McKay.");
}

sub config_defaults {
  my $self = shift;
  return { 
	  version     => 3,
	  mode        => 'selected',
	  disposition => 'save',
	  coords      => 'absolute',
	  region      => 'selected',
	  embed       => 0,
	  print_config=> 1,
	 };
}

sub reconfigure {
  my $self = shift;
  my $current_config = $self->configuration;
  my @keys = keys %{$self->config_defaults};
  foreach my $p ( @keys ) {
      $current_config->{$p} = $self->config_param($p);
  }
}

sub configure_form {
  my $self = shift;
  my $current_config = $self->configuration;
  my $html = p('Dump',
	       popup_menu(-name   => $self->config_name('mode'),
			  -values  => ['selected','all'],
			  -default => $current_config->{mode},
			  -override => 1,
			 ),
	       '&nbsp; features using GFF version',
	       popup_menu(-name   => $self->config_name('version'),
			  -values => [2,2.5,3],
			  -labels => { 2   => '2',
                                       2.5 => '2.5*',
				       3   => '3'},
			  -default => $current_config->{version},
			  -override => 1),
  
	       popup_menu(-name=>$self->config_name('region'),
			  -default=>$current_config->{region},
			  -override=>1,
			  -values => ['selected','all'],
			  -labels=>{all      => 'Across entire genome',
				    selected => 'Across currently visible region'})
      );      

  autoEscape(0);
  $html .= p(
	     radio_group(-name=>$self->config_name('disposition'),
			 -values => ['view','save','edit'],
			 -labels => {view => 'View',
				     save => 'Save to File',
				     edit => 'Edit'.sup('**'),
				 }
			));
  $html .= p(
	     checkbox(-name=>$self->config_name('embed'),
		      -checked=>$current_config->{embed},
		      -override=>1,
		      -label=>'Embed DNA sequence in the file')
		      );      
  $html .= p(
	     checkbox(-name=>$self->config_name('print_config'),
		      -checked=>$current_config->{print_config},
		      -override=>1,
		      -label=>'Include track configuration data')
		      );      
  autoEscape(1);

  my $href = a( {-href => 'javascript:void(0)', -onclick => "alert('" .
		"\\'Target\\' syntax in the group field:\\n" .
                "GFF2:   Target class:name start stop\\n" .
		"GFF2.5: Target class:name ; tstart start ; tstop stop\\n')"},
		"similarity target" );

  $html .= p(sup('*'), 
              "GFF2.5 is GFF2 with a special syntax for $href"
              ) .
           p(sup('**'),
	      "To edit, install a helper application for MIME type",
	      cite('application/x-gff2'),'or',
	      cite('application/x-gff3')
	      );
  $html;
}

sub mime_type {
  my $self   = shift;
  my $config = $self->configuration;
  my $ps     = $self->page_settings;
  my $base   = join '_',@{$ps}{qw(ref start stop)};
  my $gff    = $config->{version} < 3 ? 'gff2' : 'gff3';
  return $config->{disposition} eq 'view' ? 'text/plain'
        :$config->{disposition} eq 'save' ? ('application/octet-stream',"$base.$gff")
        :$config->{disposition} eq 'edit' ? "application/x-${gff}"
        :'text/plain';
}

sub dump {
  my $self = shift;
  my ($segment, @more_feature_sets) = @_;
  my $conf          = $self->browser_config;
  my $page_settings = $self->page_settings;
  my $config        = $self->configuration;
  my $version       = $config->{version} || 3;
  my $mode          = $config->{mode}    || 'selected';
  my $entire_genome = $config->{region} && $config->{region} eq 'all';
  my $db            = $self->database;
  my $whole_segment = $db->segment(Accession => $segment->seq_id) ||
                      $db->segment($segment->seq_id);
  my $coords        = $config->{coords};
  my $embed         = $config->{embed};

  my $thing_to_dump = $entire_genome ? $segment->db : $segment;

  # safest thing to do is to use embedded logic
  if ($version == 3 && $config->{print_config}) {
      my $dumper = Bio::Graphics::Browser2::TrackDumper->new(
	  -data_source => $conf,
	  -id          => $page_settings->{userid},
	  -segment     => $segment->seq_id.':'.$segment->start.'..'.$segment->end,
	  -labels      => $mode eq 'selected' 
	                  ? [$self->selected_tracks] 
	                  : []
	  ) or return;
      $dumper->print_gff3();
  }

  elsif ($config->{print_config}) {
      Bio::Graphics::Browser2::TrackDumper->print_configuration
	  ($self->browser_config,
	   $mode eq 'selected' ? [$self->selected_tracks] : ()
	  );
      $self->print_gff($thing_to_dump,@more_feature_sets);
  }

  else {
      $self->print_gff($thing_to_dump,@more_feature_sets);
  }

  if ( $embed && !$entire_genome) {
    my $dna = $segment->dna;
    $dna =~ s/(\S{60})/$1\n/g;
    print ">$segment\n$dna\n" if $dna;
  }
}

sub print_gff {
    my $self = shift;
    my ($segment, @more_feature_sets) = @_;
    my $config     = $self->configuration;
    my $version    = $config->{version} || 3;
    my $mode       = $config->{mode}    || 'selected';
    
    my $date = localtime;
    print "##gff-version $version\n";
    print "##date $date\n";
    eval {print "##sequence-region ",join(' ',$segment->ref,$segment->start,$segment->stop),"\n"};
    print "##source gbrowse GFFDumper plugin\n";
    print $mode eq 'selected' ? "##NOTE: Selected features dumped.\n"
	: "##NOTE: All features dumped.\n";

    my @args;
    if ($mode eq 'selected') {
	my @feature_types = $self->selected_features;
	@args = (-types => \@feature_types);
    }
      
    my @feats = ();

    my $iterator = $segment->get_seq_stream(@args);
    while ( my $f = $iterator->next_seq ) {
	$self->print_feature($f,$version);
    }

    for my $set (@more_feature_sets) {
	if ( $set->can('get_seq_stream') ) {
	    my @feats = ();
	    my $iterator = $set->get_seq_stream;
	    while ( my $f = $iterator->next_seq ) {
		$self->print_feature($f);
	    }
	}
    }
}

sub print_feature {
  my $self = shift;
  my ($f,$version) = @_;
  $version       ||= 3;
  eval{$f->version($version)};
  my $s = $f->gff_string(1); # the flag is for GFF3 subfeature recursion
  chomp $s;
  print $s,"\n";
  return if $version >= 3; # gff3 recurses automatically
  for my $ss ($f->sub_SeqFeature) {
    # next if $ss eq $f;
    my $s = $ss->gff_string;
    print $s,"\n";
  }
}

1;
