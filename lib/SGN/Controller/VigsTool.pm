
package SGN::Controller::VigsTool;

use Moose;

use CXGN::DB::Connection;
use CXGN::BlastDB;
use CXGN::Page::FormattingHelpers qw| page_title_html info_table_html hierarchical_selectboxes_html |;
use CXGN::Page::UserPrefs;


BEGIN { extends 'Catalyst::Controller'; }


sub input :Path('/tools/vigs/')  :Args(0) { 
    my ($self, $c) = @_;
    my $dbh = CXGN::DB::Connection->new;
    our $prefs = CXGN::Page::UserPrefs->new( $dbh );

    # get database ids from a string in the configuration file 
    my @database_ids = split /\s+/, $c->config->{vigs_tool_blast_datasets};

    print STDERR "DATABASE ID: ".join(",", @database_ids)."\n";
    
    # check databases ids exists at SGN
    my @databases;
    foreach my $d (@database_ids) { 
	my $bdb = CXGN::BlastDB->from_id($d);
	if ($bdb) { push @databases, $bdb; }
    }

    $c->stash->{template} = '/tools/vigs/input.mas';
    $c->stash->{databases} = \@databases;    
}

sub upload_file :Path('/tools/vigs/upload/') :Args(0) {
    my $c = shift;
    my $upload = $c->req->upload("expr_file");
    my $expr_file = undef;
    print STDERR "upload: $upload\n";

    if (defined($upload)) {
	$expr_file = $upload->tempname;    
	$expr_file =~ s/\/tmp\///;
    print STDERR "expr file: $expr_file\n";
    
	my $expr_dir = $c->generated_file_uri('expr_files', $expr_file);
	my $final_path = $c->path_to($expr_dir);
    
	write_file($final_path, $upload->slurp);
    }

    print STDERR "expr file: $expr_file\n";

    $c->stash->{expr_file} = $expr_file;
}


1;
