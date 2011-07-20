=head1 NAME

SGN::Controller::Qtl- controller for the qtl anlysis start page

=cut




package SGN::Controller::Qtl;

use Moose;
use namespace::autoclean;
use File::Spec::Functions;
use File::Temp qw / tempfile /;
use File::Path qw / mkpath  /;
use File::Copy;
use File::Basename;
use File::Slurp;

BEGIN { extends 'Catalyst::Controller'}  


sub view : PathPart('qtl/view') Chained Args(1) {
    my ( $self, $c, $id) = @_;
    
    if ( $id !~ /^\d+$/ ) 
    { 
        $c->throw_404("$id is not a valid population id.");
    }  
    elsif ( $id )
    {
        my $schema = $c->dbic_schema('CXGN::Phenome::Schema');
        my $rs = $schema->resultset('Population')->find($id);                             
        if ($rs)  
        { 
            $self->_is_qtl_pop($c, $id);
            if ( $c->stash->{is_qtl_pop} ) 
            {
                my $userid = $c->user->get_object->get_sp_person_id if $c->user;          
                $c->stash(template     => '/qtl/qtl_start/index.mas',                              
                          pop          => CXGN::Phenome::Population->new($c->dbc->dbh, $id), 
                          referer      => $c->req->path,             
                          userid       => $userid,
                    );
                $self->_link($c);
                $self->_show_data($c);           
                $self->_list_traits($c);   
                
                if ( $id == 18 ) 
                { 
                    $c->stash(heatmap_file => undef,
                              corre_table_file => undef,
                        );
                    $self->_get_trait_acronyms($c);
                   
                } 
                else 
                {
                    $self->_correlation_output($c);
                }
            } 
            else 
            {
                $c->throw_404("This not a QTL population");
            }
        }
        else 
        {
            $c->throw_404("There is no QTL population for this $id");
        }

    }
    elsif (!$id) 
    {
        $c->throw_404("You must provide a valid population id argument");
    }
}

sub download_phenotype : PathPart('qtl/download/phenotype') Chained Args(1) {
    my ($self, $c, $id) = @_;
    my $pop = CXGN::Phenome::Population->new($c->dbc->dbh, $id);
    my @pheno_data;
    foreach ( read_file($pop->phenotype_file($c))) 
    {
       push @pheno_data, [ split(/,/) ];
    }
    $c->stash->{'csv'}={ data => \@pheno_data};
    $c->forward("SGN::View::Download::CSV");
}

sub download_genotype : PathPart('qtl/download/genotype') Chained Args(1) {
    my ($self, $c, $id) = @_;
    my $pop = CXGN::Phenome::Population->new($c->dbc->dbh, $id);    
    my @geno_data;
    
    foreach ( read_file($pop->genotype_file($c))) 
    {
       push @geno_data, [ split(/,/) ];
    }
    $c->stash->{'csv'}={ data    => \@geno_data};
    $c->forward("SGN::View::Download::CSV");
}

sub download_correlation : PathPart('qtl/download/correlation') Chained Args(1) {
    my ($self, $c, $id) = @_;

    $c->stash(pop => CXGN::Phenome::Population->new($c->dbc->dbh, $id)); 
    $self->_correlation_output($c);
   
    my @corr_data;
    my $count=1;
    
    foreach ( read_file($c->stash->{corre_table_file}) )
    {
        if ($count==1) { $_ = "Traits " . $_;}
        s/\"//g; s/\s/,/g;
        push @corr_data, [ split (/,/) ];
        $count++;
    }
    
    $c->stash->{'csv'}={ data => \@corr_data };
    $c->forward("SGN::View::Download::CSV");
}

sub download_acronym : PathPart('qtl/download/acronym') Chained Args(1) {
    my ($self, $c, $id) = @_;
    my $pop = CXGN::Phenome::Population->new($c->dbc->dbh, $id);    
    $c->stash->{'csv'}={ data => $pop->get_cvterm_acronyms};
    $c->forward("SGN::View::Download::CSV");
}


sub _analyze_correlation : {
    my ($self, $c)      = @_;    
    my $pop_id          = $c->stash->{pop}->get_population_id();
    my $pheno_file      = $c->stash->{pop}->phenotype_file($c);
    my $base_path       = $c->config->{basepath};
    my $temp_image_dir  = $c->config->{tempfiles_subdir};
    my $r_qtl_dir       = $c->config->{r_qtl_temp_path};
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
         copy( $corre_table_file, $corre_file_dir )
            or die "could not copy $corre_table_file to $corre_file_dir";

        $heatmap_file = fileparse($heatmap_file);
        $heatmap_file  = $c->generated_file_uri("correlation",  $heatmap_file);
        $corre_table_file = fileparse($corre_table_file);
        $c->stash( heatmap_file     => "../../../$heatmap_file", 
                   corre_table_file => "$corre_file_dir/$corre_table_file"
            );  
    } 
}

sub _correlation_output {
    my ($self, $c)  = @_;
    my $pop         = $c->{stash}->{pop};
    my $cache       = $c->cache;
    my $key_h       = "heat_" . $pop->get_population_id();
    my $key_t       = "table_" . $pop->get_population_id();   
    my $heatmap     = $cache->get($key_h);
    my $corre_table = $cache->get($key_t);
   # $cache->remove($key_h);
   # $cache->remove($key_t);

    if  (!$corre_table  || !$heatmap) 
    {
        $self->_analyze_correlation($c);
        $heatmap = $c->stash->{heatmap_file};
        $corre_table  = $c->stash->{corre_table_file};
        $cache->set($key_h, $heatmap, (expires =>'24h'));
        $cache->set($key_t, $corre_table, (expires =>'24h'));    
    } else 
    {
        $c->stash( heatmap_file     => $heatmap,
                   corre_table_file => $corre_table,
            );               
    }
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
            
            my ($min, $max, $avg, $std, $count)= $c->stash->{pop}->get_pop_data_summary($trait_id);
            
            $c->stash( trait_id   => $trait_id,
                       trati_name => $trait_name
                );
            
            my $cvterm = CXGN::Chado::Cvterm::get_cvterm_by_name( $c->dbc->dbh, $trait_name);
            my $trait_link;
                    
            if ($cvterm)
            {
                my $cvterm_id = $cvterm->get_cvterm_id();
                $c->stash(cvterm_id =>$cvterm_id);
                $self->_link($c);
                $trait_link = $c->stash->{cvterm_page};
            } else
            {
                $self->_link($c);
                $trait_link = $c->stash->{trait_page};
            }
            $self->_link($c);
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
            my $graph_icon = $c->stash->{graph_icon};
            my $qtl_analysis_page = $c->stash->{qtl_analysis_page};
            my $cvterm_page = $c->stash->{cvterm_page};
            push  @phenotype,  [ map { $_ } ( $cvterm_page, $min, $max, $avg, $count, $qtl_analysis_page ) ];
        }
    }
    $c->stash->{traits_list} = \@phenotype;
}


sub _is_qtl_pop {
    my ($self, $c, $id) = @_;
    my $qtltool = CXGN::Phenome::Qtl::Tools->new();
    my @qtl_pops = $qtltool->has_qtl_data();

    foreach my $qtl_pop ( @qtl_pops )
    {
        my $pop_id = $qtl_pop->get_population_id();
        if ($pop_id == $id)
        {
            $c->stash->{is_qtl_pop} = 1;
            last;
        }       
    }
}


sub _link {
    my ($self, $c) = @_;
    my $pop_id     = $c->stash->{pop}->get_population_id();
    my $trait_id   = $c->stash->{trait_id};
    my $cvterm_id  = $c->stash->{cvterm_id};
    my $trait_name = $c->stash->{trait_name};
    my $term_id    = $cvterm_id ? $cvterm_id : $trait_id;
    my $graph_icon = qq | <img src="/../../../documents/img/pop_graph.png"/> |;
    
    $self->_get_owner_details($c);
    my $owner_name = $c->stash->{owner_name};
    my $owner_id   = $c->stash->{owner_id};
    
    $c->stash( cvterm_page        => qq |<a href="/chado/cvterm.pl?cvterm_id=$cvterm_id">$trait_name</a> |,
               trait_page         => qq |<a href="/phenome/trait.pl?trait_id=$trait_id">$trait_name</a> |,
               owner_page         => qq |<a href="/solpeople/personal-info.pl?sp_person_id=$owner_id">$owner_name</a> |,
               guideline          => qq |<a href="http://docs.google.com/View?id=dgvczrcd_1c479cgfb">Guidelines</a> |,
               phenotype_download => qq |<a href="/qtl/download/phenotype/$pop_id">Phenotype data</a> |,
               genotype_download  => qq |<a href="/qtl/download/genotype/$pop_id">Genotype data</a> |,
               corre_download     => qq |<a href="/qtl/download/correlation/$pop_id">Correlation data</a> |,
               acronym_download   => qq |<a href="/qtl/download/acronym/$pop_id">Trait-acronym key</a> |,
               qtl_analysis_page  => qq |<a href="/phenome/qtl_analysis.pl?population_id=$pop_id&amp;cvterm_id=$term_id" onclick="Qtl.waitPage();">$graph_icon</a> |,
        );
    
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
            :        $c->stash(show_data => undef)
            ;
    }
            
            
}

####
1;
####
