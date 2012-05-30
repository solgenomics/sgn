
package SGN::Controller::VigsTool;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

use File::Basename;
use File::Slurp;
use File::Spec;
use File::Temp qw | tempfile |; 
use POSIX;
use Storable qw | nstore |;
use Tie::UrlEncoder;

use Bio::SeqIO;
use CXGN::Graphics::BlastGraph;
use CXGN::Graphics::VigsGraph;
use CXGN::DB::Connection;
use CXGN::BlastDB;
use CXGN::Page::FormattingHelpers qw| page_title_html info_table_html hierarchical_selectboxes_html |;
use CXGN::Page::UserPrefs;
use CXGN::Tools::List qw/evens distinct/;

our %urlencode;

sub input :Path('/tools/vigs/')  :Args(0) { 
    my ($self, $c) = @_;
    my $dbh = CXGN::DB::Connection->new;
    our $prefs = CXGN::Page::UserPrefs->new( $dbh );


    my @database_ids = split /\s+/, $c->config->{vigs_tool_blast_datasets};

    print STDERR "DATABASE ID: ".join(",", @database_ids)."\n";
    
    my @databases;
    foreach my $d (@database_ids) { 

	my $bdb = CXGN::BlastDB->from_id($d);
	if ($bdb) { push @databases, $bdb; }
    }

    $c->stash->{template} = '/tools/vigs/input.mas';

    $c->stash->{databases} = \@databases;
    
}

sub advanced :Path('/tools/vigs/advanced') :Args(0) { 
    my ($self, $c) = @_;
    my $dbh = CXGN::DB::Connection->new;
    our $prefs = CXGN::Page::UserPrefs->new( $dbh );
    
    my ($databases,$programs,$programs_js) = blast_db_prog_selects($c,$prefs);

    $c->stash->{template} = '/tools/vigs/advanced.mas';

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
	my @web_visible = $_->blast_dbs( web_interface_visible=>'t');
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

    # processing the primers 
    #
#    my $min_primer_length = 15;
    
    my $sequence = $c->req->param("sequence");
    my $fragment_size = $c->req->param("fragment_size");
    
    if (!$fragment_size) { 
	push @errors, "Fragment size ($fragment_size) should be greater than zero (~20 - 40 bp)\n";
    }


    if (length($sequence) <= $fragment_size ){
	push ( @errors , "Sequence should be at least $fragment_size in length.\n");
    }
    
    # clean sequence 
    $sequence =~ s/^>(.*)\s?\n(.*)/$2/; # remove first fasta line
    my $id = $1;
    $sequence =~ s/[^a-zA-Z]//g;
    
    if (scalar (@errors) > 0){
	user_error(join("<br />" , @errors));
    }

    # generate a file with fragments of 'sequence' of length 'fragment_size'
    # for analysis with BWA.
    my ($seq_fh, $seq_filename) = tempfile( "vigsXXXXXX",
                 DIR=> $c->config->{'cluster_shared_tempdir'},
     );

    
    my $query = Bio::Seq->new(-seq=>$sequence, -id=> $id || "temp");

    my $io = Bio::SeqIO->new(-format=>'fasta', -file=>">".$seq_filename.".fragments");
    
    foreach my $i (1..$query->length()-$fragment_size) { 
	
	my $subseq = $query->subseq($i, $i + $fragment_size -1);

	my $subseq_obj = Bio::Seq->new(-seq=>$subseq, -display_id=>"temp-$i");
	
	$io->write_seq($subseq_obj);
	
    }

    $c->stash->{query} = $query;
    
    $io->close();


    print STDERR "DATABASE SELECTED: $params->{database}\n";
    my $bdb = CXGN::BlastDB->from_id($params->{database});

    my $basename = $bdb->full_file_basename;
    print STDERR "\n\n\n".$bdb->dbpath()." - ".$basename." Outputfile: $seq_filename.bwa.out\n\n\n";    

    my $err = system('/data/shared/bin/bwa_wrapper.sh', $basename, $seq_filename.".fragments", $seq_filename.".bwa.out");

    print STDERR "SYSTEM CALL RETURN CODE: $err\n";
    my $query_file = $seq_filename;
     my $seq = Bio::Seq->new(-seq=>$sequence, -id=> $id || "temp");
     $io = Bio::SeqIO->new(-format=>'fasta', -file=>">".$query_file);
    
     $io->write_seq($seq);
     $io->close();

    if (! -e $query_file) { die "Query file failed to be created."; }


   my $file = $c->request->param('report_file');
 #   my $fragment_size = $c->request->param('fragment_size');
#    my $query_file = $c->request->param('query_file');
    my $seq_window_size = $c->request->param('seq_window_size') || 300;

    $c->stash->{query_file} = $query_file;

   $seq_filename =~ s/\%2F/\//g;

    $c->stash->{template} = '/tools/vigs/view.mas';
    my $job_file_tempdir = $c->path_to( $c->tempfiles_subdir('blast') );
    
#    open(my $F, "<", $job_file_tempdir."/".$file) || die "Can't open file $file.";
    my %matches;
    my @queries = ();
    
    #graph variables for just Evan's graph package
    my $graph_img_filename = basename($c->tempfile(TEMPLATE=>'imgXXXXXX', UNLINK=>0) . ".png");
    my $graph_img_path = File::Spec->catfile($c->config->{basepath}, $c->tempfiles_subdir('vigs'), $graph_img_filename);
    my $graph_img_url  = File::Spec->catfile($c->tempfiles_subdir('vigs'), $graph_img_filename);

    my $raw_blast_path = File::Spec->catfile($job_file_tempdir, $file);
    my $raw_blast_url  = File::Spec->catfile($c->tempfiles_subdir('blast'), $file);
    

    #print STDERR "TEMP FILE PATH FOR PNG = $graph_img_path\n";
    #print STDERR "RAW BLAST PATH = $raw_blast_path\n";

    my $vg = CXGN::Graphics::VigsGraph->new();
    $vg->bwafile($seq_filename.".bwa.out");
    $vg->fragment_size($fragment_size);
    $vg->query_seq($query->seq());
    $vg->seq_window_size($seq_window_size);
    $vg->parse();    
    $vg->render($graph_img_path);

    my $errstr;
    my @regions;

    $errstr and die "<b>ERROR:</b> $errstr";
    
    $c->stash->{regions} = \@regions;

    $c->stash->{graph_url} = $graph_img_url;

   my @bwa_matches = `cut -f3 $seq_filename.bwa.out | sort -u`;

    $c->stash->{blast_matches} = \@bwa_matches;
    $c->stash->{fragment_size} = $fragment_size;

   
    
}



sub user_error {
    my ($reason) = @_;
    
    print <<EOF;
    
    <h4>VIGS Tool Error</h4>
	
	<p>$reason</p>
EOF

return;

}

sub hash2param {
  my %args = @_;
  return join '&', map "$urlencode{$_}=$urlencode{$args{$_}}", distinct evens @_;
}


1;
