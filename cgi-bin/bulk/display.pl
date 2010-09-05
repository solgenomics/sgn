#!/usr/bin/perl

=head1 NAME

  /bulk/display.pl

=head1 DESCRIPTION

  This perl script is used on the bulk download page. It determines the format
  of the data given back to the user (submitted to download.pl). This includes
  the format of the the html pages that display the data as well as determining
  the fasta format and the text format.

=cut

use strict;
use warnings;
use CatalystX::GlobalContext '$c';

bulk_display->new($c)->display_page;

package bulk_display;
use CGI ();
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/ html_break_string/;

=head2 new

  Desc: sub new
  Args: default
  Ret : $args, $class;

  When implemented creates a new display object that the methods in the display
  package can be called on.

=cut

sub new {
    my $class   = shift;
    my $c       = shift;
    my $args    = {};

    # define some constants
    $args->{pagesize} = 50;
    $args->{content}  = "";
    $args->{tempdir} = $c->path_to( $c->tempfiles_subdir('bulk') );

    # get cgi arguments
    $args->{cgi}         = my $cgi = CGI->new;
    $args->{dumpfile}    = $cgi->param("dumpfile");
    $args->{page_number} = $cgi->param("page_number");
    $args->{outputType}  = $cgi->param("outputType");
    $args->{seq_type}    = $cgi->param("seq_type");
    $args->{idType}      = $cgi->param("idType");
    $args->{summary}     = $cgi->param("summary");
    $args->{download}    = $cgi->param("download");
    $args->{page} = CXGN::Page->new( "Browse Bulk Results", "Lukas Mueller" );

    return bless $args, $class;
}

=head2 display_page

  Desc: sub display_page
  Args: default
  Ret : page

  Calls summary page to be displayed. Determines what page to render depending
  on the outout type the user selects.

=cut

sub display_page() {
    my $self = shift;

    # if summary switch is set, display summary page
    if ( $self->{summary} ) { $self->display_summary_page(); }

    elsif ( $self->{outputType} =~ /html/i ) {
        $self->render_html_table_page();
    }
    elsif ( $self->{outputType} =~ /text/i ) {
        $self->render_text_page();
    }
    elsif ( $self->{outputType} =~ /fasta/i ) {
        $self->render_fasta_page();
    }
    elsif ( $self->{outputType} =~ /notfound/i ) {
        $self->display_ids_notfound();
    }
    else { $self->render_html_table_page(); }
}

=head2 display_summary_page

  Desc: sub display_summary_page
  Args: default
  Ret : n/a

  Opens temp file created in download.pl then opens a filehandle and prints the
  data to that file.

=cut

sub display_summary_page {
    my $self = shift;
    my $file = $self->{tempdir} . "/" . $self->{dumpfile} . ".summary";
    open( F, "<$file" ) || $self->{page}->error_page("can't open $file");
    $self->{page}->header();
    while (<F>) {
        print $_;
    }
    $self->{page}->footer();
}

=head2 render_html_page

  Desc: sub render_html_page
  Args: default
  Ret : n/a

  Creates html page in style specified by object that calls the method.

=cut

sub render_html_page {
    my $self  = shift;
    my $style = shift;
    if ( $style =~ /HTML/i || !defined($style) ) {
        $self->render_html_table_page();
    }
    if ( $style =~ /tree/i ) { $self->render_html_tree_page(); }
}

=head2 render_html_table_page

  Desc: sub render_html_table_page
  Args: default
  Ret : n/a

  Creates the html table that will contain the data on the page. Prints page
  number and links above and below the table. Also determines the format of text
  that will be place in the table (by download.pl). For example, sequences and
  quality values are displayed in a smaller font and appear 60 per line (value
  can be adjusted).

=cut

sub render_html_table_page {
    my $self = shift;

    #
    # open the file
    #
    if ( !exists( $self->{page_number} ) || ( $self->{page_number} == 0 ) ) {
        $self->{page_number} = 1;
    }
    if ( !exists( $self->{page_size} ) ) { $self->{page_size} = 50; }

    $self->{debug} = 0;
    my $line_count =
      $self->getFileLines( $self->{tempdir} . "/" . $self->{dumpfile} );
    $self->{line_count} = $line_count;
    $self->debug("Line Count in the file: $line_count");
    if ( $line_count < 2 ) {
        $self->{content} .=
"No data was retrieved. Please verify your input parameters. Thanks.<br /><br />\n";
    }
    else {
        open( F, "<" . $self->{tempdir} . "/" . $self->{dumpfile} )
          || $self->{page}->error_page("Can't open $self->{dumpfile}");

        #
        # read the column definitions
        #
        my @output_fields;
        my $defs = <F>;
        if ($defs) { chomp($defs); @output_fields = split /\t/, $defs; }
        $self->debug( "column definitions: " . ( join " ", @output_fields ) );

        # define the links
        my %links = (
            clone_name =>
"/search/est.pl?request_type=10&amp;search=Search&amp;request_id=",
            SGN_U        => "/search/unigene.pl?unigene_id=",
            converted_id => "/search/unigene.pl?unigene_id=",
        );
        $self->{links} = \%links;

        #
        # read in the required page
        #
        my $line = 0;
        my @data = ();
        $self->{page}->header("Bulk download results");
        $self->buttons();
        $self->{content} .= "<table summary=\"\" border=\"1\">\n";

        # print table header
        $self->{content} .=
            "<tr><td>line</td><td>"
          . ( join "</td><td>", @output_fields )
          . "</td></tr>";

        while (<F>) {
            chomp;
            $line++;
            if ( $line >=
                ( ( ( $self->{page_number} - 1 ) * $self->{page_size} ) + 1 )
                && (
                    $line <= ( ( $self->{page_number} ) * $self->{page_size} ) )
              )
            {
                my @fields = split /\t/;
                my %row;
                for ( my $i = 0 ; $i < @fields ; $i++ ) {
                    $row{ $output_fields[$i] } = $fields[$i];
                }

                # format the sequence data for output to browser.
                # number of letters in sequence or qual to wrap on
                my $breakspace_num = 60;

                $row{est_seq} =
                  html_break_string( $row{est_seq}, $breakspace_num );
                $row{est_seq} =
"<span class=\"sequence\" style=\"font-size: smaller;\"> $row{est_seq}</span>";

                $row{unigene_seq} =
                  html_break_string( $row{unigene_seq}, $breakspace_num );
                $row{unigene_seq} =
"<span class=\"sequence\" style=\"font-size: smaller;\"> $row{unigene_seq}</span>";

                $row{protein_seq} =
                  html_break_string( $row{protein_seq}, $breakspace_num );
                $row{protein_seq} =
"<span class=\"sequence\" style=\"font-size: smaller;\"> $row{protein_seq}</span>";
                $row{estscan_seq} =
                  html_break_string( $row{estscan_seq}, $breakspace_num );
                $row{estscan_seq} =
"<span class=\"sequence\" style=\"font-size: smaller;\"> $row{estscan_seq}</span>";
                $row{longest6frame_seq} =
                  html_break_string( $row{longest6frame_seq}, $breakspace_num );
                $row{longest6frame_seq} =
"<span class=\"sequence\" style=\"font-size: smaller;\"> $row{longest6frame_seq}</span>";
                $row{preferred_protein_seq} =
                  html_break_string( $row{preferred_protein_seq},
                    $breakspace_num );
                $row{preferred_protein_seq} =
"<span class=\"sequence\" style=\"font-size: smaller;\"> $row{preferred_protein_seq}</span>";

                $row{bac_end_sequence} =
                  html_break_string( $row{bac_end_sequence}, $breakspace_num );
                $row{bac_end_sequence} =
"<span class=\"sequence\" style=\"font-size: smaller;\"> $row{bac_end_sequence}</span>";

                my $qual = $row{qual_value_seq};
                my @qual = split /\s+/, $qual;
                $row{qual_value_seq} = "";
                s/^(\d)$/&nbsp;$1/ foreach (@qual);
                while ( my @a = splice( @qual, 0, $breakspace_num ) ) {
                    $row{qual_value_seq} .= join( "&nbsp;", @a ) . "<br />";
                }
                $row{qual_value_seq} =
"<span class=\"sequence\" style=\"font-size: smaller;\"> $row{qual_value_seq}</span>";

                my @output;

         #
         # cycle through @output_fields and find the corresponding hash elements
         #
                $self->{content} .= "<tr><td>$line</td>\n";
                foreach my $f (@output_fields) {

                    #$self-> debug("outputting $row{$f}...");
                    if ( !exists( $row{$f} ) || $row{$f} eq undef ) {
                        $row{$f} = "N.A.";
                    }

#
# add links as required. Links for each output field are stored in the %links hash.
#
                    if ( exists( $links{$f} ) && $row{$f} ne "N.A." ) {
                        $row{$f} =
                          "<a href=\"$links{$f}$row{$f}\">$row{$f}</a>";
                    }
                    if ( $f eq "clone_id" ) {
                        $self->{content} .= "<td>$row{$f}</td>";
                    }
                    else {
                        $self->{content} .= "<td>$row{$f}</td>";
                    }

                    #push @output, $row{$f};
                }
                $self->{content} .= "</tr>\n";

     #$self->{content} .= "<tr><td>".(join "</td><td>", @output) . "</td></tr>";

            }

        }
        $self->{content} .= "</table><!-- dump info -->\n";
        $self->buttons();

    }

    #
    # output to browser
    #
    print $self->{content};
    $self->{page}->footer();
    close(F);
}

=head2 render_fasta

  Desc: sub render_fasta
  Args: default
  Ret : n/a

  Determines the format of the fasta page (in a similar way as
  render_html_table_page). No trailing spaces or new lines should be present
  after this subroutine is called for fasta pages.

=cut

sub render_fasta_page {
    my $self = shift;

    # print header
    #
    if ( $self->{download} ) {
        print
"Pragma: \"no-cache\"\nContent-Disposition: filename=sequences.fasta\nContent-type: application/data\n\n";
    }
    else {
        print "Content-type: text/plain\n\n";
    }
    open( F, "<" . $self->{tempdir} . "/" . $self->{dumpfile} )
      || $self->{page}->error_page( "Can't open " . $self->{dumpfile} );

    # read column definitions
    my @output_fields;
    my $defs = <F>;
    if ($defs) { chomp($defs); @output_fields = split /\t/, $defs; }

    while (<F>) {
        chomp;
        my @f    = split /\t/;
        my %data = ();

        #convert to hash
        for ( my $i = 0 ; $i < @output_fields ; $i++ ) {
            $data{ $output_fields[$i] } = $f[$i];
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
        if ( $data{qual_value_seq} ) {
            $qual = $data{qual_value_seq};
        }
        else {
            $data{qual_value_seq} = "";
        }
        my @qual = split /\s+/, $qual;
        $data{qual_value_seq} = "\n";
        while ( my @a = splice( @qual, 0, $breakspace_num ) ) {
            $data{qual_value_seq} .= join( " ", @a ) . "\n";
        }
        if ( $data{qual_value_seq} ) {
            $seq = $data{qual_value_seq};
            $data{qual_value_seq} = "";
        }

        # bac end sequences
        # only print sequence if both quality value and sequence selected
        if ( $data{bac_end_sequence} ) {
            $seq = "\n"
              . html_break_string( $data{bac_end_sequence}, $breakspace_num,
                "\n" )
              . "\n";
            $data{bac_end_sequence} = "";
        }
        else {
            $data{bac_end_sequence} = "";
        }

        # est vs. unigene seq
        $data{est_seq} =
          html_break_string( $data{est_seq}, $breakspace_num, "\n" )
          if defined( $data{est_seq} );
        $data{unigene_seq} =
          html_break_string( $data{unigene_seq}, $breakspace_num, "\n" )
          if defined( $data{unigene_seq} );
        $data{protein_seq} =
          html_break_string( $data{protein_seq}, $breakspace_num, "\n" )
          if defined( $data{protein_seq} );
        $data{estscan_seq} =
          html_break_string( $data{estscan_seq}, $breakspace_num, "\n" )
          if defined( $data{estscan_seq} );
        $data{longest6frame_seq} =
          html_break_string( $data{longest6frame_seq}, $breakspace_num, "\n" )
          if defined( $data{longest6frame_seq} );
        $data{preferred_protein_seq} =
          html_break_string( $data{preferred_protein_seq},
            $breakspace_num, "\n" )
          if defined( $data{preferred_protein_seq} );

        if ( $self->{seq_type} eq "est_seq" ) {
            $seq = "\n" . $data{est_seq} . "\n";
            warn "NOTE: est sequence given, seq_type: "
              . $self->{seq_type} . "\n";
            $data{est_seq} = "";
        }
        elsif ( $self->{seq_type} eq "unigene_seq" ) {
            $seq = "\n" . $data{unigene_seq} . "\n";
            warn "NOTE: unigene sequence given, seq_type: "
              . $self->{seq_type} . "\n";
            $data{unigene_seq} = "";
        }

        #added for protein
        elsif ( $self->{seq_type} eq "protein_seq" ) {
            $seq = "\n" . $data{protein_seq} . "\n";
            warn "NOTE: protein sequence given, seq_type: "
              . $self->{seq_type} . "\n";
            $data{protein_seq} = "";
        }
        elsif ( $self->{seq_type} eq "estscan_seq" ) {
            $seq = "\n" . $data{estscan_seq} . "\n";
            $data{estscan_seq} = "";
        }
        elsif ( $self->{seq_type} eq "preferred_protein_seq" ) {
            $seq = "\n" . $data{preferred_protein_seq} . "\n";
            $data{preferred_protein_seq} = "";
        }
        elsif ( $self->{seq_type} eq "longest6frame_seq" ) {
            $seq = "\n" . $data{longest6frame_seq} . "\n";
            $data{longest6frame_seq} = "";
        }

        # output
        my $output = "";
        foreach my $o (@output_fields) {
            if ( exists( $data{$o} ) && $data{$o} ne "" ) {
                $output .= "$o:$data{$o}\t";
            }
        }

        s/ +/ /g foreach ( $output . $seq );
        $output =~ s/.*?\://
          ; # remove the first label (>SGN_U:SGN_U738473 becomes simply >SGN_U738473)

        print ">$output$seq";    # do not add new lines to this string

    }

    close(F);
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
        "<a href=\"display.pl?summary=1&amp;dumpfile="
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
    my $output = `wc -l $file`;
    chomp($output);
    $output =~ s/^\s+(.*)/$1/;
    my @list = split /\b/, $output;
    return $list[0];
}

=head2 render_text_page

  Desc: sub render_text_page
  Args: default;
  Ret : n/a

  Opens dumpfile and displays it (this is the text file).

=cut

sub render_text_page {
    my $self = shift;
    $self->dumptextfile( $self->{tempdir} . "/" . $self->{dumpfile} );
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
    my $file  = $self->{tempdir} . "/" . $self->{dumpfile} . ".notfound";
    my $count = $self->getFileLines($file);
    $self->dumptextfile( $file, "IDs not found in the database: $count" );
}

=head2 dumptextfile

  Desc: sub dumptextfile
  Args: default;
  Ret : n/a

  Cleans up and closes dumpfile.

=cut

sub dumptextfile {
    my $self    = shift;
    my $file    = shift;
    my $message = shift;
    if ( $self->{download} ) {
        print
"Pragma: \"no-cache\"\nContent-Disposition: filename=sgn_dump.txt\nContent-type: application/data\n\n";
    }
    else {
        print "Content-type: text/plain\n\n";
    }

    # open file
    print $message. "\n";
    open( F, "<$file" ) || no_data_error_page();

    while (<F>) {
        print $_;
    }
    close(F);
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

=head1 BUGS

  None known.

=head1 AUTHOR

  Lukas Mueller, August 12, 2003
  Modified and documented by Caroline Nyenke, August, 11, 2005

=head1 SEE ALSO

  /bulk/download.pl
  /bulk/input.pl

=cut
