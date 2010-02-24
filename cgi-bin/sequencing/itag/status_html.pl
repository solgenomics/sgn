use strict;
use warnings;

use File::Basename;

use JSON;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw( info_section_html
				      modesel
				      hierarchical_selectboxes_html
				      columnar_table_html
				      info_table_html
				    );
use CXGN::Tools::Identifiers qw/link_identifier/;
use CXGN::ITAG::Pipeline;
use CXGN::Tools::List qw/all/;

use CXGN::VHost;

my $page = CXGN::Page->new('ITAG Pipeline Status Viewer','Robert Buels');
$page->jsan_use('MochiKit.Base','MochiKit.Async');

my ($mode,$pipe,$batch) = $page->get_encoded_arguments('mode','pipe','batch');
if($mode eq 'async') {
  $ENV{CXGNITAGPIPELINEANALYSISTESTING}=1 unless CXGN::VHost->new->get_conf('production_server');
  my $s = get_status($pipe,$batch+0);
  print "Content-type: text/html\n\n$s";
  exit;
} elsif($mode eq 'async_ainfo') {
  my ($aname) = $page->get_encoded_arguments('aname');
  my $ainfo = get_analysis_info($pipe,$aname);
  print "Content-type: text/html\n\n$ainfo";
  exit;
}

$page->header(('ITAG Pipeline Status Viewer') x 2);

#now load styles and javascript specific to this script
print <<EOHTML;
<style>
div#loading_indicator {
  background: red;
  font-weight: bold;
  color: white;
  padding: 0.2em 0.4em 0.2em 0.4em;
  display: inline;
  visibility: hidden;
}

ul.errlist {
  margin-top: 0.1em;
  max-height: 12em;
  overflow: auto;
}
hr.depgroup {
  border: 0;
  border-top: 1px solid black;
}
span.owner {
  white-space: nowrap;
}
span.depends,span.produces, span.tagname, span.owner {
 font-family: monospace;
}
</style>
EOHTML

print <<EOHTML;
<div style="margin-bottom: 1.5em;">This page provides continuously updated information on the running status of the <a href="http://www.ab.wur.nl/TomatoWiki">ITAG Distributed Annotation Pipeline</a>.</div>
EOHTML


my @pipelines = sort {$b <=> $a} CXGN::ITAG::Pipeline->list_pipelines;
print <<EOH
  <table align="center" cellspacing="0" width="100%" ><tr><td style="padding: 0.3em; background: #ccc;">
    <form name="batch_selector">
EOH
      .hierarchical_selectboxes_html(
  				   parentsel => { label => '<b>Pipeline version: </b>',
  						  choices => \@pipelines,
  						  name => 'pipever',
  						  params => {onchange => qq|updateStatusContents()|,
  							    },
						  selected => $pipe,
  						},
  				   childsel => { label => '<b>Batch: </b>',
  						 name => 'batchnum',
  						 params => {onchange => qq|updateStatusContents()|,
  							   },
						 selected => $batch,
  					       },
  				   childchoices => [
  						    map {
  						      my $p = CXGN::ITAG::Pipeline->open(
                                                          version => $_,
                                                          basedir => $c->config->{'CXGN::ITAG'}->{'itag_pipeline_base'},
                                                         );
  						      [sort {$b+0 <=> $a+0} $p->list_batches]
  						    } @pipelines
  						   ],
  				  )
    .<<EOH
    <input type="button" style="background: url(/documents/img/refresh.png)" value="" onclick="this.blur(); updateStatusContents()" />
    <div id="loading_indicator">Loading...</div>
    </form>
  </td></tr>
  <tr><td id="pipestatus_contents" style="border: 2px solid #bbb; padding: 0.5em;">
  </td></tr>
  </table>
EOH
  ;

print <<EOS;
<script type="text/javascript">
  var updateStatusContents = function() {
    var loading_ind = document.getElementById('loading_indicator');

    var pipesel = document.batch_selector.pipever;
    var batchsel = document.batch_selector.batchnum;


    var set_loading = function(is_on) {
      if(is_on) {
        loading_ind.style.visibility = 'visible';
        pipesel.disabled = true;
        batchsel.disabled = true;
      } else {
        loading_ind.style.visibility = 'hidden';
        pipesel.disabled = false;
        batchsel.disabled = false;
      }
    };

    set_loading(true);

    var contentarea = document.getElementById('pipestatus_contents');

    var set = function(req) {
      contentarea.innerHTML = req.responseText;
      set_loading(false);
    };
    var err = function() {
       contentarea.innerHTML = 'Error retrieving pipeline status';
       set_loading(false);
    }
    var res = MochiKit.Async.doSimpleXMLHttpRequest( "status_html.pl",
                                                     { mode: 'async',
                                                       pipe: pipesel.value,
                                                       batch: batchsel.value,
                                                       t: Math.random()
                                                     }
                                                   );
    res.addCallbacks(set,err);

  };

  updateStatusContents();
</script>
EOS

$page->footer;




###################### SUBROUTINES ######################

#given a pipeline version and batch number, return a bunch of html showing its status
sub get_status {
  my ($pipever,$batchnum) = @_;
  my $pipe = CXGN::ITAG::Pipeline->open( version => $pipever,
                                         basedir => $c->config->{'CXGN::ITAG'}->{'itag_pipeline_base'},
                                        );

  my $retstring;
  my $batch = $pipe->batch($batchnum);
  my %errstrings; #< hash of tag name => error message

  my @analyses = map { $pipe->analysis($_) } $pipe->list_analyses;
  my %existing_analyses = map {$_->tagname =>1} @analyses;
  #now sort the analyses by their dependencies
  my @sorted_analyses;
  my %already_processed;
  while( @analyses ) {
    my @ans_this_level;
    foreach my $an (@analyses) {
      next unless $an;
      my @existing_dependencies = grep $existing_analyses{$_}, $an->dependencies;
      if( all @already_processed{ @existing_dependencies } ) {
	push @ans_this_level, $an;
	$an = undef;
      }
    }
    last unless @ans_this_level;
    $already_processed{$_} = 1 foreach map {$_->tagname} @ans_this_level;
    push @sorted_analyses,\@ans_this_level;
  }
  if( my @other_analyses = grep $_,@analyses ) {
    push @sorted_analyses,\@other_analyses;
  }

  #now sorted_analyses is an array like ( [an,an,...], [an,an,...] ),
  #where each set of analyses is dependent on the ones before it

  my $rowcount = 0;
  my $statuses =  columnar_table_html( headings => ['Status','Analysis Tag','Owner','Produces',],
				       __alt_freq => 2,
				      #__align => 'cl',
				       __tableattrs => 'width="100%" summary="" cellspacing="0" align="center"',
				       data =>
				      [
				       map {
					 (($rowcount++) ? ([('<hr class="depgroup" />')x4]) : ()),
					 map {
					   my $an = $_;
					   my $st = $an->status($batchnum);
					   my %t = ( ready => 'inputs ready',
						     not_ready => 'not ready',
						   );
					   my %c = ( ready   => '#6666ff',
						     error   => '#ff0000',
						     done    => '#00ff00',
						     running => '#00ffff',
						     validating => '#dd00dd',
						   );
					   my $c = $c{$st};
					   my $t = $t{$st} || $st;
					   if ($st eq 'error') {
					     my @errors = $an->errors($batchnum);
					     #TODO: MAKE THIS NOT BE SUCH A HACK
					     my $atag = $an->tagname;
					     foreach (@errors) {
					       my ($valname,$filename) = /^(\S+) validation failed for file (\S+),/
						 or next;
					       $_ =~ s|\[report file\]|<a href="report_download.pl?pipe=&batch=$batchnum&atag=$atag&filename=$filename&valname=$valname">report file</a>|;
					     }
					     $errstrings{$atag} = join '',map "<li>$_</li>",@errors;
					     $errstrings{$atag} &&= '<ul class="errlist">'.$errstrings{$atag}.'</ul>';
					   }
					   $st = $c ? qq|<div style="background: $c; padding: 2px 2em 2px 2em;">$t</div>| : $t;
					   my $owner_info = $an->owner_info;
					   my $name = $owner_info->{contact_name};
					   $name .= ',' if $name;
					   $owner_info->{email} = obfuscate_email($owner_info->{email});
					   [ mkspans(
						     status => $st,
						     tagname => $an->tagname,
						     owner => qq|$name $owner_info->{email}|,
						     produces => join(', ', $an->output_files_specs ),
						    )
					   ],
					 } grep {
					   $_->status($batchnum) ne 'disabled'
					 } @$_
				       } @sorted_analyses
				      ],
				     );

  my $errs = do {
    if(%errstrings) {
      info_section_html( title => 'Errors',
			 contents =>
			 join('',
			      map {
				"<b>$_</b>$errstrings{$_}"
			      } sort keys %errstrings
			     ),
			 is_subsection => 1,
		       );
      } else {
	''
      }
  };

  my @seqlist = sort $batch->seqlist;
  my $seqlist_html = join('',
			  '<div style="height: 20em; width: 10em; overflow: auto; border: 1px solid #cccccc; padding: 6px">',
			  ( map {
			      (link_identifier($_)||$_).'<br />'
			    } @seqlist
			  ),
			  '</div>',
			 );
  my $seq_cnt = scalar @seqlist;
  return <<EOH;
<table align="center" style="margin-bottom: 0.5em">
  <tr>
    <td><b>Sequences ($seq_cnt)</b> $seqlist_html</td>
    <td>$statuses</td>
  </tr>
</table>
$errs
EOH
}

########## UTILITY FUNCTIONS

sub obfuscate_email {
  my $email = shift;
  my ($emailuser,$emaildomain) = split /@/, $email;
  $emaildomain =~ s/\./ /g;
  return "$emailuser _ $emaildomain";
}

sub mkspans(@) {
  my @ret;
  while(my ($class,$html) = splice @_,0,2) {
    push @ret,qq|<span class="$class">$html</span>|;
  }
  return @ret;
}
