package solGS::AnalysisReport;

use Moose;
use namespace::autoclean;

use DateTime;
use Email::Sender::Simple qw /sendmail/;
use Email::Simple;
use Email::Simple::Creator;
use File::Spec::Functions qw /catfile catdir/;
use File::Slurp qw /write_file read_file/;
use JSON;
use Storable qw/ nstore retrieve /;

with 'MooseX::Getopt';
with 'MooseX::Runnable';

has 'output_details_file' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

#for how long (in minutes) to check for outputs before
#reporting analyses status
has 'status_check_duration' => (
    is      => 'ro',
    isa     => 'Int',
    default => 5,
);

our $START_TIME = DateTime->now;

sub run {
    my $self = shift;

    my $output_details = retrieve( $self->output_details_file );
    $self->check_analysis_status($output_details);

}

sub check_analysis_status {
    my ( $self, $output_details ) = @_;

    $output_details = $self->check_success($output_details);
    $self->log_analysis_status($output_details);
    $self->report_status($output_details);

}

sub check_success {
    my ( $self, $output_details ) = @_;

    my $analysis_profile = $output_details->{analysis_profile};
    my $type             = $analysis_profile->{analysis_type};

    if ( $analysis_profile->{analysis_type} =~ /training_dataset/ ) {
        $output_details = $self->check_population_download($output_details);
    }
    elsif ( $analysis_profile->{analysis_type} =~ /(training|multiple)_model/ )
    {
        if ( $output_details->{data_set_type} =~ /combined_populations/ ) {
            $output_details =
              $self->check_combined_pops_trait_modeling($output_details);
        }
        elsif ( $output_details->{data_set_type} =~ /single_population/ ) {
            $output_details = $self->check_trait_modeling($output_details);
        }
    }
    elsif ( $analysis_profile->{analysis_type} =~ /combine_populations/ ) {
        $output_details =
          $self->check_multi_pops_data_download($output_details);
    }
    elsif ( $analysis_profile->{analysis_type} =~ /selection_prediction/ ) {
        my $st_type = $output_details->{data_set_type};

        if ( $output_details->{data_set_type} =~ /combined/ ) {

 # $output_details = $self->check_combined_pops_trait_modeling($output_details);
            $output_details =
              $self->check_selection_prediction($output_details);
        }
        elsif ( $output_details->{data_set_type} =~ /single_population/ ) {
            $output_details =
              $self->check_selection_prediction($output_details);
        }
    }
    elsif ( $analysis_profile->{analysis_type} =~ /kinship/ ) {
        $output_details = $self->check_kinship_analysis($output_details);
    }
    elsif ( $analysis_profile->{analysis_type} =~ /pca/ ) {
        $output_details = $self->check_pca_analysis($output_details);
    }
    elsif ( $analysis_profile->{analysis_type} =~ /cluster/ ) {
        $output_details = $self->check_cluster_analysis($output_details);
    }

    return $output_details;
}

sub check_combined_pops_trait_modeling {
    my ( $self, $output_details ) = @_;

    $output_details = $self->check_pops_trait_data_combination($output_details);
    $output_details = $self->check_trait_modeling($output_details);

    return $output_details;
}

sub check_pops_trait_data_combination {
    my ( $self, $output_details ) = @_;

    foreach my $k ( keys %{$output_details} ) {
        if ( $k =~ /population_id/ ) {
            my $pheno_file;
            my $geno_file;

            if ( ref $output_details->{$k} eq 'HASH' ) {
                $pheno_file = $output_details->{$k}->{phenotype_file};
                $geno_file  = $output_details->{$k}->{genotype_file};
            }

            if ( $geno_file || $pheno_file ) {
                my $pheno_size;
                my $geno_size;
                my $died_file;

                while (1) {
                    sleep 30;
                    $pheno_size = -s $pheno_file;
                    $geno_size  = -s $geno_file;

                    if ($pheno_size) {
                        $output_details->{$k}->{pheno_success} =
                          'pheno success';
                    }

                    if ($geno_size) {
                        $output_details->{$k}->{geno_success} = 'geno success';
                    }

                    if ( $pheno_size && $geno_size ) {
                        $output_details->{$k}->{success} = 1;
                        $output_details->{status} = 'Done';
                        last;
                    }
                    else {
                        my $end_process = $self->end_status_check();
                        if ($end_process) {
                            $output_details->{$k}->{pheno_success} = 0;
                            $output_details->{$k}->{geno_success}  = 0;
                            $output_details->{$k}->{success}       = 0;
                            $output_details->{status}              = 'Failed';
                            last;
                        }
                    }
                }
            }
            else {
                if ( ref $output_details->{$k} eq 'HASH' ) {
                    $output_details->{$k}->{pheno_success} = 0;
                    $output_details->{$k}->{geno_success}  = 0;
                    $output_details->{$k}->{success}       = 0;
                    $output_details->{status}              = 'Failed';
                }
            }
        }
    }

    return $output_details;
}

sub check_multi_pops_data_download {
    my ( $self, $output_details ) = @_;

    my $no_match = $output_details->{no_match};

    foreach my $k ( keys %{$output_details} ) {
        my $pheno_file;
        my $geno_file;
        if ( $k =~ /population_id/ ) {
            if ( ref $output_details->{$k} eq 'HASH' ) {
                $pheno_file = $output_details->{$k}->{phenotype_file};
                $geno_file  = $output_details->{$k}->{genotype_file};
            }

            if ( $geno_file && $pheno_file ) {
                my $pheno_size;
                my $geno_size;
                my $died_file;

                while (1) {
                    sleep 30;
                    $pheno_size = -s $pheno_file;
                    $geno_size  = -s $geno_file;

                    if ($pheno_size) {
                        $output_details->{$k}->{pheno_success} =
                          'pheno success';
                    }

                    if ($geno_size) {
                        $output_details->{$k}->{geno_success} = 'geno success';
                    }

                    if ( $pheno_size && $geno_size ) {
                        $output_details->{$k}->{success} = 1;
                        $output_details->{status} = 'Done';
                        last;
                    }
                    else {
                        my $end_process = $self->end_status_check();
                        if ($end_process) {
                            $output_details->{$k}->{pheno_success} = 0;
                            $output_details->{$k}->{geno_success}  = 0;
                            $output_details->{$k}->{success}       = 0;
                            $output_details->{status}              = 'Failed';
                            last;
                        }
                    }
                }
            }
            else {
                if ( ref $output_details->{$k} eq 'HASH' ) {
                    $output_details->{$k}->{pheno_success} = 0;
                    $output_details->{$k}->{geno_success}  = 0;
                    $output_details->{$k}->{success}       = 0;
                    $output_details->{status}              = 'Failed';
                }
            }
        }
    }

    return $output_details;
}

sub check_selection_prediction {
    my ( $self, $output_details ) = @_;

    foreach my $k ( keys %{$output_details} ) {
        if ( $k =~ /trait_id/ ) {
            my $gebv_file;
            if ( $output_details->{$k}->{trait_id} ) {
                $gebv_file = $output_details->{$k}->{gebv_file};
            }

            if ($gebv_file) {
                while (1) {
                    sleep 30;
                    if ( -s $gebv_file ) {
                        $output_details->{$k}->{success} = 1;
                        $output_details->{status} = 'Done';
                        last;
                    }
                    else {
                        my $end_process = $self->end_status_check();
                        if ($end_process) {
                            if (
                                !-s $output_details->{$k}->{selection_geno_file}
                              )
                            {
                                $output_details->{$k}->{failure_reason} =
'No genotype data was found for this selection population.';
                            }
                            else {
                                $output_details->{$k}->{failure_reason} =
'The prediction of the selection population failed.';
                            }

                            $output_details->{$k}->{success} = 0;
                            $output_details->{status} = 'Failed';
                            last;
                        }
                    }
                }
            }
        }
    }

    return $output_details;
}

sub check_trait_modeling {
    my ( $self, $output_details ) = @_;

    foreach my $k ( keys %{$output_details} ) {
        if ( $k =~ /trait_id/ ) {
            my $gebv_file;
            if ( ref $output_details->{$k} eq 'HASH' ) {
                if ( $output_details->{$k}->{trait_id} ) {
                    $gebv_file = $output_details->{$k}->{gebv_file};
                }

                if ($gebv_file) {
                    my $gebv_size;
                    my $died_file;

                    while (1) {
                        sleep 30;
                        $gebv_size = -s $gebv_file;

                        if ($gebv_size) {
                            $output_details->{$k}->{success} = 1;
                            $output_details->{status} = 'Done';
                            last;
                        }
                        else {
                            my $end_process = $self->end_status_check();
                            if ($end_process) {
                                $output_details->{$k}->{success} = 0;
                                $output_details->{status} = 'Failed';
                                last;
                            }
                        }
                    }
                }
            }
            else {
                if ( ref $output_details->{$k} eq 'HASH' ) {
                    $output_details->{$k}->{success} = 0;
                    $output_details->{status} = 'Failed';
                }
            }
        }
    }

    return $output_details;
}

sub check_population_download {
    my ( $self, $output_details ) = @_;

    foreach my $k ( keys %{$output_details} ) {
        if ( $k =~ /population_id/ ) {
            my $pheno_file;
            my $geno_file;

            if ( ref $output_details->{$k} eq 'HASH' ) {
                if ( $output_details->{$k}->{population_id} ) {
                    $pheno_file = $output_details->{$k}->{phenotype_file};
                    $geno_file  = $output_details->{$k}->{genotype_file};

                    if ( !$pheno_file ) {
                        $output_details->{$k}->{pheno_message} =
                          'Could not find the phenotype file for this dataset.';
                    }

                    if ( !$geno_file ) {
                        $output_details->{$k}->{geno_message} =
                          'Could not find the genotype file for this dataset.';
                    }

                    if ( $pheno_file && $geno_file ) {
                        my $pheno_size;
                        my $geno_size;
                        my $died_file;

                        while (1) {
                            sleep 30;
                            $pheno_size = -s $pheno_file;
                            $geno_size  = -s $geno_file;

                            if ($pheno_size) {
                                $output_details->{$k}->{pheno_success} = 1;
                            }
                            else {
                                $output_details->{$k}->{pheno_message} =
'There is no phenotype data for this dataset.';
                            }

                            if ($geno_size) {
                                $output_details->{$k}->{geno_success} = 1;
                            }
                            else {
                                $output_details->{$k}->{geno_message} =
                                  'There is no genotype data for this dataset.';
                            }

                            if ( $pheno_size && $geno_size ) {
                                $output_details->{$k}->{success} = 1;
                                $output_details->{status} = 'Done';
                                last;
                            }
                            else {
                                my $end_process = $self->end_status_check();

                                if ($end_process) {
                                    $output_details->{$k}->{pheno_success} = 0;
                                    $output_details->{$k}->{geno_success}  = 0;
                                    $output_details->{$k}->{success}       = 0;
                                    $output_details->{status} = 'Failed';

                                    last;
                                }
                            }
                        }
                    }
                    else {
                        if ( ref $output_details->{$k} eq 'HASH' ) {
                            $output_details->{$k}->{pheno_success} = 0;
                            $output_details->{$k}->{geno_success}  = 0;
                            $output_details->{$k}->{success}       = 0;
                            $output_details->{status}              = 'Failed';
                        }
                    }
                }
            }
        }
    }

    return $output_details;

}

sub check_kinship_analysis {
    my ( $self, $output_details ) = @_;

    foreach my $k ( keys %{$output_details} ) {
        if ( $k =~ /kinship/ ) {

            my $kinship_file = $output_details->{$k}->{matrix_file};
            if ($kinship_file) {
                while (1) {
                    sleep 30;
                    if ( -s $kinship_file ) {
                        $output_details->{$k}->{success} = 1;
                        $output_details->{status} = 'Done';
                        last;
                    }
                    else {
                        my $end_process = $self->end_status_check();
                        if ($end_process) {
                            if ( !-s $output_details->{$k}->{genotype_file} ) {
                                $output_details->{$k}->{failure_reason} =
'No genotype data was found for this kinship analysis.';
                            }
                            else {
                                $output_details->{$k}->{failure_reason} =
                                  'The kinship analysis failed.';
                            }

                            $output_details->{$k}->{success} = 0;
                            $output_details->{status} = 'Failed';
                            last;
                        }
                    }
                }
            }
        }
    }

    return $output_details;
}

sub check_pca_analysis {
    my ( $self, $output_details ) = @_;

    foreach my $k ( keys %{$output_details} ) {
        if ( $k =~ /pca/ ) {

            my $scores_file = $output_details->{$k}->{scores_file};

            if ($scores_file) {
                while (1) {
                    sleep 30;
                    if ( -s $scores_file ) {
                        $output_details->{$k}->{success} = 1;
                        $output_details->{status} = 'Done';
                        last;
                    }
                    else {
                        my $end_process = $self->end_status_check();
                        if ($end_process) {

                        # my $input_files = $output_details->{$k}->{input_file};
                        # my @input_files = split(/\t/, $input_file);
                            my $failure_reason;
                            my $input_file =
                              $output_details->{$k}->{input_file};

                            # foreach my $input_file ($input_file)
                            # {
                            if ( !-s $input_file ) {
                                $failure_reason =
"This dataset has no data. $input_file is empty.";
                            }

                            # }

                            if ($failure_reason) {
                                $output_details->{$k}->{failure_reason} =
                                  $failure_reason;
                            }
                            else {
                                $output_details->{$k}->{failure_reason} =
'The pca algorithm (R) caught an exception. Details are in the analysis error file.';
                            }

                            $output_details->{$k}->{success} = 0;
                            $output_details->{status} = 'Failed';
                            last;
                        }
                    }
                }
            }
        }
    }

    return $output_details;
}

sub check_cluster_analysis {
    my ( $self, $output_details ) = @_;

    foreach my $k ( keys %{$output_details} ) {
        if ( $k =~ /cluster/ ) {
            my $result_file = $output_details->{$k}->{result_file};
            if ($result_file) {
                while (1) {
                    sleep 30;
                    if ( -s $result_file ) {
                        $output_details->{$k}->{success} = 1;
                        $output_details->{status} = 'Done';
                        last;
                    }
                    else {
                        my $end_process = $self->end_status_check();
                        if ($end_process) {
                            my $input_file =
                              $output_details->{$k}->{input_file};

                            if ( !-s $input_file ) {
                                $output_details->{$k}->{failure_reason} =
"The input data file ($input_file) is empty.\n";
                            }
                            else {
                                $output_details->{$k}->{failure_reason} =
"The clustering algorithm (R) caught an exception. Details are in the analysis error file.\n";
                            }

                            $output_details->{$k}->{success} = 0;
                            $output_details->{status} = 'Failed';
                            last;
                        }
                    }
                }
            }
        }
    }

    return $output_details;
}

sub get_file {
    my ( $self, $dir, $exp ) = @_;

    opendir my $dh, $dir
      or die "can't open $dir: $!\n";

    my ($file) = grep { /$exp/ && -f "$dir/$_" } readdir($dh);
    close $dh;

    if ($file) {
        $file = catfile( $dir, $file );
    }

    return $file;
}

sub report_status {
    my ( $self, $output_details ) = @_;

    my $args = $output_details->{analysis_profile}->{arguments};
    my $json = JSON->new();
    $args = $json->decode($args);
    my $first_name = $args->{first_name};

    my $analysis_status = $self->email_body($output_details);
    my $closing =
        "If you have any remarks, please contact us:\n"
      . $output_details->{contact_page}
      . "\n\nThanks and regards,\nsolGS M Tool";

    my $body = "Dear $first_name,\n" . "\n$analysis_status" . "$closing";

    my $email_adds    = $self->email_addresses($output_details);
    my $analysis_name = $output_details->{analysis_profile}->{analysis_name};

    my $email = Email::Simple->create(
        header => [
            From    => $email_adds->{email_from},
            To      => $email_adds->{email_to},
            Cc      => $email_adds->{email_cc},
            Subject => "solGS Report: $analysis_name",
        ],
        body => $body,
    );

    sendmail($email);

}

sub email_addresses {
    my ( $self, $output_details ) = @_;

    my $analysis_profile = $output_details->{analysis_profile}->{arguments};
    my $json             = JSON->new();
    $analysis_profile = $json->decode($analysis_profile);
    my $first_name = $analysis_profile->{first_name};

    my $user_email = $analysis_profile->{user_email};
    my $user_name  = $analysis_profile->{user_name};

    my $email_from;
    my $email_to;
    my $email_cc;

    if ( $output_details->{host} =~ /localhost/ ) {
        my $uid = getpwuid($<);
        $email_from = $uid . ' <' . $uid . '@localhost.localdomain>';
        $email_to   = $uid . ' <' . $uid . '@localhost.localdomain>';
    }
    else {
        my $mail_list = $output_details->{mailing_list};
        $email_from = 'solGS M Tool <' . $mail_list . '>';
        $email_cc   = 'solGS Job <' . $mail_list . '>';
        $email_to   = $user_name . '<' . $user_email . '>';

    }

    return {
        'email_from' => $email_from,
        'email_cc'   => $email_cc,
        'email_to'   => $email_to
    };

}

sub email_body {
    my ( $self, $output_details ) = @_;

    my $analysis_profile = $output_details->{analysis_profile};
    my $analysis_type    = $analysis_profile->{analysis_type};

    my $msg;

    if ( $analysis_type =~ /multiple_models/ ) {
        $msg = $self->multi_modeling_message($output_details);
    }
    elsif ( $analysis_type =~ /training_model/ ) {
        $msg = $self->single_modeling_message($output_details);
    }
    elsif ( $analysis_type =~ /training_dataset/ ) {
        $msg = $self->population_download_message($output_details);
    }
    elsif ( $analysis_type =~ /combine_populations/ ) {
        $msg = $self->combine_populations_message($output_details);
    }
    elsif ( $analysis_type =~ /selection_prediction/ ) {
        $msg = $self->selection_prediction_message($output_details);
    }
    elsif ( $analysis_type =~ /kinship/ ) {
        $msg = $self->kinship_analysis_message($output_details);
    }
    elsif ( $analysis_type =~ /pca/ ) {
        $msg = $self->pca_analysis_message($output_details);
    }
    elsif ( $analysis_type =~ /cluster/ ) {
        $msg = $self->cluster_analysis_message($output_details);
    }

    return $msg;

}

sub multi_modeling_message {
    my ( $self, $output_details ) = @_;

    my $message;
    my $cnt = 0;

    foreach my $k ( keys %{$output_details} ) {
        if ( $k =~ /trait_id/ ) {
            my $all_success;

            if ( $output_details->{$k}->{trait_id} ) {
                my $trait_name = uc( $output_details->{$k}->{trait_name} );
                my $trait_page = $output_details->{$k}->{trait_page};

                if ( $output_details->{$k}->{success} ) {
                    $cnt++;
                    $all_success = 1;
                    $message .=
                        "The analysis for $trait_name is done."
                      . " You can view the model output here:"
                      . "\n\n$trait_page\n\n";
                }
                else {
                    $all_success = 0;
                    $message .= "The analysis for $trait_name failed.\n\n";
                    $message .= 'Refering page: ' . $trait_page . "\n\n";
                }
            }
        }
    }

    if ( $cnt > 1 ) {
        $message .= $self->multi_models_extra_message($output_details);
    }

    return $message;
}

sub single_modeling_message {
    my ( $self, $output_details ) = @_;

    my $message;
    foreach my $k ( keys %{$output_details} ) {

        if ( $k =~ /trait_id/ ) {
            my $gebv_file;
            if ( ref $output_details->{$k} eq 'HASH' ) {
                if ( $output_details->{$k}->{trait_id} ) {
                    my $trait_name = uc( $output_details->{$k}->{trait_name} );
                    my $trait_page = $output_details->{$k}->{trait_page};
                    $gebv_file = $output_details->{$k}->{gebv_file};

                    if ( $output_details->{$k}->{success} ) {
                        $message =
                            "The modeling for $trait_name is done."
                          . "\nYou can view the model output here:"
                          . "\n\n$trait_page\n\n";
                    }
                    else {
                        $message = "The modeling for $trait_name failed.\n\n";
                        $message .= 'Refering page: ' . $trait_page . "\n\n";
                        $message .=
"We will troubleshoot the cause and contact you when we find out more.";
                    }
                }
            }
        }
    }

    return $message;
}

sub selection_prediction_message {
    my ( $self, $output_details ) = @_;

    my $message;
    my $cnt = 0;
    foreach my $k ( keys %{$output_details} ) {
        if ( $k =~ /trait_id/ ) {
            if ( $output_details->{$k}->{trait_id} ) {
                my $trait_name = uc( $output_details->{$k}->{trait_name} );
                my $training_pop_page =
                  $output_details->{$k}->{training_pop_page};
                my $selection_pop_page =
                  $output_details->{$k}->{selection_pop_page};
                my $selection_pop_name =
                  $output_details->{$k}->{selection_pop_name};
                $selection_pop_name =~ s/^\s+|\s+$//g;

                if ( $output_details->{$k}->{success} ) {
                    $cnt++;
                    if ( $cnt == 1 ) {
                        $message .=
"The prediction of selection population $selection_pop_name is done."
                          . "\nYou can view the prediction output here:\n\n";
                    }        
                    $message .= uc($trait_name) . ":\n" .  $selection_pop_page . "\n\n";
                }
                else {
                    my $failure_reason =
                      $output_details->{$k}->{failure_reason};
                    $message =
"The analysis for $trait_name failed. Possible reason is:\n\n";
                    $message .= "$failure_reason\n\n";
                    $message .= "Refering page: $selection_pop_page\n\n";
                    $message .=
"We will troubleshoot the cause and contact you when we find out more.\n\n";
                }
            }
        }
    }

    if ( $cnt > 1 ) {
        $message .= $self->multi_models_extra_message($output_details);
    }

    return $message;
}

sub multi_models_extra_message {
    my ( $self, $output_details ) = @_;

    my $multi_models_url = $output_details->{multi_models_url};
    my $message .=
        "You can also view the summary of all the analyses in the page below.\n"
      . "Additionally, you may find the analytical features in the page useful.\n"
      . $multi_models_url . "\n\n";

    return $message;
}

sub population_download_message {
    my ( $self, $output_details ) = @_;

    my $message;

    foreach my $k ( keys %{$output_details} ) {
        if ( $k =~ /population_id/ ) {
            if ( $output_details->{$k}->{population_id} ) {
                my $pop_name = uc( $output_details->{$k}->{population_name} );
                my $pop_page = $output_details->{$k}->{population_page};

                if ( $output_details->{$k}->{success} ) {
                    $message =
"The phenotype and genotype data for $pop_name is ready for analysis."
                      . "\nYou can view the training population page here:\n"
                      . "\n$pop_page.\n\n";
                }
                else {
                    no warnings 'uninitialized';
                    my $msg_geno  = $output_details->{$k}->{geno_message};
                    my $msg_pheno = $output_details->{$k}->{pheno_message};

                    $message =
"Downloading phenotype and genotype data for $pop_name failed.\n";
                    $message .=
                      "\nPossible causes are:\n$msg_geno\n$msg_pheno\n";
                    $message .= 'Refering page: ' . $pop_page . "\n\n";
                    $message .=
"We will troubleshoot the cause and contact you when we find out more.\n\n";
                }
            }
        }
    }

    return $message;
}

sub combine_populations_message {
    my ( $self, $output_details ) = @_;

    my $no_match = $output_details->{no_match};

    my $message;

    if ($no_match) {
        $message =
            $no_match
          . " can not be combined.\n"
          . "Possibly the the populations were genotyped\n"
          . "with different marker alleles or querying the data for one or more of the\n"
          . "populations failed. See details below:\n\n";

        foreach my $k ( keys %{$output_details} ) {
            if ( $k =~ /population_id/ ) {
                if ( $output_details->{$k}->{population_id} ) {
                    my $pop_name =
                      uc( $output_details->{$k}->{population_name} );
                    my $pop_page = $output_details->{$k}->{population_page};

                    if ( $output_details->{$k}->{success} ) {
                        $message .=
"The phenotype and genotype data for $pop_name is succesfuly downloaded."
                          . "\nYou can view the population here:"
                          . "\n$pop_page.\n\n";
                    }
                    else {
                        $message .=
"Downloading phenotype and genotype data for $pop_name failed.";
                        $message .= 'Refering page: ' . $pop_page . "\n\n";
                        $message .=
"We will troubleshoot the cause and contact you when we find out more.\n\n";
                    }
                }
            }
        }

    }
    else {
        my $combined_pops_page = $output_details->{combined_pops_page};
        $message .= "Your combined training population is ready for analysis."
          . " You can view it here:\n\n$combined_pops_page\n\n";
    }

    return $message;
}

sub kinship_analysis_message {
    my ( $self, $output_details ) = @_;

    my $message;

    foreach my $k ( keys %{$output_details} ) {
        if ( $k =~ /kinship/ ) {

            my $output_page = $output_details->{$k}->{output_page};

            if ( $output_details->{$k}->{success} ) {
                $message =
'Your kinship analysis is done. You can access the result here:'
                  . "\n\n$output_page\n\n";
            }
            else {
                no warnings 'uninitialized';
                my $fail_message = $output_details->{$k}->{failure_reason};

                $message = "The kinship analysis failed.\n";
                $message .= "\nPossible causes are:\n$fail_message\n";
                $message .= 'Refering page: ' . $output_page . "\n\n";
                $message .=
"We will troubleshoot the cause and contact you when we find out more.\n\n";
            }
        }
    }

    return $message;
}

sub pca_analysis_message {
    my ( $self, $output_details ) = @_;

    my $message;

    foreach my $k ( keys %{$output_details} ) {
        if ( $k =~ /pca/ ) {

            my $output_page = $output_details->{$k}->{output_page};

            if ( $output_details->{$k}->{success} ) {
                $message = 'Your PCA is done. You can access the result here:'
                  . "\n\n$output_page\n\n";
            }
            else {
                no warnings 'uninitialized';
                my $fail_message = $output_details->{$k}->{failure_reason};

                $message = "The PCA failed.\n";
                $message .= "\nPossible causes are:\n$fail_message\n";
                $message .= 'Refering page: ' . $output_page . "\n\n";
                $message .=
"We will troubleshoot the cause and contact you when we find out more.\n\n";
            }
        }
    }

    return $message;
}

sub cluster_analysis_message {
    my ( $self, $output_details ) = @_;

    my $message;

    foreach my $k ( keys %{$output_details} ) {
        if ( $k =~ /cluster/ ) {

            my $output_page = $output_details->{$k}->{output_page};

            if ( $output_details->{$k}->{success} ) {

                $message =
                    'Your clustering is done. You can access the result here:'
                  . "\n\n$output_page\n\n";
            }
            else {
                no warnings 'uninitialized';
                my $fail_message = $output_details->{$k}->{failure_reason};

                $message = "The cluster analysis failed.\n";
                $message .= "\nPossible causes are:\n$fail_message\n";
                $message .= 'Refering page: ' . $output_page . "\n\n";
                $message .=
"We will troubleshoot the cause and contact you when we find out more.\n\n";
            }
        }
    }

    return $message;
}

sub log_analysis_status {
    my ( $self, $output_details ) = @_;

    my $log_file = $output_details->{analysis_log_file};

    my $analysis_profile = $output_details->{analysis_profile};
    my $analysis_name    = $analysis_profile->{analysis_name};

    my $status = $output_details->{status};

    my @contents = read_file( $log_file, { binmode => ':utf8' } );
    map {
            $contents[$_] =~ m/$analysis_name\s+-*/
          ? $contents[$_] =~ s/error|submitted/$status/ig
          : $contents[$_]
    } 0 .. $#contents;

    write_file( $log_file, { binmode => ':utf8' }, @contents );

}

sub end_status_check {
    my $self = shift;

    my $end_after = $self->status_check_duration;

    my $now_time = DateTime->now;
    my $dur      = $START_TIME->delta_ms($now_time);

    my $dur_mins    = $dur->in_units('minutes');
    my $end_process = $dur_mins >= $end_after ? 1 : 0;

    return $end_process;

}

__PACKAGE__->meta->make_immutable;

####
1;    #
####
