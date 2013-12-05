
package SGN::Controller::Bulk::Download;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

use Data::Dumper;
use File::Slurp qw | read_file |;
use Cache::File; 
use File::Spec::Functions;

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
use CXGN::Bulk::Converter;

sub download : Path('/tools/bulk/download') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $params = $c->req->params();

    print STDERR "PARAMS: ".Data::Dumper::Dumper($params);
    
    _invalid_params($c) unless $params->{idType};

    $params->{dbc}     = $c->dbc->dbh();
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
    } elsif($idType eq "converter") { 
	my @files = split /\s+/, $c->config->{solyc_converter_files};
	$params->{solyc_converter_files} = \@files;
	$bulk = CXGN::Bulk::Converter->new($params);
    }
	else {
	die "invalid idtype '$idType'";
    }
    
    if ( $bulk->process_parameters() ) {
	$bulk->process_ids();
	$bulk->create_dumpfile();

	$bulk->result_summary();

	my $dumpfile = $bulk->get_dumpfile();
	my $notfoundfile = $bulk->get_notfoundfile();
	
	$c->forward("Bulk::Display", "display_summary_page", [ $dumpfile ]);
    }
    else {
	$c->stash->{message}  = $bulk->error_message();
	$c->stash->{template} = '/generic_message.mas';
    }
}

=head2 get_parameters

  Desc: sub get_parameters
  Args: array; example: get_parameters($ARGV[0]);
  Ret : modified parameter array

  Retrives parameters from CXGN::Page object (passed from the user).

=cut

sub get_parameters {
    my $self = shift;
    my $c = shift;

    my $params = {};
    $params->{idType}               = $c->req->param("idType");
    $params->{outputType}           = $c->req->param("outputType");
    $params->{debug}                = $c->req->param("debug");
    $params->{fasta}                = $c->req->param("fasta");
    $params->{seq_type}             = $c->req->param("seq_type") || '';
    $params->{build_id}             = $c->req->param("build_id") || '';
    $params->{automatic_annotation} = $c->req->param("automatic_annotation");
    $params->{best_arabidopsis_match} =
      $c->req->param("best_arabidopsis_match");
    $params->{best_genbank_match} = $c->req->param("best_genbank_match");
    $params->{manual_annotation}  = $c->req->param("manual_annotation");

    # the file name of the file used in the upload:
    $params->{file} = $c->req->param("file");

    # the name of the dumpfile, if available:
    $params->{dumpfile}    = $c->req->param("dumpfile");
    $params->{page_number} = $c->req->param("page_number");

    # if this is true, the summary page is displayed again.
    $params->{summary} = $c->req->param("summary");
    ### Build id to deal with:  $params->{build_id}
    ### seq_type:$params->{seq_type}
    $params->{group_by_unigene} = $c->req->param("group_by_unigene");
    $params->{unigene_mode}     = $c->req->param("unigene_mode");
    $params->{associated_loci}  = $c->req->param("associated_loci");
    $params->{sequence}    = $c->req->param("sequence");
    $params->{seq_type}    = $c->req->param("seq_type");
    $params->{unigene_seq} = $c->req->param("unigene_seq");
    $params->{seq_mode}    = $c->req->param("seq_mode");
    $params->{est_seq}     = $c->req->param("est_seq");
    $params->{uni_seq}     = $c->req->param("uni_seq");

    # bac search parameters
    $params->{bac_seq_type}       = $c->req->param("bac_seq_type");
    $params->{bac_id}             = $c->req->param("bac_id");
    $params->{bac_end_sequence}   = $c->req->param("bac_end_sequence");
    $params->{qual_value_seq}     = $c->req->param("qual_value_seq");
    $params->{arizona_clone_name} = $c->req->param("arizona_clone_name");
    $params->{chr_clone_name}     = $c->req->param("chr_clone_name");
    $params->{cornell_clone_name} = $c->req->param("cornell_clone_name");
    $params->{clone_type}         = $c->req->param("clone_type");
    $params->{org_name}           = $c->req->param("org_name");
    $params->{accession_name}     = $c->req->param("accession_name");
    $params->{library_name}       = $c->req->param("library_name");
    $params->{estimated_length}   = $c->req->param("estimated_length");
    $params->{genbank_accession}  = $c->req->param("genbank_accession");
    $params->{overgo_matches}     = $c->req->param("overgo_matches");
    $params->{SGN_S}              = $c->req->param("SGN_S");
    $params->{SGN_C}              = $c->req->param("SGN_C");
    $params->{SGN_T}              = $c->req->param("SGN_T");
    $params->{SGN_E}              = $c->req->param("SGN_E");
    $params->{SGN_U}              = $c->req->param("SGN_U");
    $params->{chipname}           = $c->req->param("chipname");
    $params->{TUS}                = $c->req->param("TUS");
    $params->{clone_name}         = $c->req->param("clone_name");
    $params->{build_nr}           = $c->req->param("build_nr");
    $params->{evalue}             = $c->req->param("evalue");
    $params->{SGN_U_U}            = $c->req->param("SGN_U_U");
    $params->{SGN_U_M}            = $c->req->param("SGN_U_M");
    $params->{convert_to_current} = $c->req->param("convert_to_current");

    # add a new line so that the first id from the file upload is separated
    # from the last id here, only if user submits ids in field and as file.

    if ( $c->req->param("ids") =~ /\S/ ) {
        $params->{ids_string} = $c->req->param("ids") . "\n";
    }

    # get an upload object to upload a file
    my $upload = $c->req->upload();

    # if there is a file add it to the ids_string
    if ( defined $upload ) {
        my $fh = $upload->fh;
        if ($fh) {
            ### Uploading file...
            while (<$fh>) {
                $params->{ids} .= $_;
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
    my $self =shift;
    my $c = shift;

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

  based on original bulk download script by Lukas Mueller
  August 12, 2003

  Modified August 11, 2005 by
  Summer Intern Caroline N. Nyenke

  Modified July 7, 2006
  Summer Intern Emily Hart

  Alexander Naydich and Matthew Crumb (interns)
  July 3, 2007

  Refactored as a Catalyst Controller
  Lukas, Nov 2013

=head1 SEE ALSO

  /bulk/display.pl
  /bulk/input.pl

=cut

