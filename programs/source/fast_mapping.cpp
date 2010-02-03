 //This is the version that replaces singletons with missing values

//August 2005, by Noah Whitman
//this program groups markers according to LOD thresholds
//then uses the RECORD algorithm to find a good marker ordering


//USAGE 2: fast_mapping [-s skip grouping -c chromosomes -u coreLOD -l lowLOD
				//-v missing_values_threshold -g 1:1_screening_threshold -h 1:3:1_screening_threshold
				//-d 1:3_screening_threshold+" -m matrix_file] loc_file
//if no optional parameters are input, the program will search for parameters in file PARAMTERS_FILE
//not all option parameters need to be input, as long as one of them is
//un-inputed parameters will revert to program defaults

//TO DO, BUGS:
//input could be simplified: -x for all chi-squared screening, -l for both LOD's 
//add SINGLETON to the matrix, should speed up scorepair
//BUG:SMOOTH weights aren't normalized for markers near the edges of their groups
//ack, ordering is slow with SMOOTH, perhaps use fast reverses...
//Rmk: SMOOTH does not interfere in some pernicious way with RECORD because RECORD is run normally on the last SMOOTH iteration

//#include <stdio.h>
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <list>
#include <cstdlib>
#include <algorithm>
#include <math.h>
//#include <stdlib.h>

using namespace std;

void core_grouping(vector<vector <int> > &markers, vector<vector <int> > &grouping, float &LOD_threshold);
void RECORD(vector <vector <int> > &markers, vector<int> &order);
int initial_placement(vector <vector <int> > &markers, vector<int> &order);
void window_improvements(vector <vector <int> > &markers, vector<int> &order, int score);
int remove_singletons(vector <vector <int> > &markers, vector<int> &order, list<int> &singleton_markers);
void hammer_markers(vector <vector <int> > &markers, vector<int> &order, list<int> &singleton_markers);
void satellites(vector<vector <int> > &markers, vector<vector <int> > &grouping, float &LOD_threshold, int chromosomes);
void satellites2(vector<vector <int> > &markers, vector<vector <int> > &grouping, float &LOD_threshold, int chromosomes);
int scorepair(vector<vector <int> > &markers, int loc1, int loc2);
void clean_groups(vector<vector <int> > &grouping);
void reverse(vector <int> &v, int a, int b);
int poprand(list <int> &list_);
int totalscore(vector<vector <int> > &markers, vector <int> &order_);
float LOD(vector<vector <int> > &markers, int loc1, int loc2, float &r);
float LOD2(vector<vector <int> > &markers, int loc1, int loc2, float &r);
bool operator<(const vector <int> &a, const vector <int> &b);
void read_program_parameters(int argc,char *argv[],string &locfile,float &core_LOD,float &min_LOD,int &chromosomes,vector<float> &quality_thresholds, bool &skip_grouping, bool &order_plants);
int read_loc_line(string &locstr, string &locname, vector<int> &markers, vector<float> &quality_thresholds);
int read_mat(vector <int> &matrow, string &line);
int marker2int(char m);
char int2marker(int a);
void fatal_error(string err_message);

const string PARAMTERS_FILE="mapping_parameters.txt";
const string DEFAULT_MATRIX_FILE="matrix.txt";

int VERBOSE_LOG =0; //0=not verbose,
					//1 print out loc reading lines, grouping process, initial RECORD order, removed singletons
					//2 also print out info on LOD calculations
					//3 also print out info surrounding singletons
fstream map_log;

const int N_GENOTYPES=6;

//genotypes
const int MV_=0;
const int A_=1;
const int B_=2;
const int C_=3;
const int D_=4;
const int H_=5;
const int SINGLETON_=-1;

//penalty matrix for RECORD
//THIS MATRIX IS NOT CONST, it will be filled in from a file
int penalty_matrix[N_GENOTYPES][N_GENOTYPES]={{ 0, 0, 0, 0, 0, 0},
											  { 0, 0, 0, 0, 0, 0},
											  { 0, 0, 0, 0, 0, 0},
											  { 0, 0, 0, 0, 0, 0},
											  { 0, 0, 0, 0, 0, 0},
											  { 0, 0, 0, 0, 0, 0}};

//indicies in the main varaible float[] quality_thresholds
const int MISSING_VALUE_IDX=0;
const int CHISQ_11_IDX=1;
const int CHISQ_121_IDX=2;
const int CHISQ_13_IDX=3;

////////////////////////// SMOOTH constants//////////////////////////////////////////////////////////////////////
const float DEFAULT_D=0.95; //SMOOTH matrix value above this is considered a double recombinant
//const int recordCycles=15;
//const float d_increment=.02;
int DELTA=1; //the radius of neighboring markers to consider for SMOOTH

const float SINGLETON_THRESHOLD=.05; //proportion of double recombinants
									 //above which a markers is a singleton

//weights matrix for SMOOTH
const int WEIGHTS_LENGTH=15;
float WEIGHTS[WEIGHTS_LENGTH]={0.998,0.981,0.934,0.857,0.758,0.647,0.537,0.433,0.342,0.265,0.202,0.151,0.112,0.082,0.059};

const unsigned int SINGLETON_GROUP_THRESHOLD=100; //minimum # of markers in data to run SMOOTH
const float SMOOTH_MATRIX[N_GENOTYPES][N_GENOTYPES]={{ 0, 0, 0, 0, 0, 0},
													 { 0, 0, 1, 1, 0, 1}, 
													 { 0, 1, 0, 0, 1, 1},
													 { 0, 1, 0, 0, 0, 0},
													 { 0, 0, 1, 0, 0, 0},
													 { 0, 1, 1, 0, 0, 0}};

\
//**********************************************  MAIN  *************************************************************
//**********************************************  MAIN  *************************************************************
//**********************************************  MAIN  *************************************************************
int main(int argc, char *argv[])
{
	cout<<"Running fast mapping...";
	

	//================= program-wide variables =========================================================	
	vector <string> locnames; // the loci names
	vector <string> bad_segregation_locnames; // the loci names
	vector <string> excessive_blank_locnames; // the loci names
	vector <string> comments; //stores lines beginning with ';'
	vector <vector <int> > markers; //a matrix of the markers
	vector <vector <int> > markerstranspose; //a transposed matrix of markers, used only when ordering individuals
	vector <vector <int> > grouping; //a matrix of grouped marker id's
	vector<int> old_plant_order;	//order of individuals
	vector<int> plant_order;	//order of individuals
	vector <vector <int> > bad_segregation_markers; //a matrix of bad segregation markers
	vector <vector <int> > excessive_blank_markers; //a matrix segregation markers
	vector< list<int> >singletons(grouping.size()); // a vector of lists of singletons for each group
		
	string locfile, outputfile;
	string filestr, poptstr, nlocstr, nindstr; //first and second lines of .loc file
	int nloc, stated_nind,nind=-1; //number of loci, number of markers per loci
	int newscore=0;  //running score of current ordering
	string oldscore=""; //old score possibly read in from loc file	

	//inputs read in from parameter file, set to default values here	
	float core_LOD=16;
	float min_LOD=4;
	int chromosomes=12;
	vector<float> quality_thresholds(4);
	quality_thresholds[MISSING_VALUE_IDX] = .2;
	quality_thresholds[CHISQ_11_IDX]=50;
	quality_thresholds[CHISQ_121_IDX]=50;
	quality_thresholds[CHISQ_13_IDX]=50; //normal chi-square threshold w/ 2 degrees of freedom giving p-value .001 
	bool order_plants = false;
	bool skip_grouping=false;

	//normalize the WEIGHTS matrix
	if(DELTA>WEIGHTS_LENGTH) DELTA=WEIGHTS_LENGTH;
	float weightSum=0;
	for(int i=0;i<DELTA;i++){
		weightSum+=2.0*WEIGHTS[i];
	}
	for(int i=0;i<DELTA;i++){
		WEIGHTS[i]=WEIGHTS[i]/weightSum;
	}

	read_program_parameters( argc,
							argv,
							locfile,
							core_LOD,
							min_LOD,
							chromosomes,
							quality_thresholds,
							skip_grouping,
							order_plants  );


	////////////////////////READ IN LOC FILE////////////////////////////////////////////////////////
	//read in number of loci and indicies
	 //char str[2000]; //buffer for reading in lines
	fstream file_op(locfile.c_str(),ios::in);
	if(!file_op.is_open())  fatal_error("bad loc file!");
	
	getline(file_op, filestr);
	getline(file_op, poptstr);
	getline(file_op, nlocstr);
	getline(file_op, nindstr);
	nloc = atoi((nlocstr.substr( nlocstr.find_last_of('=',nlocstr.size()-1) + 1)).c_str());
	stated_nind = unsigned( atoi( (nindstr.substr(nindstr.find_last_of('=',nindstr.size()-1) + 1)).c_str() ) );
	outputfile = string(locfile).substr(0,string(locfile).find_last_of('.',string(locfile).size()-1));
	map_log<<"\nRUNNING FASTMAPPING ON "<<outputfile<<endl;
	outputfile.append("_map.loc");


	//read in loc data
	if(VERBOSE_LOG>0) map_log<<endl<<"READING IN LOC DATA:"<<endl;
	vector <int> marker;
	string locname;
	int marker_quality; //0=acceptable, -1=error, 1==bad segregation, 2==too many blanks
	bool individuals_preordered=false; //0 if no inidividual order is present in loc file	
	while(!file_op.eof()) 
    {
		string line_str;
		getline(file_op,line_str);
		if(line_str.size() > 1 && line_str[0]!='\t' && line_str[0]!=';')
		{			
			marker_quality=read_loc_line(line_str, locname, marker, quality_thresholds);

			if(marker_quality==-1){
				map_log<<"Error reading loc"<<locname<<endl;
			}
			if(marker_quality!=-1 && nind==-1) nind = (int)marker.size();
			else if(marker_quality!=-1 && (unsigned)nind!=marker.size()) {
				map_log<<"Terminating program! At marker "<<locname<<", number of individuals "<<marker.size()<<" different previous loci at "<<nind<<endl;
				cout<<"Terminating program! At marker "<<locname<<", number of individuals "<<marker.size()<<" different previous loci at "<<nind<<endl;
				exit(1);
			}
			if(marker_quality!=-1 && stated_nind > 0 && nind!=stated_nind) {
				map_log<<"Warning!: At marker "<<locname<<", number of individuals "<<marker.size()<<" different than stated value "<<stated_nind<<endl;
				cout<<"Warning!: At marker "<<locname<<", number of individuals "<<marker.size()<<" different than stated value "<<stated_nind<<endl;
			}	
			if(marker_quality==0){
				locnames.push_back(locname);
				markers.push_back(marker);
			}
			else if(marker_quality==1) {
				bad_segregation_locnames.push_back(locname);
				bad_segregation_markers.push_back(marker);
			}
			else{
				excessive_blank_locnames.push_back(locname);
				excessive_blank_markers.push_back(marker);
			}
		}
		else{
			if(line_str.substr(0,8)==";indOrdr") {
				old_plant_order.clear();
				map_log<<"loading old inidividual order...\n";
				line_str=line_str.substr(line_str.find_first_of('\t'));
				while(line_str[0]=='\t') line_str=line_str.substr(1);
				string temp;
				unsigned int pos=0;
				while(pos < line_str.size() && line_str.at(pos)!='\t' && line_str.at(pos)!=';'){
					temp=line_str.substr(pos,line_str.find_first_of('\t',pos)-pos);
					old_plant_order.push_back(atoi(temp.c_str() ));
					pos=line_str.find_first_of('\t',pos);
					if(pos==string::npos) break;
					else pos=pos+1;
				}
				if(old_plant_order.size()==(unsigned int)nind) {
					individuals_preordered=true;
					map_log<<"loaded individual order successfull\n";
				}
			}
			if(line_str.substr(0,10)==";newscore="){
				oldscore = ";oldscore="+line_str.substr(line_str.find_first_of('=')+1,line_str.size()-1);
			}
			line_str.append("\n");
			comments.push_back(line_str);
		}
		marker.clear();
    }   
	file_op.close();

	nloc=markers.size();

	//Create the initial order of plants
	plant_order.clear();
	plant_order.resize(nind);
	for(int i=0;i<nind;i++){
		plant_order[i]=i;
	}


	//=================================================== grouping =======================================================
	if(skip_grouping){
		cout<<"\nskipping grouping";
		map_log<<"\nSKIPPING GROUPING\n";
		grouping.resize(1);
		for(int loc=0;(unsigned)loc<markers.size();loc++)
			grouping.at(0).insert(grouping.at(0).end(),loc);
	}
	else{
		cout<<"\ncore grouping...";
		map_log<<"\nCORE GROUPING MARKERS...\n";
		core_grouping(markers, grouping, core_LOD);
		map_log<<endl;

		//place satellites with progressively smaller threshold
		if(grouping.size()>(unsigned int)chromosomes){
			//float LOD_thresholdt_1 = ((core_LOD-min_LOD)*2.0/3.0) + min_LOD;
			//float LOD_thresholdt_2 = ((core_LOD-min_LOD)/3.0) + min_LOD;
			//satellites(markers, grouping, LOD_thresholdt_1, chromosomes);
			//satellites(markers, grouping, LOD_thresholdt_2, chromosomes);
			satellites2(markers, grouping, min_LOD, chromosomes);
			map_log<<endl;
		}

		//remove empty groups which will all be at the end of the vector
		clean_groups(grouping);
	}
	//printing groups to the log
	for(unsigned int j=0;j<grouping.size();j++) {
		map_log<<"group ("<<j+1<<"):";
		for(unsigned int k=0;k<grouping.at(j).size();k++) 
			map_log<<grouping[j][k]+1<<" ";
		map_log<<endl<<endl;
	}

	//=================================================== implement RECORD algorithm =======================================================
	cout<<"\nordering markers...";
	map_log<<"\nORDERING MARKERS...\n\n";

	//set the random seed, always the same right now
	int seed = 6;
    srand(seed);


	//run RECORD on each group
	singletons.resize(grouping.size());
	for(unsigned int j=0;j<grouping.size();j++) {
		if(grouping.at(j).size() > 1) {
			
			map_log<<"-------------------------------------------------------------\n";
			map_log<<"Running RECORD on group "<<j+1<<endl;
			
			if(grouping.at(j).size() > SINGLETON_GROUP_THRESHOLD) {
				//run RECORD, then SMOOTH, then RECORD
				int markersremoved=1;
				RECORD(markers,grouping.at(j));
				markersremoved = remove_singletons(markers, grouping.at(j), singletons.at(j));
				if(markersremoved>0) {
					map_log<<"Removed Singletons!, ReRunning RECORD\n"<<endl;
					cout<<"Removed Singletons!, ReRunning RECORD\n"<<endl;
					RECORD(markers,grouping.at(j));
				}
				int score=totalscore(markers,grouping.at(j));
				map_log<<"\nMain loop done!!!!, score="<<score<<"\nHammering in removed markers..."<<endl;
				cout<<"\nMain loop done!!!!, score="<<score<<"\nHammering in removed markers..."<<endl;

				hammer_markers(markers, grouping.at(j), singletons.at(j));
				score=totalscore(markers,grouping.at(j));
				map_log<<"\nRECORD done, score="<<score<<endl;
			}
			else {
				//just run RECORD without any SMOOTHing
				RECORD(markers,grouping.at(j));
				map_log<<"-------------------------------------------------------------\n";
			}
		}
	}
	map_log<<"-------------------------------------------------------------\n";
	
	//now flip marker matrix and perform RECORD on the transpose
	if(order_plants) {
		markerstranspose.resize(nind);	
		for(int i=0;i<nind;i++)
			markerstranspose.at(i).resize(nloc);
		for(int i=0;i<nind;i++){
			for(int j=0;j<nloc;j++)
				markerstranspose[i][j]=markers[j][i];
		}
		map_log<<"Running RECORD on the order of individuals"<<endl;
		RECORD( markerstranspose, plant_order);
	}

	for(unsigned int j=0;j<grouping.size();j++) 
		newscore +=totalscore( markers, grouping.at(j));
	
	//=================================================== write loc file of new order========================================================
	float r, L;

	fstream fwr(outputfile.c_str(),ios::out);
	fwr<<filestr<<endl<<poptstr<<endl<<nlocstr<<endl<<nindstr<<endl;
	for(unsigned int i=0;i<3;i++){
		if(i<comments.size())
			fwr<<comments[i];	
		else fwr<<'\n';
	}
	
	fwr<<";grouping threshold LOD="<<core_LOD<<endl;
	fwr<<oldscore<<endl;
	fwr<<";newscore="<<newscore<<"\n;indOrdr\t";
	
	for(int j=0; j<nind;j++){
		if(individuals_preordered)
			fwr<<old_plant_order[plant_order[j]]<<"\t";
		else fwr<<plant_order[j]<<"\t";
	}

	fwr<<";\tr\tLOD\tdist";
	fwr<<endl;
    
	for(unsigned i=0;i<grouping.size();i++){
		for(unsigned j=0;j<grouping.at(i).size();j++){
			fwr<<locnames[grouping[i][j]];
			for(int k=0; k<nind; k++){
				fwr<<'\t'<<int2marker(markers[grouping[i][j]][plant_order[k]]);
			}
			if(j<grouping.at(i).size() - 1){
				L = LOD2(markers,grouping[i][j],grouping[i][j+1],r);
				fwr<<"\t;\t"<<r<<'\t'<<L;
				if(r<0.5) fwr<<'\t'<<100.0/4.0*log10((1+2*r)/(1-2*r));		//Kosambi mapping function
			}
			fwr<<endl;
		}
		fwr<<";"<<endl;
		if(singletons[i].size()>0){
			map_log<<"singletons in group "<<i+1<<":";

			for(list<int>::iterator smitr = singletons[i].begin(); smitr != singletons[i].end(); smitr++ ){
				map_log<<locnames[*smitr]<<", ";
			}
			map_log<<"\n";
		}
	}
	
	if(bad_segregation_markers.size() > 0) fwr<<";bad segregation ratio markers\n";
	for(unsigned i=0; i<bad_segregation_markers.size();i++){
		fwr<<bad_segregation_locnames[i]<<'\t';
		for(unsigned j=0;j<bad_segregation_markers.at(i).size();j++)
			fwr<<int2marker(bad_segregation_markers[i][plant_order[j]])<<'\t';
		fwr<<endl;
	}
	if(excessive_blank_markers.size() > 0) fwr<<"\n;excessive missing value markers\n";
	for(unsigned i=0; i<excessive_blank_markers.size();i++){
		fwr<<excessive_blank_locnames[i]<<'\t';
		for(unsigned j=0;j<excessive_blank_markers.at(i).size();j++)
			fwr<<int2marker(excessive_blank_markers[i][plant_order[j]])<<'\t';
		fwr<<endl;
	}
		
	fwr.close();
	map_log<<"\nFASTMAPPING IS DONE\n";
	cout<<"\nDONE";
	map_log.close();
	return 0;
} 
//=============================================== END OF MAIN======================================================================================
//=============================================== END OF MAIN======================================================================================
//=============================================== END OF MAIN======================================================================================
//=============================================== END OF MAIN======================================================================================

//============================================== core_grouping ============================================================================================
//groups markers by LOD_threshold, this algorithm is deterministic, with n^2 complexity
//output: grouping should be initially emnpty, this function adds groups to grouping
void core_grouping(vector<vector <int> > &markers, vector<vector <int> > &grouping, float &LOD_threshold){
	int group,previous_group=-1;
	unsigned int nloc= markers.size();
	bool unplaced;
	float r, L;

	for(unsigned int loc=0;loc<nloc;loc++){
			group=0;
			unplaced = true;

			//iterate across groups and through group members
			for(unsigned int j=0;j<grouping.size();j++) {
				for(unsigned int k=0;k<grouping.at(j).size();k++) {
					L=LOD(markers,loc,grouping[j][k],r);
					if(L > LOD_threshold && unplaced) {  //place marker in group
						grouping.at(j).insert(grouping.at(j).end(),loc);
						group=j;
						unplaced=false;
						if(group!=previous_group) {
							if(VERBOSE_LOG>0) map_log<<endl<<"Placing markers in group ("<<group+1<<"):";
							previous_group=group;
						}
						if(VERBOSE_LOG>0) map_log<<loc<<",";
						break;
					}
					if(L > LOD_threshold && !unplaced) {  //merge groups
						grouping.at(group).insert(grouping.at(group).end(),grouping.at(j).begin(),grouping.at(j).end());
						grouping.at(j).erase(grouping.at(j).begin(),grouping.at(j).end());
						if(VERBOSE_LOG>0) map_log<<endl<<"Loci "<<loc<<" matches groups ("<<group+1<<") and ("<<j+1<<") , combining!";
						previous_group=-1;
						break;
					}
				}
			}
			if(unplaced) { //create a new group for the unplaced marker
				grouping.resize(grouping.size()+1);
				grouping.at(grouping.size()-1).insert(grouping.at(grouping.size()-1).end(),loc);
				if(VERBOSE_LOG>0) map_log<<endl<<"Creating new group ("<<grouping.size()<<"), Placing markers:"<<loc<<",";
				previous_group=grouping.size();
			}
	}
}

//============================================== RECORD ============================================================================================
//implements the RECORD algorithm to sort markers
//input: markers is matrix expression data
//output: order is the new marker order
void RECORD(vector <vector <int> > &markers, vector<int> &order) {
	int ndata=order.size();
	if(ndata > 1) {
	
	list <int> inital_order;
	list <int> to_place;
	vector <int> old_order(ndata);

	/////////randomize markers////////////////
	inital_order.clear();	
	to_place.clear();		
	map_log<<"Running RECORD!, groupsize="<<order.size()<<". Randomizing order...\n";
	cout<<"Running RECORD on group of size="<<order.size()<<endl;
	for(unsigned int i=0;i<order.size();i++) inital_order.push_back(order.at(i));		
	for(unsigned int i=0;i<order.size();i++) to_place.push_back(poprand(inital_order));
	for(unsigned int i=0;i<order.size();i++) {
		order[i]=to_place.back();
		to_place.pop_back();
	}

	int score =totalscore(markers,order);
	map_log<<"randomized score="<<score<<endl;
	

	int windowruns=1, oldscore=score+1;

	//The loop repeating the RECORD algorithm until no further inprovement
	while(score<oldscore && score >= 0){ 
		map_log<<"\nRECORD run "<<windowruns<<endl;
		windowruns++;

		//copy the old order so we can get back to it
		oldscore=score;
		for(int i=0;i<ndata;i++) old_order[i]=order[i];

		//STEP ONE: do greedy first placement
		score = initial_placement( markers, order);
		map_log<<"inital window placement score = "<<score<<endl;

		//STEP TWO: do 'window' improvement
		window_improvements(markers, order, score);
		score = totalscore(markers,order);
		map_log<<"score = "<<score<<endl;
	}
	
	for(int i=0;i<ndata;i++) order[i]=old_order[i];
	score=totalscore(markers,order);
	map_log<<"\nRECORD Done, using score "<<score<<endl<<endl;
	}
}


//============================================== inital placement ================================================================
//change order by placing markers one by one in best position
//output: order is changed
int initial_placement(vector <vector <int> > &markers, vector<int> &order) {
	list<int>::iterator itr, best_pos;
	int loc_ind, dscore, best_dscore, ind_a,ind_b;
	int score;
	int ndata= order.size();
	list <int> placed;
	placed.clear();
	list <int> to_place;
	for(int i=0;i<ndata;i++) 
		to_place.push_back(order[i]);

	//place first two loci
	placed.push_back(to_place.back());
	to_place.pop_back();
	placed.push_back(to_place.back());
	to_place.pop_back();

	score=scorepair(markers,placed.front(),placed.back());
	
	while(to_place.size()>0){
		loc_ind=to_place.back();
		to_place.pop_back();
		itr=placed.begin();
		best_dscore=scorepair(markers,loc_ind,*itr);
		best_pos=itr;
		while( itr != placed.end() ){ //find the position for the marker with lowest dscore
			ind_a=*itr;
			itr++;
			if(itr!= placed.end()) {
				ind_b=*itr;
				dscore=scorepair(markers,ind_a,loc_ind) + scorepair(markers,ind_b,loc_ind)
					- scorepair(markers,ind_a,ind_b);
				if(dscore<best_dscore) {
					best_dscore=dscore;
					best_pos=itr;
				}
			}
		}
		itr--;
		if(scorepair(markers,*itr,loc_ind)<best_dscore) { //place marker at the end
			score+=scorepair(markers,*itr,loc_ind);
			placed.push_back(loc_ind);
		}
		else {	//place marker in the middle
			placed.insert(best_pos,loc_ind);
			score+=best_dscore;
		}
	}

	//copy list to order vector
	order.resize(ndata);
	list<int>::iterator list_iterator=placed.begin();
	int locx=0;
	if(VERBOSE_LOG>0) map_log<<"initial order:";
	while( list_iterator != placed.end() ) {
		order[locx]= *list_iterator;
		if(VERBOSE_LOG>0) map_log<<(*list_iterator)+1<<",";
		list_iterator++;
		locx++;
	}
	return score;

	}


//============================================== window_improvements ====================================================================
//change order by running windows of increasing size along order and flipping if this improves the score
//output: order is changed
void window_improvements(vector <vector <int> > &markers, vector<int> &order, int score) {
	int ndata = order.size();
	int oldscore=score+1;
	int passes=0;
	int reverses, dscore;
	while(score<oldscore && score >= 0){
		oldscore=score;
		passes++;
		map_log<<"pass "<<passes;		
		reverses=0;
				
		//iterate over window size i
		for(unsigned int i=2;i<unsigned(ndata)-1;i++){ 
			//dscore is the difference between the current score and the reversed score

			//j=0 case, window is [0,i-1]
			dscore=scorepair(markers,order[0],order[i]) - scorepair(markers,order[i-1],order[i]);
			if(dscore < 0 ) {
				reverse(order,0,i-1);
				score+=dscore;
				reverses++;
			}
		
			//iterate over window start position j, window is [j,j+i-1]
			for(unsigned int j=1;j<unsigned(ndata)-i-1;j++){ 
				dscore = scorepair(markers,order[j-1],order[j+i-1])+scorepair(markers,order[j],order[j+i])
					- (scorepair(markers,order[j-1],order[j])+scorepair(markers,order[j+i-1],order[j+i]));
				if(dscore < 0) {
					reverse(order,j,j+i-1);
					score+=dscore;
					reverses++;
				}
			}
		
			//j=ndata-i-1 case, window is [ndata-i,ndata-1]
			dscore=scorepair(markers,order[ndata-i-1],order[ndata-1]) - scorepair(markers,order[ndata-i-1],order[ndata-i]);
			if(dscore < 0 ) {
				reverse(order,ndata-i,ndata-1);
				score+=dscore;
				reverses++;
			}
		}
		//score=totalscore(markers,order);
		map_log<<", "<<reverses<<" reverses made, score is "<<score<<endl;
	}
}


//============================================== remove_singletons ====================================================================
//singleton markers are removed from order, and added to singleton_markers
//output: singleton_markers and order are changed
int remove_singletons(vector <vector <int> > &markers, vector<int> &order, list<int> &singleton_markers) {
	int nloc = markers[order[0]].size();
	int singletons;
	//float d=1.0-d_increment*c;  //we're not doing a fixed number of cycles anymore
	float yhat;
	list<int> remove;
	list <list <int> > singleton_indicies;

	remove.clear();
	singleton_indicies.clear();
	if(VERBOSE_LOG==3) map_log<<"Printing singletons, format: (order:order index:individual:yhat)\n";
	for(unsigned int i=0;i<order.size();i++){ //iterate on all rows in group
		list<int> marker_singletons;
		marker_singletons.clear();
		singletons=0;
		for(int k=0;k<nloc;k++){  //iterate across all individuals
			yhat=0;
			for(int m=-DELTA;m<=DELTA;m++){  //add up penalties across DELTA width
				if(m!=0 && i+m>0 && i+m < order.size())
						yhat+=WEIGHTS[abs(m)-1]*SMOOTH_MATRIX[markers[order[i+m]][k]][markers[order[i]][k]];				
			}
			if(yhat>DEFAULT_D){  //marker is a singleton
				singletons++;	 //use fixed d threshold instead of lowering one
				marker_singletons.push_back(k);
				if(VERBOSE_LOG==3) map_log<<"("<<order[i]<<":"<<i<<":"<<k<<":"<<yhat<<"),";
			}			
		}
		if(((float)singletons)/((float)nloc) > SINGLETON_THRESHOLD){
			singleton_markers.push_back(order[i]);	
			remove.push_back(i);

			map_log<<"removing marker="<<order[i]<<" at "<<i<<" for "<<singletons<<" singletons with score "<<((float)singletons)/((float)nloc)<<endl;
			
			singleton_indicies.push_back(marker_singletons);

			///////all this prints out the marker line and those surrounding it////////
			if(VERBOSE_LOG==3) {
				map_log<<"k % 10\t";
				for(int k=0;k<nloc;k++) map_log<<k % 10<<" ";
				map_log<<endl;
				map_log<<i-1<<"\t";
				if(i>0){				
					for(int k=0;k<nloc;k++){
						map_log<<int2marker(markers[order[i-1]][k])<<" ";
					}
					map_log<<endl;
				}
				map_log<<i<<"\t";
				for(int k=0;k<nloc;k++){				
					map_log<<int2marker(markers[order[i]][k])<<" ";
				}
				map_log<<endl;
				map_log<<i+1<<"\t";
				if(i<order.size()){
					for(int k=0;k<nloc;k++){
						map_log<<int2marker(markers[order[i+1]][k])<<" ";
					}
					map_log<<endl;
				}
			}
			//////////////////////////////////////////////////////////////////////////
		}
	}
	//remove.sort();
	list<int>::iterator itr = remove.begin();
	vector<int>::iterator oitr;

	//remove the singletons from order and add them to the singleton list
	int removed=0;  //compensates the index in order for the entries removed
					//this relies on remove being sorted increasing
	for( itr = remove.begin(); itr != remove.end(); itr++ ){
		oitr=order.begin();
		for(int j=0;j<*itr-removed;j++){ oitr++; }
		if(VERBOSE_LOG>0) map_log<<"erasing marker "<<*oitr<<" at "<<*itr-removed<<endl;

		//replace singleton spots in these markers with missing values
		while( !singleton_indicies.front().empty() ){
			markers[order[*itr-removed]][singleton_indicies.front().back()]=SINGLETON_;
			singleton_indicies.front().pop_back();
		}
		singleton_indicies.pop_front();

		order.erase(oitr);
		removed++;
	}
	return remove.size();

}



//============================================== Hammer markers ====================================================================
//markers in singleton markers are added back into order
//output: order is changed
void hammer_markers(vector <vector <int> > &markers, vector<int> &order, list<int> &singleton_markers) {
	list<int>::iterator smitr;
	vector<int>::iterator itr;
	int bestpos;
	for( smitr = singleton_markers.begin(); smitr != singleton_markers.end(); smitr++ ){
		int bestpos=0;			
		int currentscore=scorepair(markers,order[0],*smitr);
		int bestscore=currentscore;

		//find the best place to put the singleton
		for(unsigned int i=1;i<order.size();i++){
			currentscore=scorepair(markers,order[i-1],*smitr)+scorepair(markers,order[i],*smitr);
			if(currentscore<bestscore){
				bestscore=currentscore;
				bestpos=i;
			}
		}
		currentscore=scorepair(markers,order[order.size()-1],*smitr); //also try putting it at end
		if(currentscore<bestscore){	
			bestpos=order.size();
			order.push_back(*smitr);
		}
		else{
			itr=order.begin();
			for(int i=0;i<bestpos;i++) itr++;
			order.insert(itr,*smitr);
		}
		map_log<<"replaced singleton marker="<<*smitr<<" at "<<bestpos<<endl;
	}
	map_log<<"Replaced "<<singleton_markers.size()<<" markers in group of size "<<order.size()<<endl;
}


//============================================== satellites ================================================================
//try placing all but the largest groups again with half the threshold
//input:markers is marker data, grouping is current grouping, LOD_threshold is previous LOD_threshold, chromosomes is number of largest groups that is fixed
//output: grouping is updated, LOD_threshold is updated
//THIS ALGORITHM should be order n^2 if group sizes are evenly distributed, which they aren't
void satellites(vector<vector <int> > &markers, vector<vector <int> > &grouping, float &LOD_threshold, int chromosomes){
	map_log<<"Placing satellites with threshold "<<LOD_threshold<<endl;
	cout<<"Placing satellites with threshold "<<LOD_threshold<<endl;
	float L, best_lod, r;
	vector <vector <int> >::iterator  itr1, itr_best,itr2;
	
	clean_groups(grouping);

	//itr is the primary loop iterator, it skips the core groups
	//itr2 is the secondary loop iterator, itr1 is just a placeholder

	itr1=grouping.begin();
	itr1+=chromosomes;
	while(itr1!=grouping.end()){
		best_lod = 0;
		itr2=grouping.begin();
		//map_log<<" calculating best..."<<endl;
		while(itr2 != grouping.end()) {
			if(itr1!=itr2) {
				map_log<<(*itr1).size()<<","<<(*itr2).size()<<endl;
				for(unsigned k=0;k<(*itr2).size();k++) {
					for(unsigned j=0;j<(*itr1).size();j++) {
						L=LOD(markers,(*itr1).at(j),(*itr2).at(k),r);
						if(L > LOD_threshold && L > best_lod) {
							best_lod=L;
							itr_best=itr2;
						}
					}
				}
				
			}
			itr2++;
		}

		if(best_lod>0){
			(*itr_best).insert((*itr_best).end(),(*itr1).begin(),(*itr1).end());
			grouping.erase(itr1);
		}
		else
			itr1++;
	}

}

//============================================== satellites ================================================================
//try placing all but the largest groups again with half the threshold
//input:markers is marker data, grouping is current grouping, LOD_threshold is previous LOD_threshold, chromosomes is number of largest groups that is fixed
//output: grouping is updated, LOD_threshold is updated
//THIS VERSION OF SATELLITES IS DETERMINISTIC
//it should be order n^2 if group sizes are evenly distributed, which the aren't
void satellites2(vector<vector <int> > &markers, vector<vector <int> > &grouping, float &LOD_threshold, int chromosomes){
	map_log<<"Placing satellites with threshold "<<LOD_threshold<<endl;
	cout<<"\nPlacing satellites with threshold "<<LOD_threshold<<endl;
	float L, best_lod, r;
	vector <vector <int> >::iterator  itr1, itr_best,itr2;

	clean_groups(grouping);
	unsigned int previous_size = grouping.size();

	while(true){
		cout<<"placing satellites.. ";
		map_log<<"placing satellites.. ";
		//itr1=primary loop iterator, it skips the core groups
		//itr2=secondary loop iterator, itr_best=a placeholder

		itr1=grouping.begin();
		itr1+=chromosomes;
		while(itr1!=grouping.end()){
			best_lod = 0;
			itr2=grouping.begin();
			while(itr2 != grouping.end()) { //scan for the best group to connect *itr1 to
				if(itr1!=itr2) {
					for(unsigned k=0;k<(*itr2).size();k++) {		//search through all markers-
						for(unsigned j=0;j<(*itr1).size();j++) {	//-in both groups
							L=LOD(markers,(*itr1).at(j),(*itr2).at(k),r);
							if(L > LOD_threshold && L > best_lod) {
								best_lod=L;
								itr_best=itr2;
							}
						}
					}
				}
				itr2++;
			}

			/*previously had, results seem to be the same
			if(best_lod>0){
				(*itr_best).insert((*itr_best).end(),(*itr1).begin(),(*itr1).end());
				(*itr1).erase((*itr1).begin(),(*itr1).end());
			}
				itr1++;
			*/
			if(best_lod>0){
				(*itr_best).insert((*itr_best).end(),(*itr1).begin(),(*itr1).end());
				grouping.erase(itr1);
			}
			else
				itr1++;
		}
		cout<<grouping.size()<<" groups"<<endl;
		map_log<<grouping.size()<<" groups"<<endl;
		if(grouping.size()==previous_size || grouping.size() <= (unsigned int)chromosomes){
			break;
		}
		previous_size = grouping.size();
	}

}

//============================================== clean_groups ================================================================
//removes any empty groups and sorts groups by size descending
//output: grouping is purged
void clean_groups(vector<vector <int> > &grouping){
	vector <vector <int> >::iterator  itr =grouping.begin();
	unsigned int size = grouping.size();
	cout<<size<<" groups";
	map_log<<size<<" groups";
	sort(grouping.begin(),grouping.end());
	
	while(itr != grouping.end()){
		if((*itr).size() == 0)
			grouping.erase(itr);
		else
			itr++;
	}
	if(grouping.size()!=size){
		cout<<", cut to "<<grouping.size();
		map_log<<", cut to "<<grouping.size();
	}
	cout<<endl;
	map_log<<endl;
}

//============================================== reverse ================================================================
//reverses segment [ab] of vector, ineffecient
void reverse(vector <int> &v, int a, int b) {
	if(a<b && a>=0 && b>=0 && unsigned(a)<v.size() && unsigned(b)<v.size()) {
		vector <int> scratch(b-a+1);
		for(int i=0;i<b-a+1;i++) {
			scratch[i]=v[a+i];
		}
		for(int i=0;i<b-a+1;i++) {
			v[a+i]=scratch[b - a - i];
		}
	}
	else {
		map_log<<"Bad indicies ("<<a<<","<<b<<") in reverse function!\n";
	}
}

//============================================== poprand ================================================================
//pop a random entry of list and return it
int poprand(list <int> &list_) {
	int pos=int(list_.size() * rand()/(RAND_MAX+1.0));
	list<int>::iterator itr_=list_.begin();
	for(int i=0; i<pos;i++)
		itr_++;
	int val=*itr_;
	list_.erase(itr_);
	return val;
}

//============================================== scorepair ================================================================
//return score between loc1 and loc2 of &markers based on scoring matrix scmat
int scorepair(vector<vector <int> > &markers, int loc1, int loc2) {
	if(loc1<0 || loc2<0 || unsigned(loc1)>=markers.size() || unsigned(loc2)>=markers.size())
		return 0;
	int score_=0;
	for(unsigned int i=0;i<(markers.at(loc1)).size();i++){
		if(markers[loc1][i] >=0 && markers[loc2][i] >= 0) //ignore singletons with value -1
			score_+=penalty_matrix[markers[loc1][i]][markers[loc2][i]];
	}
	return score_;
}

//============================================== totalscore ================================================================
//calculate total score of &markers in order &order based on matrix scmat (vector version)
int totalscore(vector<vector <int> > &markers, vector <int> &order) {
	int totalscore_ = 0;
	for(unsigned int i=0;i<order.size()-1;i++)
		totalscore_+=scorepair(markers,order[i],order[i+1]);

	return totalscore_;
}

//============================================== totalscore ================================================================
//calculate total score of &markers in order &order based on matrix scmat (list version)
/*int totalscore(vector<vector <int> > &markers, list <int> &order) {
	int totalscore_ = 0,ind1,ind2;
	list<int>::iterator itr_=order.begin();
	while(itr_!=order.end()){
		ind1=*itr_;
		itr_++;
		ind2=*itr_;
		if(itr_!=order.end())
			totalscore_+=scorepair(markers,ind1,ind2);
			//map_log<<scorepair(markers,ind1,ind2)<<",";
	}

	return totalscore_;
}*/

//============================================== LOD ================================================================
//return the LOD of two markers
float LOD(vector<vector <int> > &markers, int loc1, int loc2, float &r) {
	int plants=markers.at(loc1).size();
	vector <vector <float> > genotypes(N_GENOTYPES);
	for(unsigned int i=0;i<N_GENOTYPES;i++){
		genotypes.at(i).resize(N_GENOTYPES);
		for(unsigned int j=0;j<N_GENOTYPES;j++){
			genotypes[i][j]=0;
		}	
	}
	for(int i=0;i<plants;i++){
		genotypes[markers[loc1][i]][markers[loc2][i]]++;
	}
	
	//move 1/3 of C's into B's, 2/3 into H's, ect.
	for(unsigned int j=0;j<N_GENOTYPES;j++){
		genotypes[B_][j]+=genotypes[C_][j]/3;
		genotypes[H_][j]+=genotypes[C_][j]*2/3;
		genotypes[C_][j]=0;
	}
	for(unsigned int i=0;i<N_GENOTYPES;i++){
		genotypes[i][B_]+=genotypes[i][C_]/3;
		genotypes[i][H_]+=genotypes[i][C_]*2/3;
		genotypes[i][C_]=0;
	}
	for(unsigned int j=0;j<N_GENOTYPES;j++){
		genotypes[A_][j]+=genotypes[D_][j]/3;
		genotypes[H_][j]+=genotypes[D_][j]*2/3;
		genotypes[D_][j]=0;
	}
	for(unsigned int i=0;i<N_GENOTYPES;i++){
		genotypes[i][A_]+=genotypes[i][D_]/3;
		genotypes[i][H_]+=genotypes[i][D_]*2/3;
		genotypes[i][D_]=0;
	}

	//calculate R
	float X=genotypes[A_][A_]+genotypes[B_][B_]+genotypes[H_][H_];
	float Y=genotypes[A_][B_]+genotypes[B_][A_];
	float Z=genotypes[A_][H_]+genotypes[H_][A_]+genotypes[B_][H_]+genotypes[H_][B_];
	float W=genotypes[H_][H_];
	float N=X+Y+Z;
	r = (Y+Z/2)/N;
	if(r>0.5) r=0.5;
	float Rc=1+r*((2*r*r-3*r+1)/(2*r*r-r*r+1));
	float r_c= (Y+Z/2)/(N-W*Rc);
	
	float q = 1-r;
	float LOD;
	if(r==0){
		LOD=9999;
	}
	else {
		LOD=W*log10(q*q+r*r)+(X-W)*log10(q*q)+Z*log10(q*r)+Y*log10(r*r)-(N-W)*log10(1.0/4.0)-W*log10(1.0/2.0);
		//LOD=W*log10(2.0*(q*q+r*r))+(X-W)*log10(4.0*q*q)+Y*log10(4.0*r*r)+Z*log10(4.0*q*r);
	}
	if(VERBOSE_LOG==2) {
	  map_log<<"loci "<<loc1 + 1<<" and "<<loc2 + 1<<" have LOD="<<LOD<<" r="<<r<<" r_c="<<r_c<<" X="<<X<<" Y="<<Y<<" Z="<<Z<<" N="<<N<<endl;
	}

	return LOD;
}



//============================================== LOD2 ================================================================
//return the LOD of two markers
//currently used only for distance printouts, but this function treat
//reflect C and D combination better that the LOD function
float LOD2(vector<vector <int> > &markers, int loc1, int loc2, float &r) {
	int plants=markers.at(loc1).size();
	int cd_count=0;
	vector <vector <float> > genotypes(N_GENOTYPES);
	for(unsigned int i=0;i<N_GENOTYPES;i++){
		genotypes.at(i).resize(N_GENOTYPES);
		for(unsigned int j=0;j<N_GENOTYPES;j++){
			genotypes[i][j]=0;
		}	
	}
	for(int i=0;i<plants;i++){
		if(markers[loc1][i] != -1 && markers[loc2][i] != -1)
			genotypes[markers[loc1][i]][markers[loc2][i]]++;
		if(markers[loc1][i]==C_ | markers[loc1][i]==D_ | markers[loc2][i]==C_ | markers[loc2][i]==D_)
			cd_count++;
	}
	
	//calculate R
	float X=genotypes[A_][A_]+genotypes[A_][D_]+genotypes[D_][A_]+genotypes[D_][D_]
		+genotypes[B_][B_]+genotypes[B_][C_]+genotypes[C_][B_]+genotypes[C_][C_]
		+genotypes[H_][H_]+genotypes[H_][D_]+genotypes[D_][H_]+genotypes[H_][C_]
		+genotypes[C_][H_]+genotypes[D_][C_]+genotypes[C_][D_];

	float Y=genotypes[A_][B_]+genotypes[B_][A_];
	 
	float Z=genotypes[A_][H_]+genotypes[H_][A_]+genotypes[A_][C_]+genotypes[C_][A_]
		+genotypes[B_][H_]+genotypes[H_][B_]+genotypes[B_][D_]+genotypes[D_][B_];

	float W=genotypes[H_][H_]+genotypes[H_][D_]+genotypes[D_][H_]+genotypes[H_][C_]
		+genotypes[C_][H_]+genotypes[D_][C_]+genotypes[C_][D_];
	 
	float N=X+Y+Z;
	r = (Y+Z/2)/N;
	if(r>0.5) r=0.5;
	float Rc=1+r*((2*r*r-3*r+1)/(2*r*r-r*r+1));
	float r_c= (Y+Z/2)/(N-W*Rc);
	
	float q = 1-r;
	float LOD;
	if(r<=0){
		LOD=9999;
	}
	else if(r>=0.5){
		LOD=0.00001;
	}
	else {
		LOD=W*log10(q*q+r*r)+(X-W)*log10(q*q)+Z*log10(q*r)+Y*log10(r*r)-(N-W)*log10(1.0/4.0)-W*log10(1.0/2.0);
	}
	if(VERBOSE_LOG==2) {
	  map_log<<"loci "<<loc1 + 1<<" and "<<loc2 + 1<<" have LOD="<<LOD<<" r="<<r<<" r_c="<<r_c<<" X="<<X<<" Y="<<Y<<" Z="<<Z<<" W="<<W<<" N="<<N<<" cd_count="<<cd_count<<endl;
	}

	return LOD;
}

bool operator<(const vector <int> &a, const vector <int> &b) {
    return a.size() > b.size();
}

//============================================== read_program_parameters ================================================================
//input parameters argc and *argv[]
//ouptput parameters: all of the other parameters, also the const variable
void read_program_parameters(int argc,
						char *argv[],
						string &locfile,
						float &core_LOD,
						float &min_LOD,
						int &chromosomes,
						 vector<float> &quality_thresholds,
						bool & skip_grouping,
						bool &order_plants    )
{
	string matrix_file=DEFAULT_MATRIX_FILE; 
	//char str[2000];

	if(argc==2) 
		locfile=argv[1];
	else
		locfile=argv[argc-1];

	fstream test(locfile.c_str(),ios::in);
	if(!test.is_open()) 
		fatal_error("bad loc file!");
	test.close();

	string directory =  string(locfile).substr(0,string(locfile).find_last_of('/',string(locfile).size()-1));
	if(directory == "") directory = string(locfile).substr( 0,string(locfile).find_last_of('/',string(argv[2]).size()-1) );
	if(directory.find_first_of("/")==string::npos && directory.find_first_of("/")==string::npos) directory="";
	if(directory!="") directory.append("/");

	map_log.open((directory + "fast_mapping_log.txt").c_str(),ios::out); //open the log file for writing

	if(argc==2){
		/////////////////////////read in parameterse from PARAMTERS_FILE //////////////////////////////////
		fstream file_op ((directory + PARAMTERS_FILE).c_str(),ios::in);
		
		if(!file_op.is_open()) {
				fatal_error("bad parameters file!"+directory + PARAMTERS_FILE);
		}
		if(file_op.is_open()) {
			map_log<<"getting parameters from "+directory+PARAMTERS_FILE;
			string line;
			getline(file_op,line);
			//file_op.getline(str,1000);
			//line = string(str);
			line = line.substr(line.find_first_of('=')+1,line.size()-1);
			matrix_file = line;

			getline(file_op,line);
			line = line.substr(line.find_first_of('=')+1,line.size()-1);
			if(atoi(line.c_str()) > 0) chromosomes = atoi(line.c_str());

			getline(file_op,line);
			line = line.substr(line.find_first_of('=')+1,line.size()-1);
			if(atof(line.c_str()) > 0) core_LOD = atof(line.c_str());

			getline(file_op,line);
			line = line.substr(line.find_first_of('=')+1,line.size()-1);
			if(atof(line.c_str()) > 0) min_LOD = atof(line.c_str());

			getline(file_op,line);
			line = line.substr(line.find_first_of('=')+1,line.size()-1);
			if(atof(line.c_str()) > 0) quality_thresholds[MISSING_VALUE_IDX] = atof(line.c_str());

			getline(file_op,line);
			line = line.substr(line.find_first_of('=')+1,line.size()-1);
			if(atof(line.c_str()) > 0) quality_thresholds[CHISQ_11_IDX]=atof(line.c_str());

			getline(file_op,line);
			line = line.substr(line.find_first_of('=')+1,line.size()-1);
			if(atof(line.c_str()) > 0) quality_thresholds[CHISQ_121_IDX]=atof(line.c_str());

			getline(file_op,line);
			line = line.substr(line.find_first_of('=')+1,line.size()-1);
			if(atof(line.c_str()) > 0) quality_thresholds[CHISQ_13_IDX]=atof(line.c_str());

			getline(file_op,line);
			line = line.substr(line.find_first_of('=')+1,line.size()-1);
			if( atof(line.c_str()) == 1) order_plants = true;

			file_op.close();
		}
	}
	else{
		/////////////////////////read in parameters from stdin//////////////////////////////////
		int i=1;
		while(i<argc-1){
			string argType(argv[i]);
			if(argType.size()!=2 || argType[0]!='-') {
				fatal_error("bad input flags "+argType);
			}

			switch (argType[1]){
			case 'u':
				core_LOD = atof(argv[++i]);
				break;
			case 'l':
				min_LOD = atof(argv[++i]);
				break;
			case 'c':
				chromosomes = atoi(argv[++i]);
				cout<<"chromosomes="<<chromosomes;
				break;
			case 'v':
				quality_thresholds[MISSING_VALUE_IDX] = atof(argv[++i]);
				break;
			case 'g':
				quality_thresholds[CHISQ_11_IDX] = atof(argv[++i]);
				break;
			case 'h':
				quality_thresholds[CHISQ_121_IDX] = atof(argv[++i]);
				break;
			case 'd':
				quality_thresholds[CHISQ_13_IDX] = atof(argv[++i]);
				break;
			case 'o':
				order_plants=true;
				break;
			case 's':
				skip_grouping=true;
				break;
			case 'm':
				matrix_file=argv[++i];
				break;
			default:
				fatal_error("bad input paramaters!");
			}
			i++;
		}
	}

	map_log<<endl<<endl;
	map_log<<"chromosomes = "<<chromosomes<<endl;
	map_log<<"LOD for core grouping = "<<core_LOD<<endl;
	map_log<<"minimum LOD for grouping = "<<min_LOD<<endl;
	map_log<<"missing value screening ratio = "<<quality_thresholds[MISSING_VALUE_IDX]<<endl;
	map_log<<"1 : 1 segregation chi_square screening ratio = "<<quality_thresholds[CHISQ_11_IDX]<<endl;
	map_log<<"1 : 2 : 1 segregation chi_square screening ratio = "<<quality_thresholds[CHISQ_121_IDX]<<endl;
	map_log<<"1 : 3 segregation chi_square screening ratio = "<<quality_thresholds[CHISQ_13_IDX]<<endl;
	map_log<<"order plants = "<<order_plants<<endl;

	/////////read in matrix file ////////////////////////////////////////////////////
	while (matrix_file.at(0)==' '){
		matrix_file=matrix_file.substr(1,matrix_file.size()-1);
	}
	if(matrix_file.at(0)=='\"') matrix_file=matrix_file.substr(1,matrix_file.size()-2);

	// matrix_file=directory + matrix_file;
	fstream file_op(matrix_file.c_str(),ios::in);
	if(!(file_op.is_open())){
		fatal_error("bad matrix file "+matrix_file);
	}
	int row=0;
	while(!file_op.eof() && row < N_GENOTYPES ) 
	{		
		vector <int> matrow(N_GENOTYPES);
		string tmp;
		getline(file_op,tmp);
		if(read_mat(matrow,tmp)!=0) {
			for(unsigned int col=0;col<N_GENOTYPES;col++) {
				penalty_matrix[row][col]=matrow[col];
				map_log<<matrow[col];
			}
			row++;
			map_log<<endl;
		}
	}  
	file_op.close();
}

//============================================== read_loc_line ====================================================================
//reads in a line of a .loc file and fills in &locname and &markers
//returns: 0=acceptable, 1==bad segregation, 2==too many blanks, -1==error
int read_loc_line(string &locstr, string &locname, vector<int> &markers,  vector<float> &quality_thresholds) {
	if(VERBOSE_LOG>0) map_log<<locstr<<endl;
	float blanks=0;
	float As=0, Bs=0, Hs=0, Cs=0, Ds=0;
	unsigned int loc_name_end=locstr.find_first_of('\t'); //run past initial tabs to data
	if (loc_name_end==string::npos) return -1;
	while(loc_name_end+1<locstr.size() && locstr.at(loc_name_end+1)=='\t')
		loc_name_end++;
	if (loc_name_end>=locstr.size()) return -1;

	locname=locstr.substr(0,locstr.find_first_of('\t'));
	unsigned int i = loc_name_end+1;
	while(i < locstr.size() && locstr.at(i)!=';'){
		if(locstr.at(i)=='\t') return -1;
		markers.push_back(marker2int(locstr.at(i)));
		if(marker2int(locstr.at(i))==0) blanks++;
		if(marker2int(locstr.at(i))==1) As++;
		if(marker2int(locstr.at(i))==2) Bs++;
		if(marker2int(locstr.at(i))==3) Cs++;
		if(marker2int(locstr.at(i))==4) Ds++;
		if(marker2int(locstr.at(i))==5) Hs++;
		i+=2;
	}
	//reject if chi_square - 2 > chi^2*
	if(markers.size()==0) return -1;
	float N=float(markers.size());
	float chi_square;
	if(Cs==0 && Ds==0 && Hs==0) { //1:1 dominant recessive
		chi_square=(As-N*3.0/2.0)*(As-N/2.0)*2.0/N + (Bs-N/2.0)*(Bs-N/2.0)*2.0/N ;
		if(chi_square - 1 > quality_thresholds[CHISQ_11_IDX]) {
			map_log<<"rejecting loci "<<locname<<", bad AB  segregation, chi square="<<chi_square<<endl;
			return 1;
		}
	}
	else if(Cs<N/10.0 && Ds<N/10.0){ //1:2:1 dominant, codominant, recessive
		chi_square=(As-N/4.0)*(As-N/4.0)*4.0/N + (Bs-N/4.0)*(Bs-N/4.0)*4.0/N +(Hs-N/2.0)*(Hs-N/2.0)*2.0/N;
		if(chi_square-2.0 > quality_thresholds[CHISQ_121_IDX]) {
			map_log<<"rejecting loci "<<locname<<", bad 1:2:1  segregation, chi square="<<chi_square<<endl;
			return 1;
		}
	}
	else if(Cs>N*3.0/10.0){ //1:3 
		chi_square=(As-N/4.0)*(As-N/4.0)*4.0/N + (Cs-N*3.0/4.0)*(Cs-N*3.0/4.0)*4.0/(3.0*N);
		if(chi_square - 1 > quality_thresholds[CHISQ_13_IDX]) {
			map_log<<"rejecting loci "<<locname<<", bad AC  segregation, chi square="<<chi_square<<endl;
			return 1;
		}
	}
	else if(Ds>N/10.0){ //1:3
		chi_square=(Bs-N/4.0)*(Bs-N/4.0)*4.0/N + (Ds-N*3.0/4.0)*(Ds-N*3.0/4.0)*4.0/(3.0*N);
		if(chi_square - 1 > quality_thresholds[CHISQ_13_IDX]) {
			map_log<<"rejecting loci "<<locname<<", bad BD  segregation, chi square="<<chi_square<<endl;
			return 1;
		}
	}
	if( blanks/N > quality_thresholds[MISSING_VALUE_IDX]) {
		map_log<<"rejecting loci "<<locname<<", too many missing values, "<<blanks<<" missing values"<<endl;
		return 2; //reject if too many blanks
	}
	//map_log<<"loci "<<locname<<" okay"<<endl;
	return 0;
}

//============================================== read_mat ================================================================
//reads in a line of a matrix file and fills in matrow
//returns://0 skip line, 1 line is OK
int read_mat(vector <int> &matrow, string &line){
	if(line.at(0)==';') return 0;
	int col=0;
	unsigned strpos=0;
	string intstr;
	while((line.find_first_of('\t',strpos) != string::npos) && col < N_GENOTYPES) {
		intstr=line.substr(strpos,line.find_first_of('\t',strpos)-strpos);
		matrow[col]=atoi(intstr.c_str());
		if(matrow[col]==-1){
			fatal_error("matrix entries should be integers!");
		}
		col++;
		strpos=line.find_first_of('\t',strpos)+1;
	}
	if( (line.find_first_of('\t',strpos) == string::npos) && col==5 && (strpos < line.size()) ) {
		matrow[col]=atoi((line.substr(strpos, line.size()-strpos)).c_str());
		if(matrow[col]==-1){
			fatal_error("matrix entries should be integers!");
		}
	}
	return 1;
}


//============================================== marker2int ================================================================
int marker2int(char m){
	int r;
	switch (m){
	case 'A':
		r = A_;
		break;
	case 'a':
		r = A_;
		break;
	case 'B':
		r = B_;
		break;
	case 'b':
		r = B_;
		break;
	case 'C':
		r = C_;
		break;
	case 'c':
		r = C_;
		break;
	case 'D':
		r = D_;
		break;
	case 'd':
		r = D_;
		break;
	case 'H':
		r = H_;
		break;
	case 'h':
		r = H_;
		break;
	default:
		r = MV_;
	}
	return r;
}

//============================================== int2marker ================================================================
char int2marker(int a){
	char c;
	switch (a){
	case A_:
		c = 'A';
		break;
	case B_:
		c = 'B';
		break;
	case C_:
		c = 'C';
		break;
	case D_:
		c = 'D';
		break;
	case H_:
		c = 'H';
		break;
	case -1:
		c = '*';
		break;
	default:
		c = '-';
	}
	return c;
}

void fatal_error(string err_message){
	cout<<"Fatal error!: "<<err_message<<endl;
	map_log<<"Fatal error!: "<<err_message<<endl;
	exit(1);
}

