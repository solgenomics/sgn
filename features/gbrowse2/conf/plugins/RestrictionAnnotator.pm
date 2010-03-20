package Bio::Graphics::Browser2::Plugin::RestrictionAnnotator;
# $Id: RestrictionAnnotator.pm,v 1.16 2009-01-02 20:57:37 lstein Exp $
# test plugin
use strict;
use Bio::Graphics::Browser2::Plugin;
use CGI qw(:standard *table);

use vars '$VERSION','@ISA';
$VERSION = '0.25';

@ISA = qw(Bio::Graphics::Browser2::Plugin);

my %SITES;

my @COLORS = qw(red green blue orange cyan black 
		turquoise brown indigo wheat yellow emerald);

sub name { "Restriction Sites" }

sub description {
  p("The restriction site plugin generates a restriction map",
    "on the current view.").
  p("This plugin was written Elizabeth Nickerson &amp; Lincoln Stein.");
}

sub type { 'annotator' }

sub init {shift->configure_enzymes}

sub config_defaults {
  my $self = shift;
  return { 
      on    => 1,
      EcoRI => 1,
      ClaI  => 1,
      BamHI => 1,
      PvuII => 1,
  };
}

sub reconfigure {
  my $self = shift;
  my $current_config = $self->configuration;
  %$current_config = map {$_=>1} $self->config_param('enzyme');
  $current_config->{on} = $self->config_param('on');
}



sub configure_form {
  my $self = shift;
  my $current_config = $self->configuration;
  configure_enzymes() unless %SITES;
  my @buttons = checkbox_group(-name   => $self->config_name('enzyme'),
			       -values => [sort keys %SITES],
			       -cols   => 4,
			       -defaults => [grep {$current_config->{$_}} keys %$current_config]
			       );
  return table(TR({-class=>'searchtitle'},
		  th("Select Restriction Sites To Annotate")),
	       TR({-class=>'searchtitle'},
		  th({-align=>'LEFT'},
		     "Restriction Site Display ",
		     radio_group(-name=>$self->config_name('on'),
				 -values  =>[0,1],
				 -labels  => {0=>'off',1=>'on'},
				 -default => $current_config->{on},
				 -override=>1,
				))),
	       TR({-class=>'searchbody'},
		  td(@buttons)));
}

sub annotate {
  my $self = shift;
  my $segment = shift;
  my $config  = $self->configuration;
  configure_enzymes() unless %SITES;
  return unless %SITES;
  return unless %$config;
  return unless $config->{on};

  my $ref        = $segment->seq_id;
  my $abs_start  = $segment->start;
  my $dna        = $segment->seq;
  $dna           = $dna->seq if ref $dna;  # API changes -darn!

  my $feature_list = $self->new_feature_list;

  # find restriction sites
  my $i = 0;
  for my $type (keys %$config) {
    next if $type eq 'on';
    next unless $SITES{$type};
    my ($pattern,$offset) = @{$SITES{$type}};
    $feature_list->add_type($type=>{glyph   => 'generic',
				    key     => "$type restriction site",
				    fgcolor => $COLORS[$i % @COLORS],
				    bgcolor => $COLORS[$i % @COLORS],
				    point   => 0,
				    orient  => 'N',
				    link    => 'http://www.google.com/search?q=$name',
				   });
    $i++;
    while ($dna =~ /($pattern)/ig) {
      my $pos = $abs_start + pos($dna) - length($1) + $offset;
      my $feature = Bio::Graphics::Feature->new(-start=>$pos,-stop=>$pos,
						-ref=>$ref,
						-name=>$type,
						-type=>$type,
						-class=>'RestrictionSite',
						-source=>'RestrictionAnnotator.pm');
      $feature_list->add_feature($feature,$type);
    }
  }
  return $feature_list;
}

sub configure_enzymes {
  my $self = shift;
  my $conf_dir = $self->config_path();
  my $file     = "$conf_dir/enzymes.txt";
  open (ENZYMES, "$file") or die "Error: cannot open file $file: $!.\n";
  while (<ENZYMES>) {
    chomp;
    my @hold_enzyme = split(/\t/,$_);
    my $enzyme_name = shift(@hold_enzyme);
    $SITES{$enzyme_name} = \@hold_enzyme;
    next;
  }
  close(ENZYMES);
}

1;

__END__

=head1 NAME

Bio::Graphics::Browser2::Plugin::RestrictionAnnotator - Generate a restriction map track in GBrowse

=head1 SYNOPSIS

In the appropriate gbrowse configuration file:

 plugins = RestrictionAnnotator

=head1 DESCRIPTION

The RestrictionAnnotator plugin generates a series of automatic tracks
showing restriction enzyme cut sites.  For it to work properly, the
genomic DNA must be loaded.

=head1 OPTIONS

There are now config file options.  The list of enzymes and their cut
sites is contained in APACHE_CONFIG/gbrowse.conf/enzymes.txt, where
APACHE_CONFIG is your Apache configuration directory.  It is
straightforward to add new enzymes.  The format is:

 <enzyme name>   <recognition site>   <cut site position>

For example, the entry for EcoRI is

  EcoRI	GAATTC	1

The "1" means that EcoRI will be cleaved at position 1, where
positions are BETWEEN the bases starting with 0:

  0 1 2 3 4 5 6
   G A A T T C

The recognition site can be a regular expression.

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
