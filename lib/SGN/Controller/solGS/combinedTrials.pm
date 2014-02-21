package SGN::Controller::solGS::combinedTrials;

use Moose;
use namespace::autoclean;

use String::CRC;
use URI::FromHash 'uri';
use File::Path qw / mkpath  /;
use File::Spec::Functions qw / catfile catdir/;
use File::Temp qw / tempfile tempdir /;
use File::Slurp qw /write_file read_file :edit prepend_file/;
use File::Copy;
use File::Basename;
use Cache::File;
use Try::Tiny;
use List::MoreUtils qw /uniq/;
use Scalar::Util qw /weaken reftype/;
use Array::Utils qw(:all);
use CXGN::Tools::Run;
use JSON;


BEGIN { extends 'Catalyst::Controller' }



sub prepare_data_for_trials :Path('/solgs/retrieve/populations/data') Args() {
    my ($self, $c) = @_;
   
    my $ids = $c->req->param('trials');
    my  @pop_ids = split(/,/, $ids);

    my $combo_pops_id;
    my $ret->{status} = 0;

    my $solgs_controller = $c->controller('solGS::solGS');
    my $not_matching_pops;
    my @g_files;
    
    if (scalar(@pop_ids) > 1 )
    {  
        $combo_pops_id =  crc(join('', @pop_ids));
        $c->stash->{combo_pops_id} = $combo_pops_id;
      
        $solgs_controller->multi_pops_phenotype_data($c, \@pop_ids);
        $solgs_controller->multi_pops_genotype_data($c, \@pop_ids);

        $solgs_controller->multi_pops_pheno_files($c, \@pop_ids);
        my $all_pheno_files = $c->stash->{multi_pops_pheno_files};
        
        my @all_pheno_files = split(/\t/, $all_pheno_files);
        $self->find_common_traits($c, \@all_pheno_files);
        
        my $entry = "\n" . $combo_pops_id . "\t" . $ids;
        $solgs_controller->catalogue_combined_pops($c, $entry);

        my $geno_files = $c->stash->{multi_pops_geno_files};
        @g_files = split(/\t/, $geno_files);

        $solgs_controller->compare_genotyping_platforms($c, \@g_files);
        $not_matching_pops =  $c->stash->{pops_with_no_genotype_match};
     
        if (!$not_matching_pops) 
        {
            $self->save_common_traits_acronyms($c);
        }
        else 
        {
            $ret->{not_matching_pops} = $not_matching_pops;
        }
    }
    else 
    {
        my $pop_id = $pop_ids[0];
        $ret->{redirect_url} = "/solgs/population/$pop_id";
    }
   
    $ret->{combined_pops_id} = $combo_pops_id;
    $ret = to_json($ret);
    
    $c->res->content_type('application/json');
    $c->res->body($ret);
   
}


sub combined_trials_page :Path('/solgs/populations/combined') Args(0) {
    my ($c, $self) = @_;

    my $combo_pops_id = $c->req->param('combined_pops_id');

}


sub find_common_traits {
    my ($self, $c, $all_pheno_files) = @_;
    
    my @common_traits;    
    foreach my $pheno_file (@$all_pheno_files)
    {     
        open my $ph, "<", $pheno_file or die "$pheno_file:$!\n";
        my $traits = <$ph>;
        $ph->close;
        
        my @trial_traits = split(/\t/, $traits);
       
        if (@common_traits)        
        {
            @common_traits = intersect(@common_traits, @trial_traits);
        }
        else 
        {    
            @common_traits = @trial_traits;
        }
    }
   
    $c->stash->{common_traits} = \@common_traits;
}


sub save_common_traits_acronyms {
    my ($self, $c) = @_;
    
    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $solgs_controller = $c->controller('solGS::solGS');
    
    $c->stash->{pop_id} = $combo_pops_id;
    
    $self->find_common_traits_acronyms($c);
    my $acronyms_table = $c->stash->{common_traits_acronyms};

    $solgs_controller->traits_acronym_file($c);
    my $traits_acronym_file = $c->stash->{traits_acronym_file};

    write_file($traits_acronym_file, $acronyms_table);
   
}
    

sub find_common_traits_acronyms {
    my ($self, $c) = @_;

    my $combo_pops_id = $c->stash->{combo_pops_id};
    my $solgs_controller = $c->controller('solGS::solGS');
    my @common_traits_acronyms;
    
    if ($combo_pops_id)
    {
        $solgs_controller->get_combined_pops_list($c, $combo_pops_id);
        my $pops_list = $c->stash->{combined_pops_list};
      
        my @pops_list = split(/,/, $pops_list);

        foreach my $pop_id (@pops_list)
        {
            $c->stash->{pop_id} = $pop_id;
          
            $solgs_controller->traits_acronym_file($c);
            my $traits_acronym_file = $c->stash->{traits_acronym_file};
            my @traits_acronyms = read_file($traits_acronym_file);

            if (@common_traits_acronyms)        
            {
                @common_traits_acronyms = intersect(@common_traits_acronyms, @traits_acronyms);
            }
            else 
            {    
                @common_traits_acronyms = @traits_acronyms;
            }

        }
        
        $c->stash->{pop_id} = $combo_pops_id;
        my $acronym_table = join("", @common_traits_acronyms);
        $c->stash->{common_traits_acronyms} = $acronym_table;

    }
    else 
    {   
        die "An id for the combined trials is missing.";
    }


}


sub begin : Private {
    my ($self, $c) = @_;

    $c->controller("solGS::solGS")->get_solgs_dirs($c);
  
}



1;
