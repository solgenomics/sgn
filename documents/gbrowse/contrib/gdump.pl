#!/usr/bin/perl

use strict;
use lib '../../lib';
use CGI::Carp qw/fatalsToBrowser/;
use CGI qw/:standard :html3 escape *table *TR *td *pre/;
use Bio::DB::GFF;
use Bio::Graphics::FeatureFile;
use constant CONFIG => '/home4/www/sumo/conf/gbrowse.conf/01.human.conf';

my $data         = Bio::Graphics::FeatureFile->new(-file=>CONFIG) or die "data $!";
my @aggregators  = split /\s+/,$data->setting(general => 'aggregators');
my $seqfactory = Bio::DB::GFF->new(-adaptor => 'dbi::mysqlopt',
				   -user    => 'nobody',
				   -pass    => '',
				   -dsn     => 'dbi:mysql:hg12:host=sumo',
				   -aggregators => \@aggregators,
				  );

# Get info for the possible features
my %fmethod = ();
my @tracks = $data->configured_types;

for my $track (@tracks) {
  next unless $data->setting($track=>'feature') and 
    $data->setting($track=>'key');
  my @low_level_features = split /\s+/,$data->setting($track=>'feature');
  $fmethod{$data->setting($track=>'key')}=\@low_level_features;;
}
my @results;
if(param()){
  if(param('links') and !param('recurse')){

    print header('text/html'),
      '<HTML><HEAD><link rel="stylesheet" type="text/css" href="/style/default.css" /></HEAD><BODY><PRE CLASS="dna">',"\n";
  } elsif(!param('recurse')) { print header('text/plain'); }

  @results = dumper($seqfactory, \%fmethod,  param('recurse'));
  exit unless param('recurse');
}
my $recurse = join "\n",@results;

print header();
print start_html(-style=>{-src=>'/style/default.css'});
print h1("GDump");
&print_HTML(\%fmethod);
exit;

########################### end of program    #################################

sub print_HTML {
my $fmethod = shift;

# HTML form
print start_multipart_form,
  table({-width=>'100%',-cellspacing=>'1', -cellpadding=>'5'},
        TR({-class=>'searchtitle'},
	   th({-width=>'33%'},'1. Sequences to Search'),th({-width =>'33%'},'2. Features'),
	   th({-width =>'33%'},'3. Options')),
        TR({-class=>'searchbody'},
	   td({-align=>'center'},
	      table({-align =>'center'},
		    TR(td({-align=>'LEFT'}, 
			  em('Either'),'choose a pre-defined search:')),
		    TR(td(scrolling_list(-name=>'prefab',
					 -size=>5,
					 -value=>["NONE",
					       "all chromosomes",
					       ],
					 -default=> "NONE",
					),)),
		    TR(td(br,
			  em('Or'),'type in a list of sequence or chromosome names:',
			  br,'e.g.','&nbsp',
			  '"1','&nbsp','X"')),
		    TR(td(textarea(-name=>'list',
				   -rows=>7,
				   -cols=>21,
				   -wrap=>'off',
				   -value=>$recurse,
				   -force=>1
				  ),)),
		    TR(td(
			  br,em('Or'),
			  'upload a file with sequence or chromosome names:')),
		    TR(td(filefield(-size=>20,
				    -name=>'upload'
				   ),)),
		   ) #end mini table
	     ),
	
           td({-align=>'center'},
	      scrolling_list(-name=>'feature',
			     -size=>21,
			     -multiple=>1,
			     -default => ['Gene Models'],
                             -values=>[sort (keys(%$fmethod))])
	     ),

           td(
	      'Dump As:',
	      radio_group(-name=>'dump',
			  -values=>['FastA','Flatfile'],
			  -default=>'FastA'),br,

	      'Compare Features Using:',
	      radio_group(-name=>'logic',
			  -values=>['AND','OR','XOR','NOT'],
			  -default=>'OR'),br,

              'Coordinates Relative to:',
	      radio_group(-name=>'relative',
			  -values=>['Query','Chromosome'],
			  -default=>'Query'),br,
	
              checkbox_group(-name=>'DNA',
			     -values=>['Show DNA'],
			     -default=>['Show DNA']),br
	
	      dd,textfield(-name=>'flank5',
			   -size=>4,
			   -maxlength=>4,
			   -default=>0),'bp 5\' flank',

	      dd,checkbox_group(-name=>'flanked',
				-values=>['feature'],
				-default=>['feature']),
	
	      dd,textfield(-name=>'flank3',
			   -size=>4,-maxlength=>4,
			   -default=>0),'bp 3\' flank',
	      br,

              checkbox_group(-name=>'links',
			     -values=>['As HTML'],
			     -default=>['As HTML']),br,
              checkbox_group(-name=>'verbose',
			     -values=>['Verbose'],
			     -default=>['Verbose']),br,

	      'Match regex: ',textfield(-name=>'grep'),br,
	      checkbox_group(-name=>'recurse',
			     -values=>['Paste']),
	      'results back into <b>Sequences to Search</b> box'
	      )
        ),

        TR({-class =>'searchtitle'},
	   td(reset()),
	   td({-align =>'CENTER',},submit("DUMP")),
	   td("&nbsp")
	  ),

       ),
  endform;
return (\%fmethod);
}

#******************************************************************************
sub dumper {
  my $seqfac  = shift;
  my $fmethod = shift;
  my $return  = shift;

  my $match  = 0;
  my $logic  = param('logic');
  my @features = param('feature');

  #hack for when 'AND' is selected, but there is only one feature selected
  if(scalar(@features) == 1 && $logic eq 'AND'){param(-name=>'logic',-value=>'OR'); dumper($seqfactory); exit;}

  my %features = map{$_=>1} @features;

  #****************************************************************************
  # Get items ......
  my @items;
  if (param('prefab') ne "NONE"){
    my $items = parse_prefab(param('prefab')); @items = @$items;
  } # => param prefab must be none

  elsif (my $fh = param('upload')){   # Use uploaded file
    while(<$fh>){
      @items = split /\s+|\s*,\s*/s, $_;  # split on white sp, or comma
    }
    if (!@items){
      print h2("Error: File must contain sequences that are space or comma delimited.");
      exit;
    }
  } # => param prefab is none, no file uploaded, => check list

  elsif (param('list')) {               # get info from list
    @items = split /\s+/s, param('list');
  }

  if (!@items){
    print h2("Error: no sequences selected! You must choose one of these:",
	     br,"&nbsp"x64,"a) select a pre-defined search",br,
	     "&nbsp"x64,"b) type a list of sequences",br,
	     "&nbsp"x64,"c) upload a file");
    exit;
  }

  #****************************************************************************
  my @returns;
  foreach my $item (@items){
    # foreach chosen seq, get the sequence from Bio::DB::GFF
    my $segment;
    my @prev_returns = @returns;
    if($item =~ /(\w+):(\d+),(\d+)/){
      ($segment) = $seqfac->segment($1 , $2 => $3);
    } else {
      ($segment) = $seqfac->segment($item);
    }
    if (!defined($segment))
      {print h4("Error:  No sequence found for \"$item\""); next;};

    #**************************************************************************
    if($logic eq 'OR' or $logic eq 'AND' or $logic eq 'XOR'){
      foreach my $feature (@features){
	my @get_features = @{$fmethod->{$feature}};
	foreach my $get_feature (@get_features){
	my $iterator = $segment->features(-type=>$get_feature,-iterator=>1);
	while (my $i = $iterator->next_feature) {
	  if($logic eq 'OR'){
	    $match = (param('dump') eq 'FastA') ?
	      asFasta($segment,$i,$return) : asTabbed($segment,$i,$return);
	    push @returns, $match;
	  } 
	  elsif($logic eq 'AND' or $logic eq 'XOR') {
	    my $fstring = join " ", $i->features();
            my $show = 1;
	    my $xor  = 0;
#	    foreach(@get_features){
	    foreach(@features){
	      unless($fstring =~ m!$_!){$show = 0; $xor++;}
	    }
	    if($show and $logic eq 'AND'){
	      $match = (param('dump') eq 'FastA') ? 
		asFasta($segment,$i,$return) : asTabbed($segment,$i,$return);
	      push @returns, $match;
	    } 
	    elsif( !$show and $logic eq 'XOR' and ($xor == $#get_features) ){
	      $match = (param('dump') eq 'FastA') ?
		asFasta($segment,$i,$return) : asTabbed($segment,$i,$return);
	      push @returns, $match;
	    }
	  } # end elsif ($logiv AND or XOR
	} # end while
      } # end of get_features
      } # end foreach $feature
    } # end of if ($logic...)
    elsif($logic eq 'NOT'){
      my $iterator = $segment->features(-iterator=>1);
      while (my $i = $iterator->next_feature) {
	next if $features{$i->method};
	$match = (param('dump') eq 'FastA') ? asFasta($segment,$i,$return)
	  : asTabbed($segment,$i,$return);
	push @returns, $match;
      }
    }
    print h4("No data for $item") if @prev_returns ==@returns;
  } # end of foreach $item

  #****************************************************************************
  # If there are no hits....
  if (!@returns){
    my $print_features = join ", ", @features;
    if ($print_features){
      print h2("Results: No data for any features selected:",$print_features);
    }
    else {print h2("Error: no features selected!!");}
  }
  return @returns if $return;
}# end sub


###############################################################################
sub parse_prefab{
  my $prefab = shift;
  my @items;
  if ($prefab eq 'all chromosomes'){
    @items = qw(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y);
  }
  elsif ($prefab eq "all genes") {
#    @items = $DB->fetch(-query=>'find predicted_gene');
  }
    else {             # for all confirmed genes and all genet. def. genes
#      @items = $prefab eq "all confirmed genes"? $DB->fetch('Gene'=>'*')
#	:$DB->fetch(-query=>'find Sequence Confirmed_by');
    }
  return \@items;
} # end parse prefab


###############################################################################
sub asFasta {
  my ($segment,$feature,$return) = @_;
  $segment->absolute(1) if param('relative') eq 'Chromosome';
  $feature->absolute(1) if ((param('relative') eq 'Chromosome') or $return);

  my $grep    = param('grep') or undef;
  my $dna     = param('DNA')
                ? get_dna($segment,$feature)."\n"
		: undef;
  my $verbose = param('verbose')? $feature->type : undef;
  my $query   = $segment->refseq.':'.$feature->start.','.$feature->stop;
  my $label   = $feature;
#  my $label   = param('links')  ? a({-href=>Object2URL($feature->group->name,$feature->group->class)},$feature)
#                                : $feature;

  my $header = join ' ',(">$query",$label,$verbose,"\n");
  if($grep and param('links')){
    markup(\$dna,$grep,'SPAN','match');
  }

  if($header.$dna =~ /($grep)/gs){
    next unless $1 eq $grep;  #comes out as '/' sometimes... why?
    if($return){
      return $query;
    }
    #this step is SLOW
    justify(\$dna,80);
    print $header.$dna and return $feature;
  }
  return undef;
}# end sub fasta

###############################################################################
sub asTabbed {
  my ($segment,$feature,$return) = @_;
  $segment->absolute(1) if param('relative') eq 'Chromosome';
  $feature->absolute(1) if ((param('relative') eq 'Chromosome') or $return);

  my $grep    = param('grep') or undef;
  my $dna     = param('DNA')
                ? get_dna($segment,$feature)
                : undef;
  my $verbose = param('verbose')? "\t" . $feature->type : undef;
  my $query   = $segment->refseq.':'.$feature->start.','.$feature->stop;
#  my $label   = param('links')  ? a({-href=>Object2URL($feature->group->name,$feature->group->class)},$feature) : $feature;
  my $label   = $feature;

  if($grep and param('links')){
    markup(\$dna,$grep,'SPAN','match');
  }
  my $outstr = join "\t",($query,$label,$verbose,$dna),"\n";

  if($outstr =~ /$grep/gs){
    return $query if $return;
    return undef if $return;
    print $outstr and return $feature;
  }
} # end of sub asTabbed

###############################################################################
sub justify {
  my $dna = shift;
  my $col = shift;

#print b($$dna);

  my ($jdna,$count,$inside);
  for my $i(0..length($$dna)){

    $inside = 1 if(substr($$dna,$i,1) eq '<');
    $inside = 0 if(substr($$dna,$i-1,1) eq '>');
    $count++      unless $inside;

    $jdna .= substr($$dna,$i,1);
    $jdna .= "\n" unless ($count % $col or $inside);
  }
  $$dna = $jdna;
} # end of sub justify

###############################################################################
sub markup {
  my $tmpstr = '---chopped---';
  my ($subject,$grep,$tag,$class) = @_;
  my $c = $class ? " CLASS=\"$class\"" : undef;
  my ($head,$tail) = ("<$tag$c>","</$tag>");

  return undef unless $$subject;
  return undef unless $$subject =~ m!$grep!s;

  #FIND THEM ALL !!!!!!!!!!
  my @greppeds = ();
  while($$subject =~ s!($grep)!$tmpstr!s){push @greppeds,$1;};

  #extract tags;
  my @postpends;
  foreach my $grepped (@greppeds){
    my $postpend = undef;
    while($grepped =~ s!(<.+?>)!!s){my $t = $1; $postpend .= $t;}
    push @postpends, $postpend;
  }

  foreach my $g (@greppeds){
    my $p = shift @postpends;
    $$subject =~ s!(.*?)$tmpstr!$1$head$g$tail$p!s;
  }
  return 1;
}# end of sub markup

###############################################################################
sub get_dna {
  my($segment,$feature) = @_;
  my $flank5 = param('flank5') or 0;
  my $flank3 = param('flank3') or 0;

  $flank5 -- if $flank5 > 0;
  $flank3 -- if $flank3 > 0;

  my $dna5 =$segment->subseq(($feature->start - $flank5),
			     $feature->start)->dna if $flank5;
  $dna5 = '<FONT CLASS="flankm">'.$dna5.'</FONT>' if param('links') and $dna5;
  my $dna3 = $segment->subseq($feature->stop, 
			      ($feature->stop  + $flank3))->dna if $flank3;
  $dna3 = '<FONT CLASS="flankm">'.$dna3.'</FONT>' if param('links') and $dna3;
  my $dnaed   = param('flanked') ? $feature->dna : '-';
  
  return $dna5.$dnaed.$dna3;
}# end of sub get dna
