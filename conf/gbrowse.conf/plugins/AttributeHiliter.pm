package Bio::Graphics::Browser::Plugin::AttributeHiliter;
# $Id: AttributeHiliter.pm,v 1.2 2003/09/18 19:51:33 scottcain Exp $
use strict;
use Bio::Graphics::Browser::Plugin;

use CGI qw(:standard);

use constant DEBUG => 0;

use vars qw($VERSION @ISA);

my @COLORS = ('',qw(
		   red brown magenta maroon pink orange
		   yellow tan teal cyan lime green blue
		   lightgrey grey darkgrey
		  ));

$VERSION = '0.01';

@ISA = qw(Bio::Graphics::Browser::Plugin);

sub name { "Selected Properties" }
sub description {
  p("This plugin highlights features whose properties match certain criteria.",
    "It only works with Bio::DB::GFF databases currently."),
  p("This plugin was written by Lincoln Stein.");
}

sub type { 'highlighter' }

# This routine is a bit more complicated than it needs to be because of
# an optimization.  What it does is to compile the highlighting pattern specified
# by the current configuration into a subroutine called "memoized_sub" and then
# invoke it.  On subsequent invocations if the config hasn't changed, the
# compiled subroutine is reinvoked.  Otherwise a new sub is compiled.  The compiled
# sub can be seen by setting the DEBUG constant at the top of this file to true.  An
# example is also here:
# 

sub highlight {
  my $self = shift;
  my $feature = shift;

  my $config = $self->configuration;
  return unless %$config;

  return $self->{memoized_sub}->($feature)
    if $self->{memoized_sub} && $self->{memoized_config} eq join ' ',%$config;

  my $sub = "sub { \n";
  $sub   .= "  my \$feature = shift;\n";

  for my $attribute (keys %$config) {
    my ($color,$text) = split(/\s+/,$config->{$attribute},2);
    next unless defined $color && defined $text;

    warn "trying to colorize $attribute with text=$text, color = $color\n" if DEBUG;

    my $regexp = quotemeta($text);
    if ($attribute eq 'Feature Name') {
      $sub .= "  return '$color' if \$feature->display_name =~ /$regexp/i;\n";
    } elsif ($attribute eq 'Feature Type') {
      $sub .= "  return '$color' if \$feature->type =~ /$regexp/i;\n";
    } elsif (defined $attribute) {
      $sub .= "  foreach (\$feature->attributes('$attribute')) { return '$color' if /$regexp/i }\n";
    }
  }
  $sub .= "  return\n}";
  warn $sub if DEBUG;
  $self->{memoized_sub}    = eval $sub or warn $@;
  $self->{memoized_config} = join ' ',%$config;
  return $self->{memoized_sub}->($feature) if $self->{memoized_sub};
  return;
}

sub config_defaults {
    my $self = shift;
    return { };
}

sub reconfigure {
  my $self = shift;
  my $current_config = $self->configuration;
  my %c;
  foreach my $param ($self->config_param) {
    warn "param = $param" if DEBUG;
    my ($operation,$attribute) = $param =~ /(match|color)\.(.+)/ or next;
    $c{$attribute}{$operation} = $self->config_param($param);
  }
  foreach my $attribute (keys %c) {
    if ( (my $match_text = $c{$attribute}{match}) && (my $match_color = $c{$attribute}{color})) {
      $current_config->{$attribute} = "$match_color $match_text";
    } else {
      delete $current_config->{$attribute};
    }
  }
  delete $self->{memoized_sub};
}

sub configure_form {
    my $self = shift;
    my $current_config = $self->configuration;
    my $db             = $self->database;
    my @attributes     = sort {lc $a cmp lc $b} $db->attributes;
    unshift @attributes,'Feature Name','Feature Type';

    my @rows;
    push @rows,TR({-class=>'searchtitle'},th(['Property','Text to Match','Highlight Color']));

    for my $attribute (@attributes) {
      next unless $attribute;
      my ($color,$text) = split(/\s+/,$current_config->{$attribute}||'',2);
      push @rows,TR(
		    th({-class=>'searchtitle',-align=>'RIGHT'},$attribute),
		    td({-align=>'CENTER'},textfield(-name    => $self->config_name("match.$attribute"),
						    -default => $text,
						    -size    => 60)),
		    td(popup_menu(-name  => $self->config_name("color.$attribute"),
				  -values=> \@COLORS,
				  -default => $color,
				 )))
    }

    return table({-width=>'10%',-border=>0},@rows);
}


1;
