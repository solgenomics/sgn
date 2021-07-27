
=head1 NAME

  /bulk/display.pl

=head1 DESCRIPTION

  This perl script is used on the bulk download page. It determines the format
  of the data given back to the user (submitted to download.pl). This includes
  the format of the the html pages that display the data as well as determining
  the fasta format and the text format.

=cut

package SGN::Controller::Bulk::Display;

use Moose;

use Cache::File;
use File::Spec::Functions;
use File::Slurp qw | read_file |;
use CXGN::Page::FormattingHelpers qw | html_break_string |;
BEGIN { extends 'Catalyst::Controller' };

=head2 display_page

  Desc: sub display_page
  Args: default
  Ret : page

  Calls summary page to be displayed. Determines what page to render depending
  on the outout type the user selects.

=cut

sub display_page : Path('/tools/bulk/display') :Args(0) {
    my $self = shift;
    my $c = shift;

    # define some constants
    $self->{pagesize} = 50;
    $self->{content}  = "";
    $self->{tempdir} = $c->path_to( $c->tempfiles_subdir('bulk') );

    # get cgi arguments
    $self->{dumpfile}    = $c->req->param("dumpfile");
    $self->{page_number} = $c->req->param("page_number") || 1;
    $self->{page_size}   = $c->req->param("page_size");
    $self->{outputType}  = $c->req->param("outputType");
    $self->{seq_type}    = $c->req->param("seq_type");
    $self->{idType}      = $c->req->param("idType");
    $self->{summary}     = $c->req->param("summary");
    $self->{download}    = $c->req->param("download");
    $self->{lines_read}  = $c->req->param("lines_read");
    $self->{outputType}  = $c->req->param("outputType");
    $self->{unigene_seq} = $c->req->param("unigene_seq");
    $self->{est_seq}     = $c->req->param("est_seq");

    $c->stash->{summary_data} = { 
	dumpfile => $self->{dumpfile},

	tempdir => $c->path_to($c->tempfiles_subdir("bulk")),
	page_number => $self->{page_number},
	page_size => $self->{page_size},
	outputType => $self->{outputType},
	seq_type => $self->{seq_type},
	idType => $self->{idType},
	summary => $self->{summary},
	download => $self->{download},
	lines_read => $self->{lines_read},
	outputType => $self->{outputType},
    };
    $c->stash->{data} = $c->stash->{summary_data};
    # if summary switch is set, display summary page
    if ( $self->{summary} ) {

	$c->stash->{template} = '/tools/bulk/display/summary_page.mas';
	return;
    }

    elsif ( $self->{outputType} =~ /html/i ) {
        #$self->render_html_table_page();
	$c->stash->{template} = '/tools/bulk/display/browse_html.mas';
    }
    elsif ( $self->{outputType} =~ /text/i ) {
        $self->render_text_page($c);
    }
    elsif ( $self->{outputType} =~ /fasta/i ) {
        $self->render_fasta_page($c);
    }
    elsif ( $self->{outputType} =~ /notfound/i ) {
        $self->display_ids_notfound($c);
    }
    else { 
	#$c->stash->{template} = '/tools/bulk/display/browse_html.mas';
	die "NEED OUTPUT TYPE";
    }
}

=head2 display_summary_page

  Desc: sub display_summary_page
  Args: default
  Ret : n/a

  Opens temp file created in download.pl then opens a filehandle and prints the
  data to that file.

=cut

sub display_summary_page : Path('/tools/bulk/summary') Args(1){
    my $self = shift;
    my $c = shift;
    my $dumpfile = shift;

    print STDERR "DUMPFILE = $dumpfile\n";
    my $cache_root = catfile($c->config->{basepath}, $c->tempfiles_subdir("bulk"), $dumpfile.".summary");;
    print STDERR "CACHE_ROOT: $cache_root\n";
    my $cache = Cache::File->new( cache_root =>$cache_root);

    my $summary_data = {};
    foreach my $k (qw | fastalink fastadownload fastamessage missing_ids_message file total query_time filesize numlines lines_read idType |) {
	$summary_data->{$k} = $cache->get($k);
	
    }
    $c->stash->{summary_data} = $summary_data;
    $c->stash->{template} = '/tools/bulk/display/summary_page.mas';

}


=head2 render_fasta_page

  Desc: sub render_fasta_page
  Args: default
  Ret : n/a

  Determines the format of the fasta page (in a similar way as
  render_html_table_page). No trailing spaces or new lines should be present
  after this subroutine is called for fasta pages.

=cut

sub render_fasta_page {
    my $self = shift;
    my $c = shift;

    my $fasta = "";

    open( F, "< :encoding(UTF-8)" . $self->{tempdir} . "/" . $self->{dumpfile} )
      || $self->{page}->error_page( "Can't open " . $self->{dumpfile} );

    # read column definitions
    my @output_fields;
    my $defs = <F>;
    if ($defs) { chomp($defs); @output_fields = split /\t/, $defs; }

    while (<F>) {
        chomp;
        my @f    = split /\t/;

        #convert to hash
        for ( my $i = 0 ; $i < @output_fields ; $i++ ) {
            $self->{ $output_fields[$i] } = $f[$i];
        }
        if ( ( join " ", @output_fields ) =~ /est_seq/i ) {
            $self->{seq_type} = "est_seq";
        }
        elsif ( ( join " ", @output_fields ) =~ /unigene_seq/i ) {
            $self->{seq_type} = "unigene_seq";
        }
        elsif ( ( join " ", @output_fields ) =~ /^protein_seq$/i ) {
            $self->{seq_type} = "protein_seq";
        }    #added for protein
        elsif ( ( join " ", @output_fields ) =~ /estscan_seq/i ) {
            $self->{seq_type} = "estscan_seq";
        }
        elsif ( ( join " ", @output_fields ) =~ /longest6frame_seq/i ) {
            $self->{seq_type} = "longest6frame_seq";
        }
        elsif ( ( join " ", @output_fields ) =~ /preferred_protein_seq/i ) {
            $self->{seq_type} = "preferred_protein_seq";
        }

        my $breakspace_num = 60;

        my $seq = "";
        # quality values
        my $qual = "";
        if ( $self->{qual_value_seq} ) {
            $qual = $self->{qual_value_seq};
        }
        else {
            $self->{qual_value_seq} = "";
        }
        my @qual = split /\s+/, $qual;
        $self->{qual_value_seq} = "\n";
        while ( my @a = splice( @qual, 0, $breakspace_num ) ) {
            $self->{qual_value_seq} .= join( " ", @a ) . "\n";
        }
        if ( $self->{qual_value_seq} ) {
            $seq = $self->{qual_value_seq};
            $self->{qual_value_seq} = "";
        }

        # bac end sequences
        # only print sequence if both quality value and sequence selected
        if ( $self->{bac_end_sequence} ) {
            $seq = "\n"
              . html_break_string( $self->{bac_end_sequence}, $breakspace_num,
                "\n" )
              . "\n";
            $self->{bac_end_sequence} = "";
        }
        else {
            $self->{bac_end_sequence} = "";
        }

        # est vs. unigene seq
        $self->{est_seq} =
          html_break_string( $self->{est_seq}, $breakspace_num, "\n" )
          if defined( $self->{est_seq} );
        $self->{unigene_seq} =
          html_break_string( $self->{unigene_seq}, $breakspace_num, "\n" )
          if defined( $self->{unigene_seq} );
        $self->{protein_seq} =
          html_break_string( $self->{protein_seq}, $breakspace_num, "\n" )
          if defined( $self->{protein_seq} );
        $self->{estscan_seq} =
          html_break_string( $self->{estscan_seq}, $breakspace_num, "\n" )
          if defined( $self->{estscan_seq} );
        $self->{longest6frame_seq} =
          html_break_string( $self->{longest6frame_seq}, $breakspace_num, "\n" )
          if defined( $self->{longest6frame_seq} );
        $self->{preferred_protein_seq} =
          html_break_string( $self->{preferred_protein_seq},
            $breakspace_num, "\n" )
          if defined( $self->{preferred_protein_seq} );

        if ( $self->{seq_type} eq "est_seq" ) {
            $seq = "\n" . $self->{est_seq} . "\n";
            warn "NOTE: est sequence given, seq_type: "
              . $self->{seq_type} . "\n";
            $self->{est_seq} = "";
        }
        elsif ( $self->{seq_type} eq "unigene_seq" ) {
            $seq = "\n" . $self->{unigene_seq} . "\n";
            warn "NOTE: unigene sequence given, seq_type: "
              . $self->{seq_type} . "\n";
            $self->{unigene_seq} = "";
        }

        #added for protein
        elsif ( $self->{seq_type} eq "protein_seq" ) {
            $seq = "\n" . $self->{protein_seq} . "\n";
            warn "NOTE: protein sequence given, seq_type: "
              . $self->{seq_type} . "\n";
            $self->{protein_seq} = "";
        }
        elsif ( $self->{seq_type} eq "estscan_seq" ) {
            $seq = "\n" . $self->{estscan_seq} . "\n";
            $self->{estscan_seq} = "";
        }
        elsif ( $self->{seq_type} eq "preferred_protein_seq" ) {
            $seq = "\n" . $self->{preferred_protein_seq} . "\n";
            $self->{preferred_protein_seq} = "";
        }
        elsif ( $self->{seq_type} eq "longest6frame_seq" ) {
            $seq = "\n" . $self->{longest6frame_seq} . "\n";
            $self->{longest6frame_seq} = "";
        }

        # output
        my $output = "";
        foreach my $o (@output_fields) {
            if ( exists( $self->{$o} ) && $self->{$o} ne "" ) {
                $output .= "$o:$self->{$o}\t";
            }
        }

        s/ +/ /g foreach ( $output . $seq );
        $output =~ s/.*?\://
          ; # remove the first label (>SGN_U:SGN_U738473 becomes simply >SGN_U738473)

        $fasta .= ">$output$seq";    # do not add new lines to this string

    }
    close(F);

    # print header
    #
    if ( $self->{download} ) {
	$c->res->content_type("application/data");
	$c->res->headers()->header("Content-Disposition: filename=sgn_bulk_download.fasta");
    }
    else {
        $c->res->content_type("text/plain");
    }
    $c->res->body($fasta);


}

=head2 buttons

  Desc: sub buttons
  Args: default
  Ret : n/a

  Calls subtroutines for buttons that will display on the html display pages.

=cut

sub buttons {
    my $self  = shift;
    my $pages = ( int( $self->{line_count} / $self->{page_size} ) ) + 1;
    $self->{content} .= "<br />Page" . $self->{page_number} . " of $pages | ";
    $self->previousButton();
    $self->{content} .= " | ";
    $self->summaryButton();
    $self->{content} .= " | ";
    $self->newSearchButton();
    $self->{content} .= " | ";
    $self->nextButton();
    $self->{content} .= "<br /><br />";
}

=head2 nextButtons

  Desc: sub nextButtons
  Args: default
  Ret : n/a

  Determines the next button that will display on the html display pages.

=cut

sub nextButton {
    my $self = shift;

    # add next page button if there is a next page
    if ( ( $self->{line_count} + $self->{page_size} ) >
        ( ( $self->{page_number} + 1 ) * $self->{page_size} ) )
    {
        $self->{content} .=
            "<a href=\"display.pl?dumpfile="
          . ( $self->{dumpfile} )
          . "&amp;page_number="
          . ( $self->{page_number} + 1 )
          . "\">Next Page</a>";
    }
    else {
        $self->{content} .= "Next Page";
    }
}

=head2 previousButtons

  Desc: sub previousButtons
  Args: default
  Ret : n/a

  Determines the previous button that will display on the html display pages.

=cut

sub previousButton {
    my $self = shift;
    if ( ( $self->{page_number} - 1 ) > 0 ) {
        $self->{content} .=
            "<a href=\"display.pl?dumpfile="
          . ( $self->{dumpfile} )
          . "&amp;page_number="
          . ( $self->{page_number} - 1 )
          . "\">Previous Page</a>";
    }
    else {
        $self->{content} .= "Previous Page";
    }
}

=head2 summaryButtons

  Desc: sub summaryButtons
  Args: default
  Ret : n/a

  Determines the summary button that will display on the html display pages.

=cut

sub summaryButton {
    my $self = shift;
    $self->{content} .=
        "<a href=\"/tools/bulk/display?summary=1&amp;dumpfile="
      . ( $self->{dumpfile} )
      . "&amp;idType="
      . ( $self->{idType} )
      . "\">Summary Page</a>";
}

=head2 newSearchButtons

  Desc: sub newSearchButtons
  Args: default
  Ret : n/a

  Determines the new search button that will display on the html display pages.

=cut

sub newSearchButton {
    my $self = shift;
    $self->{content} .= "<a href=\"input.pl\">New Search</a>";
}

=head2 getFileLines

  Desc: sub getFileLines
  Args: file; example. $self -> getFileLines($self->{tempdir});
  Ret : $list[0];

  Counts file lines (used on temp directories).

=cut

sub getFileLines {
    my $self   = shift;
    my $file   = shift;
    open my $f, '< :encoding(UTF-8)', $file or die "$! reading $file";
    my $cnt = 0;
    $cnt++ while <$f>;
    return $cnt;
}

=head2 render_text_page

  Desc: sub render_text_page
  Args: $c
  Ret : n/a

  Opens dumpfile and displays it (this is the text file).

=cut

sub render_text_page {
    my $self = shift;
    my $c = shift;
    print STDERR "TEMPDIR = $self->{tempdir}\n\n";
    $self->dumptextfile($c, $self->{tempdir} . "/" . $self->{dumpfile} );
}

=head2 display_ids_notfound

  Desc: sub display_ids_notfound
  Args: default;
  Ret : n/a

  Opens dumpfile and counts the lines, then compares to the number of IDs
  submitted to get the count of the IDs that were not found in the database.

=cut

sub display_ids_notfound {
    my $self  = shift;
    my $c = shift;
    my $file  = $self->{tempdir} . "/" . $self->{dumpfile} . ".notfound";
    my $count = $self->getFileLines($file);
    $self->dumptextfile($c, $file, "IDs not found in the database: $count" );
}

=head2 dumptextfile

  Desc: sub dumptextfile
  Args: default;
  Ret : n/a

  Cleans up and closes dumpfile.

=cut

sub dumptextfile {
    my $self = shift;
    my $c = shift;
    my $file = shift;
    my $message = shift;
    if ( $self->{download} ) {
	#"Pragma: \"no-cache\"\nContent-Disposition: filename=sgn_dump.txt\nContent-type: application/data\n\n";
	$c->res->content_type("application/data");
	$c->res->headers()->header("Content-Disposition: filename=sgn_bulk_download.fasta");
#no-cache\nContent-Disposition: filename=sgn_dump.txt\nContent-type: application/data\n\n");
    }
    else {
        $c->res->content_type("text/plain");
    }

    my $contents = read_file($file);

    $c->res->body($message . $contents);
}

=head2 debug

  Desc: sub debug
  Args: string; example. $self -> debug("input_ok: Input is NOT OK!");
  Ret : n/a

  Function for printing adds break and new line to messages.

=cut

sub debug {
    my $self    = shift;
    my $message = shift;
    if ( $self->{debug} ) { $self->{content} .= "$message<br />\n"; }
}

=head2 no_data_error_page

  Desc: sub no_data_error_page
  Args: n/a
  Ret : n/a

  Displays message when file can no longer be opened.

=cut

sub no_data_error_page {
    print
"The results of that search or not available anymore. Please repeat your search.";
}

1;

=head1 BUGS

  None known.

=head1 AUTHOR

  Lukas Mueller, August 12, 2003
  Modified and documented by Caroline Nyenke, August, 11, 2005

=head1 SEE ALSO

  /bulk/download.pl
  /bulk/input.pl

=cut


