package Bio::Graphics::Browser2::Plugin::AlignTwoSequences;
# $Id: AlignTwoSequences.pm,v 1.2 2003-08-27 21:17:46 markwilkinson Exp $

use strict;
use Bio::Graphics::Browser2::Plugin;
use CGI qw(:standard *table);
use vars '$VERSION','@ISA','$blast_executable';


=head1 NAME

Bio::Graphics::Browser2::Plugin::AlignTwoSequences -- a plugin that executes NCBI's bl2seq on the current view

=head1 SYNOPSIS

 in 0X.organism.conf:
     
 [AlignTwoSequences:plugin]
 bl2seq_executable = /usr/local/BLAST/bl2seq
 


=head1 DESCRIPTION

This Gbrowse plugin will take a sequence (entered in the configuration screen)
and BLAST it against the current display, with hits as new sequence features.

You must, of course, have the NCBI Blast suite of programs installed,
you must have configured the plugin to be visible, and you must
set a single plugin parameter in the 0X.organism.conf file:
    [AlignTwoSequences:plugin]
    bl2seq_executable = /path/to/your/bl2seq

=cut


$blast_executable = "";

$VERSION = '0.02';

@ISA = qw(Bio::Graphics::Browser2::Plugin);

my @COLORS = qw(red green blue orange cyan black 
		turquoise brown indigo wheat yellow emerald);

sub name { "Blast Against Displayed Sequence" }

sub description {
  p("This plugin will take an input sequence - entered in the 'Configure' scren - and run bl2seq (a Blast sequence alignment) ",
    "against any sequence raised in the current view as new features.").
  p("This plugin was written by Mark Wilkinson.");
}

sub type { 'annotator' }
sub init {
    my $self = shift;
    my $conf = $self->browser_config;
    $blast_executable = $conf->plugin_setting('bl2seq_executable');
}

sub config_defaults {
  my $self = shift;
  return {sequence_to_blast => '',
          p => 'blastn',
          g => 'T',
          G => -1,
          E => -1,
          X => 0,
          W => 0,
          M => 'BLOSUM62',
          q => -3,
          r => 1,
          F => 'T',
          e => 10,
          S => 3,
          'm' => 'F',
          Y => 0,
          t => 0,
          U => 'F',
          };
}

sub reconfigure {
  my $self = shift;
  my $current = $self->configuration;
  $current->{'sequence_to_blast'} = $self->config_param('sequence_to_blast');
  $current->{'p'} = $self->config_param('p');
  $current->{'g'} = $self->config_param('g');
  $current->{'G'} = $self->config_param('G');
  $current->{'E'} = $self->config_param('E');
  $current->{'X'} = $self->config_param('X');
  $current->{'W'} = $self->config_param('W');
  $current->{'M'} = $self->config_param('M');
  $current->{'q'} = $self->config_param('q');
  $current->{'r'} = $self->config_param('r');
  $current->{'F'} = $self->config_param('F');
  $current->{'e'} = $self->config_param('e');
  $current->{'S'} = $self->config_param('S');
  $current->{'m'} = $self->config_param('m');
  $current->{'Y'} = $self->config_param('Y');
  $current->{'t'} = $self->config_param('t');
  $current->{'U'} = $self->config_param('U');
}
sub configure_form {
  my $self = shift;
  my $current_config = $self->configuration;

  my $form = h3("Default bl2seq values have been selected for you").
      table({-border => 0},TR([
      td([b("Sequence To Align"),   textfield(-name => $self->config_name('sequence_to_blast'),-size => 100, -value=>$current_config->{'sequence_to_blast'})]),
      td(["Blast Program: ",   popup_menu($self->config_name('p'),['blastn','tblastx'], $current_config->{'p'})]),
      td("Gapped: ").td(radio_group( -name=>$self->config_name('g'), -values=>['T','F'],-default=>$current_config->{'g'})),
      td(["Gap Penalty: ",   textfield(-name=>$self->config_name('G'),-default=>$current_config->{'G'},-size=>3,-maxlength=>3)]),
      td(["Extend Penalty: ",   textfield(-name=>$self->config_name('E'),-default=>$current_config->{'E'},-size=>3,-maxlength=>3)]),
      td(["Dropoff value: ",   textfield(-name=>$self->config_name('X'),-default=>$current_config->{'X'},-size=>3,-maxlength=>3)]),
      td(["Word size: " ,    textfield(-name=>$self->config_name('W'),-default=>$current_config->{'W'},-size=>3,-maxlength=>3)]),
      td(["Matrix: ",   popup_menu($self->config_name('M'), ['BLOSUM62'],$current_config->{'M'})]),
      td(["Mismatch Penalty: ",   textfield(-name=>$self->config_name('q'),-default=>$current_config->{'q'},-size=>3,-maxlength=>3)]),
      td(["Match Reward: ",    textfield(-name=>$self->config_name('r'),-default=>$current_config->{'r'},-size=>3,-maxlength=>3)]),
      td("Filter query: ").td(radio_group(-name=>$self->config_name('F'), -values=>['T','F'],-default=>$current_config->{'F'})),
      td(["Expect: ",   textfield(-name=>$self->config_name('e'),-default=>$current_config->{'e'},-size=>10,-maxlength=>10)]),
      td(["Strands to search: ",    textfield(-name=>$self->config_name('S'),-default=>$current_config->{'S'},-size=>1,-maxlength=>1)]),
      td(["Search Space: ",    textfield(-name=>$self->config_name('Y'),-default=>$current_config->{'Y'},-size=>3,-maxlength=>3)]),
      td(["Length of largest intron: ",    textfield(-name=>$self->config_name('t'),-default=>$current_config->{'t'},-size=>3,-maxlength=>3)]),
      td("Filter Lower Case: ").td(radio_group(-name=>$self->config_name('U'), -values=>['T','F'],-default=>$current_config->{'U'}))
                              ]));
    return $form;
}
  

sub annotate {
    my $self = shift;
    my $segment = shift;
    my $ref        = $segment->ref;
    my $abs_start  = $segment->start;
    my $dna        = $segment->seq;
    my $conf = $self->configuration;
    my $feature_list   = Bio::Graphics::FeatureFile->new(-smart_features => 1);
    $feature_list->add_type(bl2seq=>{glyph   => 'alignment',
                    key     => "BLAST alignment",
                    fgcolor => 'brown',
                    bgcolor => 'brown',
                    point   => 0,
                    'link' => 'AUTO',
                    orient  => 'N',
                   });
    #  I should add a "link" section to the feature
    #  with the configuration set to open up an alignment window
    #  of some kind via an [AlignTwoSequences:plugin]section...

    my $file = $self->do_blast($dna);
    use Bio::SearchIO;
    my $searchio = new Bio::SearchIO(-format => 'blast',
                                    -file   => $file);
    while( my $result = $searchio->next_result ) {
       while( my $hit = $result->next_hit ) {
           while( my $hsp = $hit->next_hsp ) {
                my $start = $abs_start + $hsp->start;
                my $stop = $abs_start + $hsp->end;
                my $feature = Bio::Graphics::Feature->new(
                    -start=>$start,
                    -type => "bl2seq",
                    -subtype => "similarity",
                    -desc => "Blast alignment",
                    -source => "NCBI_Blast",
                    -strand => "0",
                    -stop=>$stop,
                    -ref=>$ref,
                    -name=>'bl2seq');
                $feature_list->add_feature($feature,'bl2seq');
           }
       }
    }
    unlink $file;
    return $feature_list;
}

sub do_blast {
    my ($self, $dna) = @_;
    use File::Temp;
    use File::Temp qw/ tempfile tempdir /;
    
    my ($fh_q, $filename_q) = tempfile();
    my ($fh_t, $filename_t) = tempfile();
    my $seq2 = $self->configuration->{'sequence_to_blast'};
    print $fh_q ">seq1\n$dna\n";
    print $fh_t ">seq2\n$seq2\n";
    open IN, "$blast_executable -i $filename_q -j $filename_t -p blastn |" || die "can't execute the blast bl2seq call $!\n";
    my $result = join "", <IN>;
    my ($fh_r, $filename_r) = tempfile();
    print $fh_r $result;
    unlink $filename_q;
    unlink $filename_t;
    return $filename_r;
}

1;

