=head1 NAME

SGN::Controller::Qtl- controller for the qtl anlysis start page

=cut

package SGN::Controller::Qtl;

use Moose;

use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use File::Spec::Functions;
use File::Temp qw / tempfile /;
use File::Path qw / mkpath  /;
use File::Copy;
use File::Basename;

sub auto :Args(0) {
    my ($self, $c) = @_;
    
    $c->stash(tempdir  => $c->get_conf("tempfiles_subdir")."/correlation",
                basepath => $c->get_conf("basepath"),
                r_qtl    => $c->get_conf("r_qtl_temp_path"), 
                guide    => $self->guideline(),             
                population => CXGN::Phenome::Population->new($c->dbc->dbh , $c->req->args->[0]),                            
        );
   
    return 1;
}


sub view : PathPart('qtl/view') Chained Args(1) {
    my ( $self, $c, $id) = @_;
    
    ($id !~ /^\d+$/ && !$id) ? $c->throw_404("$id is not a valid population.")  
                     : $c->stash(template      => '/qtl/qtl_start/index.mas',                              
                                 pop    => $c->stash->{population},                                
                                 referer => $c->req->path,                                
                     );
 
    my ($heatmap, $corr_table) = $self->_analyze_correlation($c, $c->stash->{population});        
    
    $c->stash(heatmap    => $heatmap,
              corr_table => $corr_table
        );
}



# sub set_qtl_parameters : PathPart('qtl/stat') Chained('/') Args(0) {
#     my ($self, $c) = @_;  
#     $c->stash(template =>'/qtl/qtl_form/stat_form.mas', 
#               pop_id => 12, 
#               guide => $c->stash->{guide}
#         );

# }

sub guideline {
    my ($self) = shift;
    return qq |<a  href="http://docs.google.com/View?id=dgvczrcd_1c479cgfb">Guidelines</a> |;
}


sub _analyze_correlation : {
    my ($self, $c, $pop)   = @_;
    
    my $pop_id = $pop->get_population_id();

    my $pheno_file      = $pop->phenotype_file($c);
    my $base_path       = $c->get_conf('basepath');
    my $temp_image_dir  = $c->get_conf('tempfiles_subdir');
    my $r_qtl_dir       = $c->get_conf('r_qtl_temp_path');
    my $corre_image_dir = catfile($base_path, $temp_image_dir, "correlation");
    my $corre_temp_dir  = catfile($r_qtl_dir, "tempfiles");
    my $corre_file_dir  = catfile($r_qtl_dir, "cache");
   
    if (-s $pheno_file) 
    {
        foreach my $dir ($corre_image_dir, $corre_temp_dir, $corre_file_dir)
        {
            unless (-d $dir)
            {
                mkpath ($dir, 0, 0755);
            }
        }

        my (undef, $heatmap_file)     = tempfile( "heatmap_${pop_id}-XXXXXX",
                                              DIR      => $corre_temp_dir,
                                              SUFFIX   =>'.png',
                                              UNLINK   => 1,
                                            );

        my (undef, $corre_table_file) = tempfile( "corre_table_${pop_id}-XXXXXX",
                                              DIR      => $corre_temp_dir,
                                              SUFFIX   => '.txt',
                                              UNLINK   => 1,
                                            );

        my ( $corre_commands_temp, $corre_output_temp ) =
            map
        {
            my ( undef, $filename ) =
                tempfile(
                    File::Spec->catfile(
                        CXGN::Tools::Run->temp_base($corre_temp_dir),
                        "corre_pop_${pop_id}-$_-XXXXXX"
                    ),
                    UNLINK =>0,
                );
            $filename
        } qw / in out /;

        {
            my $corre_commands_file = $c->path_to('/cgi-bin/phenome/correlation.r');
            copy( $corre_commands_file, $corre_commands_temp )
                or die "could not copy '$corre_commands_file' to '$corre_commands_temp'";
        }

        my $r_process = CXGN::Tools::Run->run_cluster(
            'R', 'CMD', 'BATCH',
            '--slave',
            "--args $heatmap_file $corre_table_file $pheno_file",
            $corre_commands_temp,
            $corre_output_temp,
            {
                working_dir => $corre_temp_dir,
                max_cluster_jobs => 1_000_000_000,
            },
            );

        sleep 1 while $r_process->alive;

        copy( $heatmap_file, $corre_image_dir )
            or die "could not copy $heatmap_file to $corre_image_dir";

        $heatmap_file = fileparse($heatmap_file);
        $heatmap_file  = $c->generated_file_uri("correlation",  $heatmap_file);
    
    return \$heatmap_file, \$corre_table_file; 
    } 

}


####
1;
####
