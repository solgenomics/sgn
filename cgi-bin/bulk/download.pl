use CatalystX::GlobalContext qw( $c );
# refactored bulk download script for SGN database
# Alexander Naydich and Matthew Crumb (interns)
# July 3, 2007

##  based on original bulk download script by
##  Lukas Mueller
##  August 12, 2003

##  Modified August 11, 2005 by
##  Summer Intern Caroline N. Nyenke

##  Modified July 7, 2006
##  Summer Intern Emily Hart

=head1 NAME

  /bulk/download.pl

=head1 DESCRIPTION

  This perl script is used on the bulk download page. The script collects
  identifiers submitted by the user and determines the mode the user is searching
  in (clone, unigene, unigene_member, microarray, bac, bac_end, or unigene_convert).
  It then uses the appropriate Bulk object to process the input, query the database,
  format the results and display them on a separate page. Options of viewing
  or downloading in text or fasta format are available.

=cut

use strict;
use warnings;

use CXGN::Page;
use CXGN::DB::Connection;

use CXGN::Bulk::BAC;
use CXGN::Bulk::UnigeneConverter;
use CXGN::Bulk::UnigeneIDUnigene;
use CXGN::Bulk::BACEndRaw;
use CXGN::Bulk::BACEndTrim;
use CXGN::Bulk::CloneEST;
use CXGN::Bulk::CloneUnigene;
use CXGN::Bulk::ArraySpotEST;
use CXGN::Bulk::ArraySpotUnigene;
use CXGN::Bulk::UnigeneMemberInfo;


my $page   = CXGN::Page->new();
my $params = get_parameters($page);

_invalid_params() unless $params->{idType};


$params->{dbc}     = CXGN::DB::Connection->new;
$params->{tempdir} = $c->path_to( $c->tempfiles_subdir('bulk') );

#create correct bulk object
my $bulk;
my $idType = $params->{idType};
if ( $idType eq "bac" ) {
    $bulk = CXGN::Bulk::BAC->new($params);
}
elsif ( $idType eq "bac_end" ) {
    if ( $params->{bac_seq_type} eq "raw_seq" ) {
        $bulk = CXGN::Bulk::BACEndRaw->new($params);
    }
    elsif ( $params->{bac_seq_type} eq "trim_seq" ) {
        $bulk = CXGN::Bulk::BACEndTrim->new($params);
    }
}
elsif ( $idType eq "clone" ) {
    if ( $params->{seq_type} eq "est_seq" ) {
        $bulk = CXGN::Bulk::CloneEST->new($params);
    }
    elsif ( $params->{seq_type} eq "unigene_seq" ) {
        $bulk = CXGN::Bulk::CloneUnigene->new($params);
    }
}
elsif ( $idType eq "microarray" ) {
    if ( $params->{seq_type} eq "est_seq" ) {
        $bulk = CXGN::Bulk::ArraySpotEST->new($params);
    }
    elsif ( $params->{seq_type} eq "unigene_seq" ) {
        $bulk = CXGN::Bulk::ArraySpotUnigene->new($params);
    }
}
elsif ( $idType eq "unigene_convert" ) {
    $bulk = CXGN::Bulk::UnigeneConverter->new($params);
}
elsif ( $idType eq "unigene" ) {
    if ( $params->{unigene_mode} eq "unigene_info" ) {
            $bulk = CXGN::Bulk::UnigeneIDUnigene->new($params);
    }
    elsif ( $params->{unigene_mode} eq "member_info" ) {
        $bulk = CXGN::Bulk::UnigeneMemberInfo->new($params);
    }
} else {
    die "invalid idtype '$idType'";
}

if ( $bulk->process_parameters() ) {
    $bulk->process_ids();
    #die "process 2 ($bulk)" ;
    $bulk->result_summary_page($page);
}
else {
    $bulk->error_message();
}
$bulk->clean_up();

exit;

=head2 get_parameters

  Desc: sub get_parameters
  Args: array; example: get_parameters($ARGV[0]);
  Ret : modified parameter array

  Retrives parameters from CXGN::Page object (passed from the user).

=cut

sub get_parameters {

    my $page = shift;

    my $params = {  page => $page };
    $params->{idType}               = $page->get_arguments("idType");
    $params->{outputType}           = $page->get_arguments("outputType");
    $params->{debug}                = $page->get_arguments("debug");
    $params->{fasta}                = $page->get_arguments("fasta");
    $params->{seq_type}             = $page->get_arguments("seq_type") || '';
    $params->{build_id}             = $page->get_arguments("build_id") || '';
    $params->{automatic_annotation} = $page->get_arguments("automatic_annotation");
    $params->{best_arabidopsis_match} =
      $page->get_arguments("best_arabidopsis_match");
    $params->{best_genbank_match} = $page->get_arguments("best_genbank_match");
    $params->{manual_annotation}  = $page->get_arguments("manual_annotation");

    # the file name of the file used in the upload:
    $params->{file} = $page->get_arguments("file");

    # the name of the dumpfile, if available:
    $params->{dumpfile}    = $page->get_arguments("dumpfile");
    $params->{page_number} = $page->get_arguments("page_number");

    # if this is true, the summary page is displayed again.
    $params->{summary} = $page->get_arguments("summary");
    ### Build id to deal with:  $params->{build_id}
    ### seq_type:$params->{seq_type}
    $params->{group_by_unigene} = $page->get_arguments("group_by_unigene");
    $params->{unigene_mode}     = $page->get_arguments("unigene_mode");
    $params->{associated_loci}  = $page->get_arguments("associated_loci");
    $params->{sequence}    = $page->get_arguments("sequence");
    $params->{seq_type}    = $page->get_arguments("seq_type");
    $params->{unigene_seq} = $page->get_arguments("unigene_seq");
    $params->{seq_mode}    = $page->get_arguments("seq_mode");
    $params->{est_seq}     = $page->get_arguments("est_seq");
    $params->{uni_seq}     = $page->get_arguments("uni_seq");

    # bac search parameters
    $params->{bac_seq_type}       = $page->get_arguments("bac_seq_type");
    $params->{bac_id}             = $page->get_arguments("bac_id");
    $params->{bac_end_sequence}   = $page->get_arguments("bac_end_sequence");
    $params->{qual_value_seq}     = $page->get_arguments("qual_value_seq");
    $params->{arizona_clone_name} = $page->get_arguments("arizona_clone_name");
    $params->{chr_clone_name}     = $page->get_arguments("chr_clone_name");
    $params->{cornell_clone_name} = $page->get_arguments("cornell_clone_name");
    $params->{clone_type}         = $page->get_arguments("clone_type");
    $params->{org_name}           = $page->get_arguments("org_name");
    $params->{accession_name}     = $page->get_arguments("accession_name");
    $params->{library_name}       = $page->get_arguments("library_name");
    $params->{estimated_length}   = $page->get_arguments("estimated_length");
    $params->{genbank_accession}  = $page->get_arguments("genbank_accession");
    $params->{overgo_matches}     = $page->get_arguments("overgo_matches");
    $params->{SGN_S}              = $page->get_arguments("SGN_S");
    $params->{SGN_C}              = $page->get_arguments("SGN_C");
    $params->{SGN_T}              = $page->get_arguments("SGN_T");
    $params->{SGN_E}              = $page->get_arguments("SGN_E");
    $params->{SGN_U}              = $page->get_arguments("SGN_U");
    $params->{chipname}           = $page->get_arguments("chipname");
    $params->{TUS}                = $page->get_arguments("TUS");
    $params->{clone_name}         = $page->get_arguments("clone_name");
    $params->{build_nr}           = $page->get_arguments("build_nr");
    $params->{evalue}             = $page->get_arguments("evalue");
    $params->{SGN_U_U}            = $page->get_arguments("SGN_U_U");
    $params->{SGN_U_M}            = $page->get_arguments("SGN_U_M");
    $params->{convert_to_current} = $page->get_arguments("convert_to_current");

    # add a new line so that the first id from the file upload is separated
    # from the last id here, only if user submits ids in field and as file.

    if ( $page->get_arguments("ids") =~ /\S/ ) {
        $params->{ids_string} = $page->get_arguments("ids") . "\n";
    }

    # get an upload object to upload a file
    my $upload;
    $upload = $page->get_upload();

    # if there is a file add it to the ids_string
    if ( defined $upload ) {
        my $fh = $upload->fh;
        if ($fh) {
            ### Uploading file...
            while (<$fh>) {
                $params->{ids_string} .= $_;
            }
        }
    }

    ### size of uploaded ids_string: length $params->{ids_string}

    return $params;
}


sub post_only {
  my ($page) = @_;
  $page->error_page('This page can only accept HTTP POST requests. Please go to <a href="input.pl">Bulk Download</a> to make your selections.');
}

sub _invalid_params {
    $c->throw(
        title    => "An Error has occured",
        message  => "ID Type must be provided",
        notify   => 0,
        is_error => 0,
    );
}

1;

=head1 BUGS

  None known.

=head1 AUTHOR

  Alexander Naydich and Matthew Crumb (interns)
  July 3, 2007

  based on original bulk download script by Lukas Mueller
  August 12, 2003

  Modified August 11, 2005 by
  Summer Intern Caroline N. Nyenke

  Modified July 7, 2006
  Summer Intern Emily Hart

=head1 SEE ALSO

  /bulk/display.pl
  /bulk/input.pl

=cut

