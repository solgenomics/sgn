=head1 DESCRIPTION
creates all the web forms for the qtl data submission
and sends the data to qtl_load.pl for processing
and loading it to the database.

=head1 AUTHOR
Isaak Y Tecle (iyt2@cornell.edu)

=cut



use strict;
my $qtl_form_detail_page = CXGN::Phenome::QtlFormDetailPage->new();

package CXGN::Phenome::QtlFormDetailPage;



use File::Spec;
use CXGN::VHost;
use CXGN::Page;
use CXGN::Scrap;
use CXGN::Scrap::AjaxPage;
use CXGN::Page::FormattingHelpers qw /info_section_html 
                                      page_title_html
                                      columnar_table_html 
                                      html_optional_show 
                                      info_table_html
                                      tooltipped_text
                                      html_alternate_show
                                      /;
use CXGN::DB::Connection;
use CXGN::Phenome::Qtl;
use CXGN::Phenome::Qtl::Tools;
use CXGN::Phenome::Population;
use CXGN::Login;


sub new { 
    my $class = shift;
    my $self = bless {}, $class;   
    $self->display();
    
    return $self; 
}


sub display {
    my $self = shift;
    my $dbh = CXGN::DB::Connection->new();
    my $login = CXGN::Login->new($dbh);
   
    my $sp_person_id = $login->verify_session();

  
    my %args = {};
    my $page = CXGN::Page->new("SGN", "isaak");
    $page->jsan_use("CXGN.Phenome.Tools");
    $page->jsan_use("CXGN.Phenome.Qtl");
    $page->jsan_use("MochiKit.DOM");
    $page->jsan_use("MochiKit.Async");
    $page->jsan_use("Prototype");
    $page->jsan_use("jQuery");

    %args = $page->get_all_encoded_arguments();
    my $type = $args{type};
   
    my $pop_id = $args{pop_id};
    if ($sp_person_id) {
	my $intro = $self->intro();
	my ($org_submit, $pop_submit) = $self->org_pop_form();
	my $traits_submit = $self->traits_form($pop_id);      
	my $pheno_submit = $self->pheno_form($pop_id);
	my $geno_submit = $self->geno_form($pop_id);
	my $stat_submit = $self->stat_form($pop_id);
	my $conf_submit = $self->conf_form($pop_id);
	

	if(!$type) {
	    $page->header("QTL Data Submission Page");
	    print page_title_html("Step 0:  Introduction");
	    print $intro;
	    
	}

	elsif($type eq 'pop_form') {
	    $page->header("QTL Data Submission Page");
	    print page_title_html("Step 1:  Submit Population Details");
	    print $org_submit;
	    print $pop_submit;
	}


	elsif ($type eq 'trait_form') {
	     $page->header("QTL Data Submission Page");
	     print page_title_html("Step 2: Submit the List of Traits");
	     print $traits_submit;
	   
	}


	elsif ($type eq 'pheno_form') {
	    $page->header("QTL Data Submission Page");
	     print page_title_html("Step 3: Submit the Phenotype Data");
	     print $pheno_submit;
	     
	}

	elsif ($type eq 'geno_form') {
	    $page->header("QTL Data Submission Page");
	     print page_title_html("Step 4: Submit the Genotype Data");
	     print $geno_submit;
	   
	}


	elsif ($type eq 'stat_form') {
	    $page->header("QTL Data Submission Page");
	     
	    print page_title_html("Step 5: Set the Statistical Parameters 
                                    for the QTL Analysis"
                                  );
	     print $stat_submit;
	    
	}	
	
	elsif ($type eq 'confirm') {
	    $page->header("Confirmation page");
	    print page_title_html("Step 6: Confirmation");	   
	    print $conf_submit;	    
	   
	}	
	
	$page->footer();

}

    else {
	print "To access the QTL data submission form and analysis, please login first. 
           <br/>If you don't have an account with SGN, you can create 
           one using this <a href= /solpeople/new-account.pl>form</a>.";

	$page->footer();
	
	exit();

    }

}


sub org_pop_form {  
    my $self = shift;
       
    my $taxon_subtitle = qq| <a href="javascript:Qtl.toggleAssociateTaxon()">[Select Organism]</a> |;
    my $required = qq | <font color="red"><sup>*</sup></font>|;
    my $organism_form = $self->associate_organism();  

    my $guide = $self->guideline();

    my $org_sec = CXGN::Page::FormattingHelpers::info_section_html(
	                                                           title     =>"Select Organism",
			                                           subtitle  =>$taxon_subtitle . " | " . $guide ,
			                                           contents  => $organism_form,
			                                           id        =>"organism_search",
			                                          );
    my $pop_sec = CXGN::Page::FormattingHelpers::info_section_html(
                                                                  title    =>'Population Details',
    			                                          contents =>"$required <i>must be filled.</i> ", 
	                                                          );   
   
    my $qtltools = CXGN::Phenome::Qtl::Tools->new();    
    my %cross_types =  $qtltools->cross_types();

 
    my $cross_options;      
    foreach my $key (keys %cross_types) {    
	$cross_options .= qq |<option value="$key">$cross_types{$key} |;	     
    }


    my $parent_m = tooltipped_text('Male parent', 'format eg. Solanum lycopersicum cv moneymaker'); 
                                     
    my $parent_f = tooltipped_text('Female parent', 'format eg. Solanum lycopersicum cv micro tom');

    my $pop_form = qq^  
    <form action="qtl_load.pl" method="POST" enctype="MULTIPART/FORM-DATA">        
     $pop_sec
     <table>
     <tr>
	 <td>Cross type$required</td>
	 <td> <select name="pop_type">
	          $cross_options
             </select>
         </td>
     </tr>
     <tr>
	<td>Population name$required</td>
	<td><input type="text" name="pop_name" size=42></td>    
     </tr>
     <tr>
         <td>Population description$required</td>
         <td><textarea name="pop_desc" rows = 5 cols=44></textarea></td>
     </tr>  
     <tr>
	<td>$parent_f$required</td>
	<td><input type="text" name="pop_female_parent" size=24></td>
	<td>$parent_m$required</td> 
	<td><input type="text" name="pop_male_parent" size=24></td> 
     </tr>
     <tr>
	<td>Recurrent parent</td>
	<td><input type="text" name="pop_recurrent_parent" size=24></td>
	<td>Donor parent</td>
	<td><input type="text" name="pop_donor_parent" size=24></td> 	 	 
     </tr> 
     <tr>
      <td>Do you want to make the data public?</td>
      <td><input type="radio" name="pop_is_public" value="true" checked />Yes</td>      
      <td><input type="radio" name="pop_is_public" value="false" />No</td> 
     </tr> 
     <tr>
       <td>&nbsp;</td><td>&nbsp;</td>
       <td><input type="hidden" name="type" value="pop_form"></td>
       <td><input type="submit" value="Submit"></td>      
     </tr>
     </table>
     </form>

^;

return $org_sec, $pop_form;

}
#########################




sub traits_form {
    my $self = shift;
    my $pop_id = shift;
  
    my $guide = $self->guideline();
    my $trait = tooltipped_text('Traits list', 'in tab delimited format');
    
    my $traits_sec = CXGN::Page::FormattingHelpers::info_section_html(
                                                                  title    => 'Traits list',
	                                                          subtitle => $guide,
			                                          contents => " ", 
	                                                          );  

    my $traits_form = qq^
    <form action="qtl_load.pl" method="POST" enctype="MULTIPART/FORM-DATA">        
     $traits_sec  
     <table cellspacing=20>
     <tr>
       <td>$trait:</td>
       <td><input type="file" name="trait_file" size=40>
       <td> <input type="hidden" name="type" value="trait_form"></td>
       <td> <input type="hidden" name="pop_id" value = $pop_id></td>
       <td><input type="submit" value="Submit"> </td>
     </tr>            
     </table>
     </form>
^;

return $traits_form;

}

sub pheno_form {
    my $self = shift;
    my $pop_id = shift;
    my $guide= $self->guideline();
    
    my $phenotype = tooltipped_text('Phenotype dataset', 'in tab delimited format');
    
    my $pheno_sec = CXGN::Page::FormattingHelpers::info_section_html(
                                                                  title    => 'Phenotype dataset',
                                                                  subtitle => "$guide",
			                                          contents => " ", 
	                                                          );  

    my $pheno_form = qq^
    <form action="qtl_load.pl" method="POST" enctype="MULTIPART/FORM-DATA">        
     $pheno_sec  
     <table cellspacing=20>
     <tr>
       <td>$phenotype:</td>
       <td><input type="file" name="pheno_file" size=40>
       <td> <input type="hidden" name="type" value="pheno_form"></td> 
       <td> <input type="hidden" name="pop_id" value = $pop_id></td>
       <td><input type="submit" value="Submit"> </td>
     </tr>            
    </table>
</form>
^;
 
return $pheno_form;

}


sub geno_form {
    my $self = shift;
    my $pop_id = shift;
    my $guide= $self->guideline();

    my $genotype = tooltipped_text('Genotype dataset', 'in tab delimited format');
    my $geno_sec = CXGN::Page::FormattingHelpers::info_section_html(
                                                                  title    => 'Genotype dataset',
                                                                  subtitle => $guide,
			                                          contents => " ", 
	                                                          );   
    my $geno_form = qq^
    <form action="qtl_load.pl" method="POST" enctype="MULTIPART/FORM-DATA">        
     $geno_sec  
     <table cellspacing=20>
     <tr>
        <td>$genotype:</td>
	<td><input type="file" name="geno_file" size=40>
	<td> <input type="hidden" name="type" value="geno_form"></td>
	<td> <input type="hidden" name="pop_id" value=$pop_id></td>  
	<td><input type="submit" value="Submit"> </td>
     </tr>  
     </table>
     </form>
^;

return $geno_form;

}

    
sub stat_form {
    my $self = shift;
    my $pop_id = shift;
    my $guide = $self->guideline();
    my $no_draws = tooltipped_text('No. of imputations', 'required only if the 
                                    Simulate method is selected for the 
                                    calculation of QTL genotype probability method and Multiple Imputation');
    my $permu_level = tooltipped_text('Significance level of permutation test', 
                                      'required only if permutation analysis 
                                      (LOD threshold) is run');
    my $genome_scan = tooltipped_text('Genome scan size (cM):', 'not required for Marker Regression'
                                      );
    my $qtl_prob = tooltipped_text('QTL genotype probablity method:', 'not required for Marker Regression' 
                                      );
    
    my $stat_sec =CXGN::Page::FormattingHelpers::info_section_html(
                                                                  title   => 'Statistical Parameters',
                                                                  subtitle => $guide,
			                                          contents => " ",
	                                                          ); 
 

    my $stat_form = qq^    
    <form action="qtl_load.pl" method="POST" enctype="MULTIPART/FORM-DATA">  
    
	$stat_sec
    
    <table cellspacing=20>
	<tr><td>QTL model: </td>
	    <td> <select name="stat_qtl_model">
	                 <option>
                         <option>Single-QTL Scan
			 <option style="color: #FF0000;text-decoration: line-through">Two-QTL Scan--currently not available
			 </select>
	   </td>
           <td>QTL mapping method:</td>
	   <td><select name="stat_qtl_method">	         
	            <option>
                    <option>Marker Regression
                    <option>Maximum Likelihood 
		    <option>Haley-Knott Regression
                    <option>Multiple Imputation
		</select>
	   </td>
      </tr>
      <tr><td>$qtl_prob</td>
          <td><select name="stat_prob_method">
                      <option>
	              <option>Calculate
                      <option>Simulate
	      </select>
	 </td>
         <td>QTL genotype probability significance level:</td>
         <td><select name="stat_prob_level">
	            <option>
                    <option>0.001
                    <option>0.05
		    <option>0.1		    
	   </select>	
         </td>
         </tr>
         <tr>
         <td>$genome_scan</td>
         <td><select name="stat_step_size">
                     <option>
	             <option>zero
		     <option>1
                     <option>2.5
		     <option>5
		     <option>10
	      </select>
	 </td>    
         <td>$no_draws</td>
	 <td><select name="stat_no_draws">
	            <option>
	            <option>5
                    <option>10
		    <option>15
		    <option>20
	    </select>	
        </td>       
    </tr>
    <tr>
       <td>No. of permutations:</td>
       <td><select name="stat_permu_test">
	            <option>
                    <option>None
                    <option>100
		    <option>1000		    
	   </select>
       </td>
       <td>$permu_level:</td>
       <td> <select name="stat_permu_level">
	            <option>
                    <option>0.05
                    <option>0.001
		    <option>0.1		    
	   </select>
       </td>
    </tr>
    <tr>      
      <td> <input type="hidden" name="type" value="stat_form"></td>  
      <td> <input type="hidden" name="pop_id" value = $pop_id ></td>
    </tr>
    <tr>      
      <td></td>
      <td><input type="submit" value="Submit"> </td>
      <td></td> 
      <td> <input type="reset"  value="Reset"></td>      
    </tr>
   </table>
   </form>  
^;


return $stat_form;

}


sub associate_organism {
    my $self = shift;    
   
    my $associate = qq^         
     <div id= 'associateTaxonForm' style="display: none">
     <div id= "organism_search">
    Common name:
    <input type="text"
           style="width: 50%"
           id="organism_name"
           onkeyup="Qtl.getTaxons(this.value)">
    <input type="button"
           id="associate_taxon_button"
           value="associate organism"
           disabled="true"	  
           onclick="Qtl.associateTaxon();this.disabled=false;">
    <select id="taxon_select"
            style="width: 100%"
            onchange="Tools.enableButton('associate_taxon_button');"	                           
            size=10>
       </select>
  </div>
 
</div>
^;	

    return $associate;

   
}

sub conf_form {
    my $self = shift;
    my $pop_id = shift;
    my $guide = $self->guideline();
    my $dbh = CXGN::DB::Connection->new();

    my $conf_sec =CXGN::Page::FormattingHelpers::info_section_html(
                                                                  title   => ' ',
                                                                  subtitle => "$guide",
			                                          contents => ' ',
                                                               );

    my ($pop_link, $pop_name);
    
    if ($pop_id)  {
	my $pop = CXGN::Phenome::Population->new($dbh, $pop_id);
	$pop_name = $pop->get_name();
	$pop_link = qq | <a href="/phenome/population.pl?population_id=$pop_id"><b>$pop_name</b></a> |;	                                                      
    }
    
    my $conf_form = qq^   
    <form action=" " method="POST" enctype="MULTIPART/FORM-DATA">  
    $conf_sec
    <table cellspacing=20>
    <tr>
      <td><b><p>You have successfully  uploaded your QTL data.</p> 
           <p>On the next page you will see the population data summary. 
          The qtl analysis is performed on-the-fly and you need to click the 
          graph icon  corresponding to the trait of your interest to proceed 
          with the QTL mapping analysis. The QTL analysis takes a few minutes, 
          so please be patient. </p>
          <p>To continue to the QTL analysis page, follow the link below:</p>
          $pop_link</b>
      </td>
     </tr>   
   </table>
  </form>

^; 

return $conf_form;    

}


sub intro {
    my $self = shift;
    my $guide = $self->guideline();
    my $intro_sec =CXGN::Page::FormattingHelpers::info_section_html(
                                                                 title => 'Introduction',
                                                                  subtitle   => $guide,
			                                          contents => ' ',
                                                               );

   
    my $intro = qq^
       <form action="qtl_load.pl" method="POST" enctype="MULTIPART/FORM-DATA">  
        $intro_sec
      <table cellspacing=20>
	<tr><td>
	   
        <p>The uploading of QTL data needs to be done in one session. 
           Therefore, have ready your data files before starting the 
           process.
        </p> 
        
        <p>The data you need are:</p>
       
        <ul>
           <li>Some basic information about the population
           <li>Traits file (tab delimited): List of traits, 
                definition, units of measurement. 
           <li>Phenotype data file (tab delimited): 
           <li>Genotype data file (tab delimited): 
           <li>Statistical parameters.
        </ul>

        <p>The QTL data  uploading software is at Beta stage. If you have any problems 
           uploading your data or remarks, please send us your feedback.
        </p>
     </td>
    </tr>
    <tr> 
      <td> <input type="hidden"  name = "type" value="begin"> </td>
      <td> <input type="submit" value="Begin Uploading"> </td>
    </tr>
   </table>
  </form>
^;

return $intro;    

}


sub guideline {
    my $self = shift;
    return my $guideline = qq |<a  href="http://docs.google.com/View?id=dgvczrcd_1c479cgfb">Guidelines</a> |;
}
