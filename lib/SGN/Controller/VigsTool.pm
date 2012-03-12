
package SGN::Controller::VigsTool;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

use File::Basename;
use File::Slurp;
use File::Temp qw | tempfile |; 
use POSIX;
use Storable qw | nstore |;
use Tie::UrlEncoder;

use Bio::SeqIO;
use CXGN::Graphics::BlastGraph;
use CXGN::DB::Connection;
use CXGN::BlastDB;
use CXGN::Page::FormattingHelpers qw| page_title_html info_table_html hierarchical_selectboxes_html |;
use CXGN::Page::UserPrefs;
use CXGN::Tools::List qw/evens distinct/;

our %urlencode;

sub input :Path('/tools/vigs/') :Args(0) { 
    my ($self, $c) = @_;
    my $dbh = CXGN::DB::Connection->new;
    our $prefs = CXGN::Page::UserPrefs->new( $dbh );
    
    my ($databases,$programs,$programs_js) = blast_db_prog_selects($c,$prefs);

    $c->stash->{template} = '/tools/vigs/input.mas';

    $c->stash->{databases} = $databases;
    
    $c->stash->{programs} = $programs;
}

# this subroutine is copied exactly from the BLAST index.pl code
#
sub blast_db_prog_selects {
    my ($c,$prefs) = @_;

  sub opt {
    my $db = shift;
    my $timestamp = $db->file_modtime
      or return '';
    $timestamp = strftime(' &nbsp;(%m-%d-%y)',gmtime $db->file_modtime);
    my $seq_count = $db->sequences_count;

    [$db->blast_db_id, $db->title.$timestamp]
  }

  my @db_choices = map {

      print STDERR $c->get_conf('blast_db_path')." ". $_->name ."= ". join (",", $_->blast_dbs( web_interface_visible=>'t'))."\n\n";
    my @dbs = map [$_,opt($_)], grep $_->file_modtime, $_->blast_dbs( web_interface_visible => 't');

    @dbs || print STDERR "No databases available...". $_->name."\n";
    @dbs ? ('__'.$_->name, @dbs) : ()
  } CXGN::BlastDB::Group->search_like(name => '%',{order_by => 'ordinal, name'});

  my @ungrouped_dbs = grep $_->file_modtime,CXGN::BlastDB->search( blast_db_group_id => undef, web_interface_visible => 't', {order_by => 'title'} );
  if(@ungrouped_dbs) {
    push @db_choices, '__Other',  map [$_,opt($_)], @ungrouped_dbs;
  }

  @db_choices or return '<span class="ghosted">The BLAST service is temporarily unavailable, we apologize for the inconvenience</span>';

  my $selected_db_file_base = $prefs->get_pref('last_blast_db_file_base');
  #warn "got pref last_blast_db_file_base '$selected_db_file_base'\n";

  my %prog_descs = ( blastn  => 'BLASTN (nucleotide to nucleotide)',
		     blastx  => 'BLASTX (nucleotide to protein; query translated to protein)',
		     blastp  => 'BLASTP (protein to protein)',
		     tblastx => 'TBLASTX (protein to protein; both database and query are translated)',
		     tblastn => 'TBLASTN (protein to nucleotide; database translated to protein)',
		   );

  my @program_choices = map {
    my ($db) = @$_;
    if($db->type eq 'protein') {
      [map [$_,$prog_descs{$_}], 'blastx','blastp']
    } else {
      [map [$_,$prog_descs{$_}], 'blastn','tblastx','tblastn']
    }
  } grep ref, @db_choices;

  @db_choices = map {ref($_) ? $_->[1] : $_} @db_choices;

  return hierarchical_selectboxes_html( parentsel => { name => 'database',
						       choices =>
						       \@db_choices,
						       $selected_db_file_base ? (selected => $selected_db_file_base) : (),
						     },
					childsel  => { name => 'program',
						     },
					childchoices => \@program_choices
				      );
}



sub calculate :Path('/tools/vigs/result') :Args(0) { 
    my ($self, $c) = @_;

    my $seq_count = 0;
    
    my @errors; #to store erros as they happen


    my $params = $c->req->body_params();

#     print STDERR "PARAMETERS: \n";
#     foreach my $k (keys(%$params)) { 
# 	print STDERR "$k: $params->{$k}\n";
#     }

    # processing the primers 
    #
#    my $min_primer_length = 15;
    
    my $sequence = $c->req->param("sequence");
    my $fragment_size = $c->req->param("fragment_size");
    
    if (!$fragment_size) { 
	push @errors, "Fragment size ($fragment_size) should be greater than zero (~20 - 40 bp)\n";
    }

    #validating the primers input
    if (length($sequence) <= $fragment_size ){
	push ( @errors , "Sequence should be at least $fragment_size in length.\n");
    }
    
    # clean sequence 
    $sequence =~ s/[^a-zA-Z]//g;
    
    if (scalar (@errors) > 0){
	user_error(join("<br />" , @errors));
    }
    
    my %arg_handlers =
	(
	 
	 sequence=>
	 sub {

	     # generate a file with fragments of 'sequence' of length 'fragment_size'
	     #
	     my ($seq_fh, $seq_filename) = tempfile( "seqXXXXXX",
						     DIR=> $c->config->{'cluster_shared_tempdir'},
		 );
	     
	     
	     my $seq = Bio::Seq->new(-seq=>$sequence, -id=>"temp");
	     my $io = Bio::SeqIO->new(-format=>'fasta', -file=>">".$seq_filename);
	     
	     #foreach my $i (1..$seq->length()-$fragment_size) { 
		 
	#	 my $subseq = $seq->subseq($i, $i + $fragment_size -1);
	#	 my $subseq_obj = Bio::Seq->new(-seq=>$subseq, -display_id=>"temp-$i");
	#	 $io->write_seq($subseq_obj);
		 
	#     }
	#     $io->close();
	     $io->write_seq($seq);
	     $io->close();

	     return "-i" => $seq_filename;
	     
# 	     my $sequence = $blast_seq_in;
# 	     #$sequence =s/^\s+|\s+$|\n\s*\n//g;
	     
# 	     #make a tempfile that has our sequence(s) in it
# 	     my ($seq_fh, $seq_filename) = tempfile( "seqXXXXXX",
# 						     DIR=> $c->config->{'cluster_shared_tempdir'},
# 		 );
# 	     print $seq_fh $sequence;
	     
	     
	     
	     
# 	     if(my $file_upload = $page->get_upload) {
# 		 if ( my $fh = $file_upload->fh ) {
# 		     print $seq_fh $_ while <$fh>;
# 		 }
# 	     }
	     
# 	     seek $seq_fh,0,0; #< rewind the filehandle
# 	     #count the number of seqs in the file
# 	     while(<$seq_fh>) {
# 		 $seq_count++ if index($_,'>') != -1;
# 	     }
	     
	     
# 	     return -i => $seq_filename
	 },

	 matrix =>
	 sub {
	     $params->{matrix} =~ /^BLOSUM\d\d$/ || $params->{matrix} =~ /^PAM\d\d$/
		 or die "invalid matrix '$params->{matrix}'";
	     return -M => $params->{matrix}
	 },
	 
	 expect =>
	 sub {
	     $params->{expect} =~ s/[^\d\.e\-\+]//gi; #can only be these characters
	     return -e => $params->{expect} || 1
	 },
	 
	 filterq =>
	 sub {
	     return -F => $params->{filterq} ? 'T' : 'F'
	 },
	 
	 outformat =>
	 sub {
	     $params->{outformat} =~ s/\D//g; #only digits allowed
	     return -m => $params->{outformat}
	 },
	 
	 database =>
	 sub {
	     #my ($bdb) = CXGN::BlastDB->search( file_base => $params{database} )
	     
	     #or die "could not find bdb with file_base '$params{database}'";
	     
	     #     warn "setting pref last_blast_db_fil
	     #database object for specific ID_No
	     
	     my $bdb = CXGN::BlastDB->from_id($params->{database});
	     print STDERR "\n\n\n".$bdb->dbpath()."\n\n\n";
	     my $basename = $bdb->full_file_basename;
	     
	     #return "-d" => $c->config->{blastdb_location}."/".$params{database};
	     
             #return '/data/shared/blast/databases/genbank/nr';
	     #remember the file_base the user just blasted with
	     
	     #return -d => $basename;
	     return -d => '/data/shared_local/blast/databases/tomato_genome/Slycopersicum_wgs_scaffolds_prerelease';
	 },

	 program =>
	 sub {
	     $params->{program} =~ s/[^a-z]//g; #only lower-case letters
	     return -p => $params->{program}
	 },
	 
	);
    
    # get all the params from our request
    #
    my (undef) = $c->request->upload('file');
#     foreach my $k (keys %arg_handlers) { 
# 	@params{$k} = $c->request->param($k);
#     }

    # Build our command with our arg handlers
    my @command =
	( 'blastall',
	  map $_->(), values %arg_handlers
	);
    

    # now run the blast
    #
    my $job = CXGN::Tools::Run->run_cluster(@command,
					    { temp_base => $c->config->{'cluster_shared_tempdir'},
					      queue => $c->config->{'web_cluster_queue'},
					      working_dir => $c->config->{'cluster_shared_tempdir'},
					      # don't block and wait if the cluster looks full
					      max_cluster_jobs => 1_000_000_000,
					    }
	);
#$job->do_not_cleanup(1);
    
    my $job_file_tempdir = $c->path_to( $c->tempfiles_subdir('blast') );
    my (undef,$job_file) = tempfile( DIR => $job_file_tempdir, TEMPLATE=>"object_XXXXXX");
    
    nstore($job, $job_file)
	or die 'could not serialize job object';
    
    my $job_file_base = basename($job_file);
    
# url encode the destination pass_back page.
#delete $params{sequence};
    
    my $pass_back = "/tools/vigs/view?".
	hash2param(%$params, seq_count => $seq_count, 
		   "report_file");
#$pass_back =~ s/&/&amp;/g;
    
    my $redir_url = "../wait.pl?tmp_app_dir=/blast&job_file=$job_file_base&redirect=$urlencode{$pass_back}";
    
#warn "redirecting to '$redir_url'";
    
    $c->response->redirect($redir_url);  # should be fully qualified URL -- fix.
    
    
}


sub user_error {
    my ($reason) = @_;
    
    print <<EOF;
    
    <h4>In Silico PCR Interface Error</h4>
	
	<p>$reason</p>
EOF

return;

}

sub hash2param {
  my %args = @_;
  return join '&', map "$urlencode{$_}=$urlencode{$args{$_}}", distinct evens @_;
}

sub view :Path('/tools/vigs/view') :Args(0) { 
    my ($self, $c) = @_;

    


    $c->stash->{template} = '/tools/vigs/view.mas';
    my $job_file_tempdir = $c->path_to( $c->tempfiles_subdir('blast') );
    my $file = $c->request->param('report_file');
    my $fragment_size = $c->request->param('fragment_size');
    
    open(my $F, "<", $job_file_tempdir."/".$file) || die "Can't open file $file.";
    my %matches;
    my @queries = ();;
    
    

#####################

    #graph variables for just Evan's graph package
    my $graph_img_filename = $c->tempname() . ".png";

    my $tempfiles_subdir = $c->{config}->{tempfiles_subdir};

    my $graph2 = CXGN::Graphics::BlastGraph->new( blast_outfile => $file,
                                                graph_outfile => $tempfiles_subdir."/$graph_img_filename",
                                              );

    return 'graphical display not available BLAST reports larger than 1 MB' if -s $file > 1_000_000;
    
    my $errstr = $graph2->write_img();
    $errstr and die "<b>ERROR:</b> $errstr";
    
    
    return join '',
    ( <<EOH,
      <center><b>Conservedness Histogram</b></center>
      <p>The histogram shows a count of hits <i>for each base</i> in the query sequence,
but counts <i>only the domains BLAST finds</i>, meaning this is really more a function of region than of individual base.
      Within the graph, green shows exact base matches within conserved regions; blue shows non-matching bases within conserved regions. Gaps introduced into the query by BLAST are ignored; gaps introduced into target sequences are not.</p>

EOH

      $graph2->get_map_html(), #code for map element (should have the name used below in the image)
      qq|<div align="center" style="color: #777777">|,
      qq|<img src="$tempfiles_subdir/$graph_img_filename" border="2" usemap="#graph2map" alt="" />|,
      qq|</div>\n\n|,
    );





#     my $old_query = "";
#     while (<$F>) { 
# 	chomp;
# 	my ($query, $subject, $percent, $length, $mismatches, $gaps) = split/\t/;
# 	if (($percent == 100) && ($length == $fragment_size)) { 
# 	    $matches{$query}++;
# 	}
# 	if ($query ne $old_query) { push @queries, $query; }
# 	$old_query = $query;
#     }
#     my @blast_results = ();
#     for (my $i=0; $i<@queries; $i++) { 
# 	push @blast_results, [$i, $matches{$queries[$i]} ];
#     }

    ## Create rbase:

# my $rbase = R::YapRI::Base->new();

# ## Create the data matrix

# my $ymatrix = R::YapRI::Data::Matrix->new({
# name     => 'data1',
# coln     => 2,
#     rown     => scalar(@queries), 
#     colnames => [ @queries ],
#     rownames => ['X', 'Y'],
#     data     => [ @queries ],
#   });

#   ## Create the graph with the graph arguments, a barplot with two series (rows)
#   ## of data per group (cols).

#     my $rgraph = R::YapRI::Graph::Simple->new({
# 	rbase  => $rbase,
# 	rdata  => { height => $ymatrix },
# 	grfile => "MyFile.bmp",
# 	device => { bmp => { width => 600, height => 600 } },
# 	sgraph => { barplot => { beside => 'TRUE',
# 				 main   => 'MyTitle',
# 				 xlab   => 'x_axis_label',
# 				 ylab   => 'y_axis_label',
# 				 col    => ["dark red", "dark blue"],
# 		    } 
# 	},
# 					      });
    
#     $rgraph->build_graph('GRAPHBLOCK1');
#     my ($graphfile, $resultfile) = $rgraph->run_graph()
	
	
# 	$c->stash->{blast_results} = \@blast_results;
    
}

1;
