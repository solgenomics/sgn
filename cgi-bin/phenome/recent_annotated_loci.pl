#!usr/bin/perl
use warnings;
use strict;

use CXGN::Page;
use CXGN::Login;
use CXGN::People;
use CXGN::Page::WebForm;

use CXGN::Phenome::Locus;
use CXGN::Page::FormattingHelpers qw/info_section_html
                                     page_title_html
				     columnar_table_html
                                     info_table_html
                                     html_optional_show
                                     html_alternate_show
                                    /;
#use base qw /CXGN::Page::WebForm/;
my $dbh= CXGN::DB::Connection->new('phenome');
my $logged_sp_person_id = CXGN::Login->new($dbh)->verify_session();

my $page = CXGN::Page->new("Recently annotated loci","Naama");
#$page->jsan_use("Dynarch.Calendar"); 
$page->jsan_use("CXGN.Calendar");

$page->header();
#$page->jsan_use("CXGN.Calendar", "CXGN.Phenome.Locus"); 


my $form = CXGN::Page::WebForm->new();

$form->set_data(date =>'');
$form->template(<<HTML);
     <input type="text" name="date"  id="cal_target" />
    <input type="submit" id="submit_button" value="Submit" />
   
HTML
print '<form action="" method="get">',
    '<h3 align="center">Find recently annotated loci</h3>',
    
    $form->to_html,
    
    '</form>'; #now print the auto-filled-in form
my $cal=get_calendar();
print $cal;

######Javascript calendar: this stuff is not working. I guess the Calendar object is not called correctly.#####
print <<EOT;

	<script language="javascript" type="text/javascript"  >
	<!-- 
    
    var c = new Calendar;
    c.showFlatCalendar('');
    c.showCalendar('cal_target', '%m/%d/%Y', '24', '1');
    -->
	</script>    
EOT



my %params= $page->cgi_params();
$form->from_request( \%params );

my $date = $params{date};


if ($date) { print_results($dbh, $date) } ;


$page->footer();

sub get_calendar {
    my $c=qq| 
	
	<a href="javascript:Calendar.showCalendar('cal_id')">[Calendar]</a><br>
	
	<div id='popUpCal' style="display: none">
	<div id='cal_id'>
	<input type="hidden" 
	value=""
	id="">
	</div>
	</div>
	|;
}   

sub print_results {
    my $dbh =shift;
    my $date = shift;

    my %locus_edits = CXGN::Phenome::Locus::get_recent_annotated_loci($dbh, $date);
    
    ####################
    #locus updates and creates section
    ###################
    my @locus_updates;
    my $action;
    foreach my $locus(@{$locus_edits{loci} }) {
	my $locus_id = $locus->get_locus_id();
	my $locus_name=$locus->get_common_name() . " " . $locus->get_locus_name();
	my $updated_by= $locus->get_updated_by() || ($locus->get_owners())[0];
	my $person= get_person_info($dbh, $updated_by);
	my $udate = $locus->get_modification_date(); 
	$action='Updated';
	if (!$udate ) { #&& $locus->get_create_date() > $date) {
	    $action= 'Created';
	    $udate = $locus->get_create_date() ; 
	} 
	if ($locus->get_obsolete() eq 't') { $action= 'Obsoleted'; }
	push @locus_updates, [map {$_} (qq|<a href="locus_display.pl?locus_id=$locus_id">$locus_name</a>|, $person,$udate, $action)];   
    }
    my $updated_loci= columnar_table_html(headings => ['Locus name',
						       'Updated by',
						       "Date",
						       ],
					  data=>\@locus_updates, __align=>'llc') if @locus_updates;
    
    
    print info_section_html(title   => "Updated loci (" . scalar(@locus_updates) . ")",
			    contents =>$updated_loci,
			    collapsible=>1,
			    collapsed=>0,
			    );
    
    ####################
    #Locus alias section
    ####################
    
    my @alias_updates;;
    foreach my $alias(@{$locus_edits{aliases} } ) {
	my $locus_id=$alias->get_locus_id();
	my $locus_name=$alias->get_common_name() ." " . $alias->get_locus_name();
	my $alias_name= $alias->get_locus_alias();
	my $alias_person_id=  $alias->get_sp_person_id();
	my $udate= $alias->get_modification_date() || $alias->get_create_date();
	my $alias_obsoleted =  $alias->get_obsolete();
	$action='Created';
	my $person= get_person_info($dbh, $alias_person_id);
	if ($alias_obsoleted eq 't' ) { $action= 'Obsoleted'; }
	push @alias_updates, [map {$_} (qq|<a href="locus_display.pl?locus_id=$locus_id">$locus_name</a>|, $alias_name, $person, $udate, $action)];
    }
    
    my $aliases;
    if (@alias_updates) { $aliases= columnar_table_html(headings => ['Locus name',
								     'Synonym',
								     'Submitted by',
								     'Date',
								     ],
							data=>\@alias_updates, __align=>'llc'); }
    
    print info_section_html(title   => "Locus synonyms (" . scalar(@alias_updates) . ")",
			    contents => $aliases ,
			    collapsible=>1,
			    );
    
    ####################
    #alleles section
    ####################
   
    my @allele_updates;
    
    foreach my $allele(@{$locus_edits{alleles} } ) {
	my $allele_id=$allele->get_allele_id();
	my $locus_name=$allele->get_locus()->get_common_name() ." " . $allele->get_locus_name();
	my $allele_name= $allele->get_allele_name();
	my $allele_symbol=$allele->get_allele_symbol();
	my $allele_owner=  $allele->get_sp_person_id();
	my $udate= $allele->get_modification_date() ;
	my $allele_obsoleted =  $allele->get_obsolete();
	$action='Updated';
	if (!$udate) {
	    $udate=$allele->get_create_date();
	    $action='Created';
	}
	my $person= get_person_info($dbh, $allele_owner);
	if ($allele_obsoleted eq 't' ) { $action= 'Obsoleted'; }
	push @allele_updates, [map {$_} ($locus_name, qq|<a href="allele.pl?allele_id=$allele_id">$allele_symbol</a>|, $person, $udate, $action)];
    }
    
    my $alleles;
    if (@allele_updates) {
	$alleles= columnar_table_html(headings => ['Locus name',
						   'Allele symbol',
						   'Submitted by',
						   'Date',
						   ],
				      data=>\@allele_updates, __align=>'llc');}
    
    
    print info_section_html(title   => "Alleles (" . scalar(@allele_updates) . ")",
			    contents => $alleles ,
			    collapsible=>1,
			    );			   

    ####################
    #locus dbxrefs
    ####################
   
    my @ld_updates;
    
    foreach my $ld(@{$locus_edits{locus_dbxrefs} } ) {
	my $locus_id=$ld->get_locus_id();
	my $locus=CXGN::Phenome::Locus->new($dbh, $locus_id);
	my $dbxref=CXGN::Chado::Dbxref->new($dbh, $ld->get_dbxref_id());
	my $annotation= get_annotation($dbxref);
	my $locus_symbol=$locus->get_common_name() ." " . $locus->get_locus_symbol();
	my $ld_owner=  $ld->get_sp_person_id();
	my $udate= $ld->get_modification_date() ;
	my $ld_obsoleted =  $ld->get_obsolete();
	$action='Updated';
	if (!$udate) {
	    $udate=$ld->get_create_date();
	    $action='Created';
	}
	my $person= get_person_info($dbh, $ld_owner);
	if ($ld_obsoleted eq 't' ) { $action= 'Obsoleted'; }
	push @ld_updates, [map {$_} (qq|<a href="locus_display.pl?locus_id=$locus_id">$locus_symbol</a>|, $annotation, $person, $udate, $action)];
    }
    
    my $lds;
    if (@ld_updates) {
	$lds= columnar_table_html(headings => ['Locus',
					       'Annotation',
					       'Updated by',
					       'Date',
					       ],
				      data=>\@ld_updates, __align=>'llc');}
    
    
    print info_section_html(title   => "Locus Annotations (" . scalar(@ld_updates) . ")",
			    contents => $lds ,
			    collapsible=>1,
			    collapsed=>1,
			    );			   
    
    
    ####################
    #locus images
    ####################
   
    my @locus_images;
    
    foreach my $list(@{$locus_edits{locus_images} } ) {
	#[$locus, $image, $person_id, $cdate, $mdate, $obsolete];
	my $locus=$list->[0];
	my $image_id=$list->[1];
#	my $image_id=$image->get_image_id();
#	my $image_name= $image->get_name() || "image: $image_id";
	my $locus_id=$locus->get_locus_id();
	my $locus_symbol=$locus->get_common_name() ." " . $locus->get_locus_symbol();
	my $owner=  $list->[2];
	my $person= get_person_info($dbh, $owner);
	
	my $udate= $list->[4];
	$action='Updated';
	if (!$udate) {
	    $udate=$list->[3];
	    $action='Created';
	}
	my $obsoleted =  $list->[5];
	if ($obsoleted eq 't' ) { $action= 'Obsoleted'; }
	push @locus_images, [map {$_} (qq|<a href="locus_display.pl?locus_id=$locus_id">$locus_symbol</a>|, qq|<a href="/image/index.pl?image_id=$image_id">image: $image_id</a>|, $person, $udate, $action)];
    }
    
    my $lis;
    if (@locus_images) {
	$lis= columnar_table_html(headings => ['Locus',
					       'Image',
					       'Updated by',
					       'Date',
					       ],
				      data=>\@locus_images, __align=>'llc');}
    
    
    print info_section_html(title   => "Locus images (" . scalar(@locus_images) . ")",
			    contents => $lis ,
			    collapsible=>1,
			    collapsed=>1,
			    );			   

    ####################
    #individuals
    ####################
   
    my @individuals;
    
    foreach my $list(@{$locus_edits{individuals} } ) {
	my $ind=$list->[0];
	my $allele=$list->[1];
	my $ind_id=$ind->get_individual_id();
	my $ind_name= $ind->get_name() ;
	my $locus_name=$allele->get_locus()->get_common_name() ." " . $allele->get_locus_name();
	my $locus_id=$allele->get_locus_id();
	my $owner=  $list->[2];
	my $person= get_person_info($dbh, $owner);
	
	my $udate= $list->[4];
	$action='Updated';
	if (!$udate) {
	    $udate=$list->[3];
	    $action='Created';
	}
	my $obsoleted =  $list->[5];
	if ($obsoleted eq 't' ) { $action= 'Obsoleted'; }
	push @individuals, [map {$_} (qq|<a href="locus_display.pl?locus_id=$locus_id">$locus_name</a>|, qq|<a href="individual.pl?individual_id=$ind_id">$ind_name</a>|, $person, $udate, $action)];
    }
    
    my $ias;
    if (@individuals) {
	$ias= columnar_table_html(headings => ['Locus',
					       'Accessions',
					       'Updated by',
					       'Date',
					       ],
				      data=>\@individuals, __align=>'llc');}
    
    
    print info_section_html(title   => "Locus accessions (" . scalar(@individuals) . ")",
			    contents => $ias ,
			    collapsible=>1,
			    collapsed=>1,
			    );		
	
    ####################
    #locus unigenes
    ####################
   
    my @locus_unigenes;
    
    foreach my $list(@{$locus_edits{locus_unigenes} } ) {
	my $unigene=$list->[0];
	my $locus=$list->[1];
	my $unigene_id='SGN-U' . $unigene->get_unigene_id();
	my $locus_name=$locus->get_common_name() ." " . $locus->get_locus_name();
	my $locus_id=$locus->get_locus_id();
	my $owner=  $list->[2];
	my $person= get_person_info($dbh, $owner);
	
	my $udate= $list->[4];
	$action='Updated';
	if (!$udate) {
	    $udate=$list->[3];
	    $action='Created';
	}
	my $obsoleted =  $list->[5];
	if ($obsoleted eq 't' ) { $action= 'Obsoleted'; }
	push @locus_unigenes, [map {$_} (qq|<a href="locus_display.pl?locus_id=$locus_id">$locus_name</a>|, qq|<a href="/search/unigene.pl?unigene_id=$unigene_id">$unigene_id</a>|, $person, $udate, $action)];
    }
    
    my $uls;
    if (@locus_unigenes) {
	$uls= columnar_table_html(headings => ['Locus',
					       'Unigene',
					       'Updated by',
					       'Date',
					       ],
				      data=>\@locus_unigenes, __align=>'llc');}
    
    
    print info_section_html(title   => "Locus-unigenes (" . scalar(@locus_unigenes) . ")",
			    contents => $uls ,
			    collapsible=>1,
			    collapsed=>1,
			    );		
    

    ####################
    #locus markers
    ####################
   
    my @lm_updates;
    
    foreach my $lm(@{$locus_edits{locus_markers} } ) {
	my $locus_id=$lm->get_locus_id();
	my $locus=CXGN::Phenome::Locus->new($dbh, $locus_id);
	my $marker_id= $lm->get_marker_id();
	my $marker=CXGN::Marker->new($dbh, $lm->get_marker_id());
	my $marker_name=$marker->name_that_marker();
	my $locus_symbol=$locus->get_common_name() ." " . $locus->get_locus_symbol();
	my $lm_owner=  $lm->get_sp_person_id();
	my $udate= $lm->get_modification_date() ;
	my $lm_obsoleted =  $lm->get_obsolete();
	$action='Updated';
	if (!$udate) {
	    $udate=$lm->get_create_date();
	    $action='Created';
	}
	my $person= get_person_info($dbh, $lm_owner);
	if ($lm_obsoleted eq 't' ) { $action= 'Obsoleted'; }
	push @lm_updates, [map {$_} (qq|<a href="locus_display.pl?locus_id=$locus_id">$locus_symbol</a>|, qq|<a href="/markers/marker_info.pl?marker_id=$marker_id">$marker_name</a>|, $person, $udate, $action)];
    }
    
    my $lms;
    if (@lm_updates) {
	$lms= columnar_table_html(headings => ['Locus',
					       'Marker',
					       'Updated by',
					       'Date',
					       ],
				      data=>\@lm_updates, __align=>'llc');}
    
    
    print info_section_html(title   => "Locus markers (" . scalar(@lm_updates) . ")",
			    contents => $lms ,
			    collapsible=>1,
			    collapsed=>1,
			    );			   
    
}



sub get_person_info {
    my $dbh=shift;
    my $sp_person_id=shift;
    my $user = CXGN::People::Person -> new($dbh, $sp_person_id);
    my $username=$user->get_first_name()." ".$user->get_last_name();
    my $person= qq| <a href="../solpeople/personal_info.pl?sp_person_id=$sp_person_id">$username</a> | ;
    return $person;
}

sub get_annotation {
    my $dbxref=shift;
    my $acc=$dbxref->get_full_accession();
    my $accession= $dbxref->get_accession();
    my $db=$dbxref->get_db_name();
    if ($db eq 'SGN_ref') {
	$accession= $dbxref->get_publication()->get_pub_id(); 
    }
    my $url=$dbxref->get_urlprefix() . $dbxref->get_url() . $accession;
    return qq |<a href="$url">$acc</a>|;
}
