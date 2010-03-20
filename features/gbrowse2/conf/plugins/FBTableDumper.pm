package Bio::Graphics::Browser2::Plugin::FBTableDumper;
# FBTableDumper.pm v1 2006 V.Strelets at FlyBase.org
# derived from GFFDumper by L.Stein
use strict;
use Bio::Graphics::Browser2::Plugin;
use CGI qw(:standard *sup);

use vars '$VERSION','@ISA';
$VERSION = '0.80';

@ISA = qw/ Bio::Graphics::Browser2::Plugin /;

sub name { "HTML table view" }
sub description {
  p("FlyBase table view dumper");
}

sub config_defaults {
  my $self = shift;
  return { 
	  version     => 2,
	  mode        => 'selected',
	  disposition => 'view',
	  coords      => 'absolute',
	 };
}

sub reconfigure {
  my $self = shift;
  my $current_config = $self->configuration;
  foreach my $p ( $self->config_param() ) {
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
	       '&nbsp; features');
  autoEscape(1);


  $html;
}

sub mime_type {
  my $self   = shift;
  return 'text/html';
}


sub dump {
  my $self = shift;
  my ($segment, @more_feature_sets) = @_;
  my $page_settings = $self->page_settings;
  my $conf          = $self->browser_config;
  my $config        = $self->configuration;
  my $version       = $config->{version} || 3;
  my $mode          = $config->{mode}    || 'selected';
  my $db            = $self->database;
  my $whole_segment = $db->segment(Accession => $segment->ref) ||
                      $db->segment($segment->ref);
  my $coords        = $config->{coords};
  $segment->refseq($segment) if $coords eq 'relative';
  my $date = localtime;
  print "## FlyBase table view dump<br>\n";
  print "## date $date<br>\n";
  print "## sequence-region ",join(' ',$segment->ref,$segment->start,$segment->stop),"<br>\n";
  print '<TABLE BORDER="0"><TR bgcolor="goldenrod"><TH>Seq.location</TH><TH>Symbol/Name/ID</TH><TH>Note(s)</TH></TR>';
  my $iterator = $segment->get_seq_stream();
  my %Out= ();
  while ( my $f = $iterator->next_seq ) {
    my $s = $f->gff_string(1); # the flag is for GFF3 subfeature recursion
    chomp $s;
    my($ref,$source,$method,$start,$stop,$score,$strand,$phase,$note) = split(/[\t]+/,$s);
    my $id= ($note=~/ID=([^;]+)/i) ? $1 : '-';
    next if( $id eq '-' );
    next if( $note=~/Parent=/i );
    my $name= ($note=~/Name=([^;]+)/i) ? $1 : $id;
    if($note=~/Symbol=([^,;]+)/i) { $name.= ' '.$1; }
    my $key= $source.':'.$method;
    if( exists $Out{$key} ) { $Out{$key}.= "\t"; } 
    $Out{$key}.= '<TD align=left><small> '.$ref.':'.$start.'..'.$stop.'['.$strand.'] </small></TD>';
    if( $id=~/^FB[a-z]{2}\d+$/ ) { 
      $name= '<A HREF="http://flybase.org/cgi-bin/fbidq.html?'.$id.'">'.$name.'</A>'; 
      }
    $Out{$key}.= '<TD><small> '.$name.' </small></TD>';
    $note=~s/(\S);(\S)/$1; $2/g;
    $Out{$key}.= '<TD align=left><small> '.$note.' </small></TD>';
    }
  foreach my $key ( sort keys %Out ) {
    my($source,$method)= split(":",$key);
    print '<TR><TD colspan=3 bgcolor="#DCDDDC" align=left> '.$source.':<B>'.$method."</B></TD></TR>\n";
    my @strs= split("\t",$Out{$key});
    foreach( @strs ) { print '<TR align=left valign=top>'.$_."</TR>\n"; }
    }
  print "</TABLE>\n";
  return;  
}


1;

