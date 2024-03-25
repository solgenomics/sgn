=head1 NAME

SGN::Controller::Qtl- controller for solQTL

=cut

package SGN::Controller::Qtl;

use Moose;
use namespace::autoclean;
use File::Spec::Functions;
use List::MoreUtils qw /uniq/;
use File::Temp qw / tempfile /;
use File::Path qw / mkpath  /;
use File::Copy;
use File::Basename;
use File::Slurp;
use Try::Tiny;
use URI::FromHash 'uri';
use Cache::File;
use Path::Class;
use Bio::Chado::Schema;
use CXGN::Phenome::Qtl;
use CXGN::Phenome::Population;

BEGIN { extends 'Catalyst::Controller'}  

sub view : Path('/qtl/view') Args(1) {
    my ($self, $c, $id) = @_;
    $c->res->redirect("/qtl/population/$id");
  
}


sub population : Path('/qtl/population') Args(1) {
    my ( $self, $c, $id) = @_;
    
    if ( $id )
    {
        $self->is_qtl_pop($c, $id);
        if ( $c->stash->{is_qtl_pop} ) 
        {
       
            my $pop =  CXGN::Phenome::Population->new($c->dbc->dbh, $id);       
            my $phenotype_file = $pop->phenotype_file($c);
            my $genotype_file =  $pop->genotype_file($c);

            my $userid = $c->user->get_object->get_sp_person_id if $c->user;          
            $c->stash(template     => '/qtl/population/index.mas',                              
                      pop          => $pop, 
                      referer      => $c->req->path,             
                      userid       => $userid,
                );
            my $size = -s $phenotype_file;
          
            $self->_link($c);
            $self->_show_data($c);           
            $self->_list_traits($c);
            $self->genetic_map($c);                
           
            $self->_get_trait_acronyms($c);
                           
            } 
            else 
            {
                $c->throw_404("$id is not a QTL population.");
            }
    }
    else 
    {
            $c->throw_404("There is no QTL population for $id");
    }

}

sub download_phenotype : Path('/qtl/download/phenotype') Args(1) {
    my ($self, $c, $id) = @_;
    
    $c->throw_404("<strong>$id</strong> is not a valid population id") if  $id =~ m/\D/;
    
    $self->is_qtl_pop($c, $id);
    if ($c->stash->{is_qtl_pop})   
    {
        my $pop             = CXGN::Phenome::Population->new($c->dbc->dbh, $id);
        my $phenotype_file  = $pop->phenotype_file($c);
    
        unless (!-e $phenotype_file || -s $phenotype_file <= 1)
        {        
            my @pheno_data = map {   s/,/\t/g; [ $_ ]; } read_file($phenotype_file);
            
            $c->res->content_type("text/plain");
            $c->res->body(join "",  map{ $_->[0]} @pheno_data);        
        }
    }
    else
    {
        $c->throw_404("<strong>$id</strong> is not a QTL population id");   
    }       
}

sub download_genotype : Path('/qtl/download/genotype') Args(1) {
    my ($self, $c, $id) = @_;
    
    $c->throw_404("<strong>$id</strong> is not a valid population id") if  $id =~ m/\D/;
   
    $self->is_qtl_pop($c, $id);
    if ($c->stash->{is_qtl_pop})
    {
       
        my $pop             = CXGN::Phenome::Population->new($c->dbc->dbh, $id);        
        my $genotype_file   = $pop->genotype_file($c);
       
        unless (!-e $genotype_file || -s $genotype_file <= 1)
        {
            my @geno_data = map { s/,/\t/g; [ $_ ]; } read_file($genotype_file);
            
            $c->res->content_type("text/plain");
            $c->res->body(join "",  map{ $_->[0]} @geno_data);   
        }
    }
    else
    {
        $c->throw_404("<strong>$id</strong> is not a QTL population id");   
    }       
}

sub download_correlation : Path('/qtl/download/correlation') Args(1) {
    my ($self, $c, $id) = @_;
    
    $c->throw_404("<strong>$id</strong> is not a valid population id") if $id =~ m/\D/;

    $self->is_qtl_pop($c, $id);
    if ($c->stash->{is_qtl_pop})
    {
    
        my $corr_file = catfile($c->path_to($c->config->{cluster_shared_tempdir}), 'correlation', 'cache',  "corre_coefficients_table_${id}");
       
        unless (!-e $corr_file || -s $corr_file <= 1) 
        {
            my @corr_data;
            my $count=1;

            foreach ( read_file($corr_file) )
            {
                if ($count==1) {  $_ = "Traits\t" . $_;}             
                s/NA//g;               
                push @corr_data, [ $_ ] ;
                $count++;
            }   
            $c->res->content_type("text/plain");
            $c->res->body(join "",  map{ $_->[0] } @corr_data);   
          
        } 
    }  
    else
    {
        $c->throw_404("<strong>$id</strong> is not a QTL population id");   
    }       
}

sub download_acronym : Path('/qtl/download/acronym') Args(1) {
    my ($self, $c, $id) = @_;

    $c->throw_404("<strong>$id</strong> is not a valid population id") if  $id =~ m/\D/;
    
    $self->is_qtl_pop($c, $id);
    if ($c->stash->{is_qtl_pop})
    {
        my $pop = CXGN::Phenome::Population->new($c->dbc->dbh, $id);    
        my $acronym = $pop->get_cvterm_acronyms;
       
        $c->res->content_type("text/plain");
        $c->res->body(join "\n",  map{ $_->[1] . "\t" . $_->[0] } @$acronym);
   
    }
    else
    {
        $c->throw_404("<strong>$id</strong> is not a QTL population id");   
    }       
}


sub _analyze_correlation  {
    my ($self, $c)      = @_;    
    my $pop_id          = $c->stash->{pop}->get_population_id();
    my $pheno_file      = $c->stash->{pop}->phenotype_file($c);
    my $base_path       = $c->config->{basepath};
    my $temp_image_dir  = $c->config->{tempfiles_subdir};
    my $r_qtl_dir       = $c->config->{solqtl};
    my $corre_image_dir = catfile($base_path, $temp_image_dir, "correlation");
    my $corre_temp_dir  = catfile($r_qtl_dir, "cache");
    
    if (-s $pheno_file) 
    {
        mkpath ([$corre_temp_dir, $corre_image_dir], 0, 0755);  
    
        my ($fh_hm, $heatmap_file)     = tempfile( "heatmap_${pop_id}-XXXXXX",
                                                  DIR      => $corre_temp_dir,
                                                  SUFFIX   => '.png',
                                                  UNLINK   => 0,
                                                );
        $fh_hm->close;
        
        print STDERR "\nheatmap tempfile: $heatmap_file\n";
       
        my ($fh_ct, $corre_table_file) = tempfile( "corre_table_${pop_id}-XXXXXX",
                                                  DIR      => $corre_temp_dir,
                                                  SUFFIX   => '.txt',
                                                  UNLINK   => 0,
                                                );
        $fh_ct->close;
        
        print STDERR "\ncorrelation coefficients tempfile: $corre_table_file\n";
        
        CXGN::Tools::Run->temp_base($corre_temp_dir);
        my ($fh_out, $filename);
        my ( $corre_commands_temp, $corre_output_temp ) =
            map
        {
            ($fh_out, $filename ) =
                tempfile(
                    File::Spec->catfile(
                        CXGN::Tools::Run->temp_base(),
                        "corre_pop_${pop_id}-$_-XXXXXX",
                         ),
                    UNLINK   => 0,
                );
            $filename
        } qw / in out /;

        $fh_out->close;
        print STDERR "\ncorrelation r output  tempfile: $corre_output_temp\n";
        
        {
            my $corre_commands_file = $c->path_to('/cgi-bin/phenome/correlation.r');
            copy( $corre_commands_file, $corre_commands_temp )
                or die "could not copy '$corre_commands_file' to '$corre_commands_temp'";
        }
        try 
        {
            print STDERR "\nsubmitting correlation job to the cluster..\n";
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

            $r_process->wait;
            sleep 5;
            print STDERR "\ndone with correlation analysis..\n";
       }
        catch 
        {  
            print STDERR "\nsubmitting correlation job to the cluster gone wrong....\n";
            my $err = $_;
            $err =~ s/\n at .+//s; #< remove any additional backtrace
            #     # try to append the R output
            try{ $err .= "\n=== R output ===\n".file($corre_output_temp)->slurp."\n=== end R output ===\n" };
            # die with a backtrace
            Carp::confess $err;
        };
        
        copy($heatmap_file, $corre_image_dir)  
            or die "could not copy $heatmap_file to $corre_image_dir";
        copy($corre_table_file, $corre_image_dir) 
            or die "could not copy $corre_table_file to $corre_image_dir";

        $heatmap_file      = fileparse($heatmap_file);
        $heatmap_file      = $c->generated_file_uri("correlation",  $heatmap_file);
        $corre_table_file  = fileparse($corre_table_file);
        $corre_table_file  = $c->generated_file_uri("correlation", $corre_table_file);
        
        print STDERR "\nheatmap tempfile after copying to the apps static dir : $heatmap_file\n";
        print STDERR "\ncorrelation coefficients after copying to the apps static dir: $corre_table_file\n";
        
        $c->stash( heatmap_file     => $heatmap_file, 
                   corre_table_file => $corre_table_file
                 );  
    } 
}

sub _correlation_output {
    my ($self, $c)      = @_;
    my $pop             = $c->{stash}->{pop};
    my $base_path       = $c->config->{basepath};
    my $temp_image_dir  = $c->config->{tempfiles_subdir};   
    my $corre_image_dir = catfile($base_path, $temp_image_dir, "correlation");
    my $cache           = Cache::File->new( cache_root  => $corre_image_dir);
    $cache->purge();

    my $key_h           = "heat_" . $pop->get_population_id();
    my $key_t           = "corr_table_" . $pop->get_population_id();   
    my $heatmap         = $cache->get($key_h);
    my $corre_table     = $cache->get($key_t); 
   
     print STDERR "\ncached heatmap file: $heatmap\n";
     print STDERR "\ncached correlation coefficients files: $corre_table\n";

    unless ($heatmap) 
    {
        $self->_analyze_correlation($c);

        $heatmap = $c->stash->{heatmap_file};      
        $corre_table  = $c->stash->{corre_table_file};

        $cache->set($key_h, $heatmap, "30 days");
        $cache->set($key_t, $corre_table, "30 days");        
    }

    $heatmap     = undef if -z $c->config->{basepath} . $heatmap;   
    $corre_table = undef if -z $c->config->{basepath} . $corre_table;
       
    $c->stash( heatmap_file     => $heatmap,
               corre_table_file => $corre_table,
             );  
 
    $self->_get_trait_acronyms($c);

}

sub _list_traits {
    my ($self, $c) = @_;      
    my $population_id = $c->stash->{pop}->get_population_id();
    my @phenotype;  
   
    if ($c->stash->{pop}->get_web_uploaded()) 
    {
        my @traits = $c->stash->{pop}->get_cvterms();
       
        foreach my $trait (@traits)  
        {
            my $trait_id   = $trait->get_user_trait_id();
            my $trait_name = $trait->get_name();
            my $definition = $trait->get_definition();
            
            my ($min, $max, $avg, $std, $count) = $c->stash->{pop}->get_pop_data_summary($trait_id);
            
            $c->stash( trait_id   => $trait_id,
                       trait_name => $trait_name
                );
                      
            $self->_link($c);
            my $trait_link = $c->stash->{trait_page};
          
            my $qtl_analysis_page = $c->stash->{qtl_analysis_page}; 
            push  @phenotype,  [ map { $_ } ( $trait_link, $min, $max, $avg, $count, $qtl_analysis_page ) ];               
        }
    }
    else 
    {
        my @cvterms = $c->stash->{pop}->get_cvterms();
        foreach my $cvterm( @cvterms )
        {
            my $cvterm_id = $cvterm->get_cvterm_id();
            my $cvterm_name = $cvterm->get_cvterm_name();
            my ($min, $max, $avg, $std, $count)= $c->stash->{pop}->get_pop_data_summary($cvterm_id);
            
            $c->stash( trait_name => $cvterm_name,
                       cvterm_id  => $cvterm_id
                );

            $self->_link($c);
            my $qtl_analysis_page = $c->stash->{qtl_analysis_page};
            my $cvterm_page = $c->stash->{cvterm_page};
            push  @phenotype,  [ map { $_ } ( $cvterm_page, $min, $max, $avg, $count, $qtl_analysis_page ) ];
        }
    }
    $c->stash->{traits_list} = \@phenotype;
}

#given $c and a population id, checks if it is a qtl population and stashes true or false
sub is_qtl_pop {
    my ($self, $c, $id) = @_;
    my $qtltool = CXGN::Phenome::Qtl::Tools->new();
    my @qtl_pops = $qtltool->has_qtl_data();

    foreach my $qtl_pop ( @qtl_pops )
    {
        my $pop_id = $qtl_pop->get_population_id();
        $pop_id == $id ? $c->stash(is_qtl_pop => 1) && last 
                       : $c->stash(is_qtl_pop => 0)
                       ;
    }
}


sub _link {
    my ($self, $c) = @_;
    my $pop_id     = $c->stash->{pop}->get_population_id();
    
    {
        no warnings 'uninitialized';
        my $trait_id   = $c->stash->{trait_id};
        my $cvterm_id  = $c->stash->{cvterm_id};
        my $trait_name = $c->stash->{trait_name};
        my $term_id    = $trait_id ? $trait_id : $cvterm_id;
        my $graph_icon = qq | <img src="/documents/img/pop_graph.png" alt="run solqtl"/> |;
    
        $self->_get_owner_details($c);
        my $owner_name = $c->stash->{owner_name};
        my $owner_id   = $c->stash->{owner_id};   
    
        $c->stash( cvterm_page        => qq |<a href="/cvterm/$cvterm_id/view">$trait_name</a> |,
                   trait_page         => qq |<a href="/phenome/trait.pl?trait_id=$trait_id">$trait_name</a> |,
                   owner_page         => qq |<a href="/solpeople/personal-info.pl?sp_person_id=$owner_id">$owner_name</a> |,
                   guideline          => qq |<a href="/qtl/submission/guide">Guideline</a> |,
                   phenotype_download => qq |<a href="/qtl/download/phenotype/$pop_id">Phenotype data</a> |,
                   genotype_download  => qq |<a href="/qtl/download/genotype/$pop_id">Genotype data</a> |,
                   corre_download     => qq |<a href="/download/phenotypic/correlation/population/$pop_id">Correlation data</a> |,
                   acronym_download   => qq |<a href="/qtl/download/acronym/$pop_id">Trait-acronym key</a> |,
                   qtl_analysis_page  => qq |<a href="/phenome/qtl_analysis.pl?population_id=$pop_id&amp;cvterm_id=$term_id" onclick="Qtl.waitPage()">$graph_icon</a> |,
            );
    }
    
}

sub _get_trait_acronyms {
    my ($self, $c) = @_;
  
    $c->stash(trait_acronym_pairs => $c->stash->{pop}->get_cvterm_acronyms());

}

sub _get_owner_details {
    my ($self, $c) = @_;
    my $owner_id   = $c->stash->{pop}->get_sp_person_id();
    my $owner      = CXGN::People::Person->new($c->dbc->dbh, $owner_id);
    my $owner_name = $owner->get_first_name()." ".$owner->get_last_name();    
    
    $c->stash( owner_name => $owner_name,
               owner_id   => $owner_id
        );
    
}

sub _show_data {
    my ($self, $c) = @_;
    my $user_id    = $c->stash->{userid};
    my $user_type  = $c->user->get_object->get_user_type() if $c->user;
    my $is_public  = $c->stash->{pop}->get_privacy_status();
    my $owner_id   = $c->stash->{pop}->get_sp_person_id();
    
    if ($user_id) 
    {        
        ($user_id == $owner_id || $user_type eq 'curator') ? $c->stash(show_data => 1) 
                  :                                          $c->stash(show_data => undef)
                  ;
    } else
    { 
        $is_public ? $c->stash(show_data => 1) 
                   : $c->stash(show_data => undef)
                   ;
    }            
}

sub set_stat_option : PathPart('qtl/stat/option') Chained Args(0) {
    my ($self, $c)  = @_;
    my $pop_id      = $c->req->param('pop_id');
    my $stat_params = $c->req->param('stat_params');
    my $file        = $self->stat_options_file($c, $pop_id);

    if ($file) 
    {
        my $f = file( $file )->openw
            or die "Can't create file: $! \n";

        if ( $stat_params eq 'default' ) 
        {
            $f->print( "default parameters\tYes" );
        } 
        else 
        {
            $f->print( "default parameters\tNo" );
        }  
    }
    $c->res->content_type('application/json');
    $c->res->body({undef});                

}

sub stat_options_file {
    my ($self, $c, $pop_id) = @_;
    my $login_id            = $c->user()->get_object->get_sp_person_id() if $c->user;
    
    if ($login_id) 
    {
        my $qtl = CXGN::Phenome::Qtl->new($login_id);
        my ($temp_qtl_dir, $temp_user_dir) = $qtl->create_user_qtl_dir($c);
        return  catfile( $temp_user_dir, "stat_options_pop_${pop_id}.txt" );
    }
    else 
    {
        return;
    }
}

    
sub qtl_form : PathPart('qtl/form') Chained Args {
    my ($self, $c, $type, $pop_id) = @_;  
    
    my $userid = $c->user()->get_object->get_sp_person_id() if $c->user;
    
    unless ($userid) 
    {
       $c->res->redirect( '/user/login' );
    }
    
    $type = 'intro' if !$type; 
   
    if (!$pop_id and $type !~ /intro|pop_form/ ) 
    {
     $c->throw_404("Population id argument is missing");   
    }

    if ($pop_id and $pop_id !~ /^([0-9]+)$/)  
    {
        $c->throw_404("<strong>$pop_id</strong> is not an accepted argument. 
                        This form expects an all digit population id, instead of 
                        <strong>$pop_id</strong>"
                     );   
    }

    $c->stash( template => $self->get_template($c, $type),
               pop_id   => $pop_id,
               guide    => qq |<a href="/qtl/submission/guide">Guideline</a> |,
               referer  => $c->req->path,
               userid   => $userid
            );   
 
}

sub templates {
    my $self = shift;
    my %template_of = ( intro      => '/qtl/qtl_form/intro.mas',
                        pop_form   => '/qtl/qtl_form/pop_form.mas',
                        pheno_form => '/qtl/qtl_form/pheno_form.mas',
                        geno_form  => '/qtl/qtl_form/geno_form.mas',
                        trait_form => '/qtl/qtl_form/trait_form.mas',
                        stat_form  => '/qtl/qtl_form/stat_form.mas',
                        confirm    => '/qtl/qtl_form/confirm.mas'
                      );
        return \%template_of;
}


sub get_template {
    my ($self, $c, $type) = @_;        
    return $self->templates->{$type};
}

sub submission_guide : PathPart('qtl/submission/guide') Chained Args(0) {
    my ($self, $c) = @_;
    $c->stash(template => '/qtl/submission/guide/index.mas');
}

sub genetic_map {
    my ($self, $c)  = @_;
    my $mapv_id     = $c->stash->{pop}->mapversion_id();
    my $map         = CXGN::Map->new( $c->dbc->dbh, { map_version_id => $mapv_id } );
    my $map_name    = $map->get_long_name();
    my $map_sh_name = $map->get_short_name();
  
    $c->stash( genetic_map => qq | <a href=/cview/map.pl?map_version_id=$mapv_id>$map_name ($map_sh_name)</a> | );

}

sub search_help : PathPart('qtl/search/help') Chained Args(0) {
    my ($self, $c) = @_;
    $c->stash(template => '/qtl/search/help/index.mas');
}

sub show_search_results : PathPart('qtl/search/results') Chained Args(0) {
    my ($self, $c) = @_;
    my $trait = $c->req->param('trait');
    $trait =~ s/(^\s+|\s+$)//g;
    $trait =~ s/\s+/ /g;
               
    my $rs = $self->search_qtl_traits($c, $trait);

    if ($rs)
    {
        my $rows = $self->mark_qtl_traits($c, $rs);
                                                        
        $c->stash(template   => '/qtl/search/results.mas',
                  data       => $rows,
                  query      => $c->req->param('trait'),
                  pager      => $rs->pager,
                  page_links => sub {uri ( query => { trait => $c->req->param('trait'), page => shift } ) }
            );
    }
    else 
    {
        $c->stash(template   => '/qtl/search/results.mas',
                  data       => undef,
                  query      => undef,
                  pager      => undef,
                  page_links => undef,
            );
    }
}

sub search_qtl_traits {
    my ($self, $c, $trait) = @_;
    
    my $rs;
    if ($trait)
    {
        my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
        my $schema    = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
        my $cv_id     = $schema->resultset("Cv::Cv")->search(
            {name => 'solanaceae_phenotype'}
            )->single->cv_id;

        $rs = $schema->resultset("Cv::Cvterm")->search(
            { name  => { 'LIKE' => '%'.$trait .'%'},
              cv_id => $cv_id,            
            },          
            {
              columns => [ qw/ cvterm_id name definition / ] 
            },    
            { 
              page     => $c->req->param('page') || 1,
              rows     => 10,
              order_by => 'name'
            }
            );       
    }
    return $rs;      
}

sub mark_qtl_traits {
    my ($self, $c, $rs) = @_;
    my @rows =();
    
    if (!$rs->single) 
    {
        return undef;
    }
    else 
    {  
        my $qtltool  = CXGN::Phenome::Qtl::Tools->new();
        my $yes_mark = qq |<font size=4 color="#0033FF"> &#10003;</font> |;
        my $no_mark  = qq |<font size=4 color="#FF0000"> X </font> |;

        while (my $cv = $rs->next) 
        {
            my $id   = $cv->cvterm_id;
            my $name = $cv->name;
            my $def  = $cv->definition;

            if (  $qtltool->is_from_qtl( $id ) ) 
            {                         
                push @rows, [ qq | <a href="/cvterm/$id/view">$name</a> |, $def, $yes_mark ];
           
            }
            else 
            {
                push @rows, [ qq | <a href="/cvterm/$id/view">$name</a> |, $def, $no_mark ];
            }      
        } 
        return \@rows;
    } 
}


sub qtl_traits : PathPart('qtl/traits') Chained Args(1) {
    my ($self, $c, $index) = @_;
    
    if ($index =~ /^\w{1}$/) 
    {
        my $traits_list = $self->map_qtl_traits($c, $index);
    
        $c->stash( template    => '/qtl/traits/index.mas',
                   index       => $index,
                   traits_list => $traits_list
            );
    }
    else 
    {
        $c->res->redirect('/search/qtl');
    }
}

sub all_qtl_traits : PathPart('qtl/traits') Chained Args(0) {
    my ($self, $c) = @_;
    $c->res->redirect('/search/qtl');
}

sub filter_qtl_traits {
    my ($self, $index) = @_;

    my $qtl_tools = CXGN::Phenome::Qtl::Tools->new();
    my ( $all_traits, $all_trait_d ) = $qtl_tools->all_traits_with_qtl_data();

    return [
        sort { $a cmp $b  }
        grep { /^$index/i }
        uniq @$all_traits
    ];
}

sub map_qtl_traits {
    my ($self, $c, $index) = @_;

    my $traits_list = $self->filter_qtl_traits($index);
    
    my @traits_urls;
    if (@{$traits_list})
    {
        foreach my $trait (@{$traits_list})
        {
            my $cvterm = CXGN::Chado::Cvterm::get_cvterm_by_name( $c->dbc->dbh, $trait );
            my $cvterm_id = $cvterm->get_cvterm_id();
            if ($cvterm_id)
            {
                push @traits_urls,
                [
                 map { $_ } 
                 (
                  qq |<a href=/cvterm/$cvterm_id/view>$trait</a> |
                 )
                ];
            }
            else
            {
                my $t = CXGN::Phenome::UserTrait->new_with_name( $c->dbc->dbh, $trait );
                my $trait_id = $t->get_user_trait_id();
                push @traits_urls,
                [
                 map { $_ } 
                 (
                  qq |<a href=/phenome/trait.pl?trait_id=$trait_id>$trait</a> |
                 )
                ];
            }
        }
    }
   
    return \@traits_urls;
}

__PACKAGE__->meta->make_immutable;
####
1;
####
