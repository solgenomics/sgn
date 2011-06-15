=head1 NAME

SGN::Controller::Qtl- controller for the qtl anlysis start page

=cut




package SGN::Controller::Qtl;

use Moose;

use namespace::autoclean;


BEGIN { extends 'Catalyst::Controller'}  



use File::Spec::Functions;
use File::Temp qw / tempfile /;
use File::Path qw / mkpath  /;
use File::Copy;
use File::Basename;




#use Catalyst qw / cache /;
# sub auto :Args(0) {
#     my ($self, $c) = @_;
    
#     ($c->req->args->[0] !~ /^\d+$/ or !$c->req->args->[0]) ? $c->throw_404("$c->req->args->[0] is not a valid population.") 
#          :   $c->stash(population => CXGN::Phenome::Population->new($c->dbc->dbh , $c->req->args->[0]));
#     $c->stash(tempdir  => $c->get_conf("tempfiles_subdir")."/correlation",
#                 basepath => $c->get_conf("basepath"),
#                 r_qtl    => $c->get_conf("r_qtl_temp_path"), 
#                 guide    => $self->guideline(),                                                
#         );     
   
#     return 1;
# }
# sub no_argument :PathPart('qtl/view') {
#     my ($self, $c) = @_;
#     $c->throw_404("You must provide a valid population id argument");
# }
    

sub view : PathPart('qtl/view') Chained Args(1) {
    my ( $self, $c, $id) = @_;
    
    if ( $id !~ /^\d+$/ ) 
    { $c->throw_404("$id is not a valid population id.");
    }  
    elsif ($id ){
        my $schema = $c->dbic_schema('CXGN::Phenome::Schema');
        my $rs = $schema->resultset('Population')->find($id);                             
        if ($rs)  { 
           
            $c->stash(template     => '/qtl/qtl_start/index.mas',                              
                      pop          => CXGN::Phenome::Population->new($c->dbc->dbh, $id),                                
                      referer      => $c->req->path,
                      guide        => $self->guideline,                     
                );
            
            $self->_list_traits($c);
          # my ($heatmap, $corr_table) = 
               $self->_correlation_output($c, $c->stash->{pop});           
           # $c->stash(heatmap    => $heatmap,
           #           corr_table => $corr_table
           #     );

        }
        else 
        {
            $c->throw_404("There is no QTL population for this $id");
        }

    }
    elsif (!$id) {
        $c->throw_404("You must provide a valid population id argument");
    }
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
    my ($self, $c)   = @_;
    
    my $pop_id          = $c->stash->{pop}->get_population_id();
    my $pheno_file      = $c->stash->{pop}->phenotype_file($c);
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
    
        $c->stash( heatmap_file     => \$heatmap_file, 
                   corre_table_file =>\$corre_table_file
            ); 
    } 
}

sub _correlation_output {
    my ($self, $c, $pop) = @_;

 
    my $cache = $c->cache;
    my $key_h   = "heat_$pop->get_population_id()";
    my $key_t   = "table_$pop->get_population_id()";
    my $heatmap = $cache->get($key_h);
    my $corre_table = $cache->get($key_t);
   
    if  (!$heatmap || !$corre_table) {
        $self->_analyze_correlation($c);
        $heatmap = $c->stash->{heatmap_file};
        $corre_table  = $c->stash->{corre_table_file};
        $cache->set($key_h, $heatmap, '24h');
        $cache->set($key_t, $corre_table, '24h');
    } else 
    {
        $heatmap = $c->stash->( heatmap_file     => $heatmap,
                                corre_table_file => $corre_table
        );
    }
}


sub _list_traits {
    my ($self, $c) = @_;
   
    my $graph_icon    = qq |<img src="/../../../documents/img/pop_graph.png"/> |;  
    my $population_id = $c->stash->{pop}->get_population_id();
    my @phenotype;    
    
    if ($c->stash->{pop}->get_web_uploaded()) 
    {
        my @traits = $c->stash->{pop}->get_cvterms();
        
        foreach my $trait (@traits)  
        {
            my $trait_id = $trait->get_user_trait_id();
            my $trait_name = $trait->get_name();
            my $definition = $trait->get_definition();
            my ($min, $max, $avg, $std, $count)= $c->stash->{pop}->get_pop_data_summary($trait_id);

            my $cvterm = CXGN::Chado::Cvterm::get_cvterm_by_name( $c->dbc->dbh, $trait_name);
            my $trait_link;
                    
            if ($cvterm)
            {
                my $cvterm_id = $cvterm->get_cvterm_id();
                $trait_link = qq |<a href="/chado/cvterm.pl?cvterm_id=$cvterm_id">$trait_name</a>|;

            } else
            {
                $trait_link = qq |<a href="/phenome/trait.pl?trait_id=$trait_id">$trait_name</a>|;
            }

           
            push  @phenotype,  [map {$_} ($trait_link,
                                    $min, $max, $avg, $count,
                                          qq | <a href="/phenome/qtl_analysis.pl?population_id=$population_id&amp;cvterm_id=$trait_id">$graph_icon</a>| 
                                )];
               
        }
    }
     else 
     {
         my @cvterms = $c->stash->{pop}->get_cvterms();
         foreach my $cvterm(@cvterms)
         {
             my $cvterm_id = $cvterm->get_cvterm_id();
             my $cvterm_name = $cvterm->get_cvterm_name();
             my ($min, $max, $avg, $std, $count)= $c->stash->{pop}->get_pop_data_summary($cvterm_id);                        
             push  @phenotype,  [ map {$_} (  qq|<a href="/chado/cvterm.pl?cvterm_id=$cvterm_id">$cvterm_name</a>|, $min, $max, $avg, $count, qq | <a href="/phenome/qtl_analysis.pl?population_id=$population_id&amp;cvterm_id=$cvterm_id">$graph_icon</a> | ) 
             ];
         }

     }
    $c->stash->{traits_list} = \@phenotype;
}


sub _is_qtl_pop {
    my ($self, $c) = @_;
    my $qtltool = CXGN::Phenome::Qtl::Tools->new();
    my @qtl_pops = $qtltool->has_qtl_data();

    foreach my $qtl_pop (@qtl_pops)
    {
        my $pop_id = $qtl_pop->get_population_id();
        if ($pop_id == $c->stash->{pop}->get_population_id())
        {
            $c->stash->{is_qtl_pop} = 1;
            last;
        }
       
    }
}


sub _links {
    my ($self, $c, $cvterm_id) = @_;
    my $pop_id = $c->stash->{pop}->get_population_id();
    
    $c->stash(qtl_analysis => qq |<a href="/phenome/qtl_analysis.pl?population_id =$pop_id&amp;cvterm_id=$cvterm_id"></a>|,             qtl_graph    => qq |<img src="/../../../documents/img/pop_graph.png"/> |
        )
    
}

####
1;
####
