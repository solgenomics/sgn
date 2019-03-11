/** NOTICE ** This is a DEPRECATED module, hence the lower-case file-name.  I will eventually move everything here-in to separate modules.  This will allow for a graceful transition to well-factored code **/


/**
************** Misc Secretary Functions ***********************************HEADER************************
**/

function getSel() {
	var txt = '';
	var foundIn = '';
	document.getElementById('selectedblastp').innerHTML = "";
	document.getElementById('selectedblastnfull').innerHTML = "";
	document.getElementById('selectedblastncds').innerHTML = "";
	
	if (window.getSelection)
	{
		txt = window.getSelection();
		foundIn = 'window.getSelection()';
	}
	else if (document.getSelection)
	{
		txt = document.getSelection();
		foundIn = 'document.getSelection()';
	}
	else if (document.selection)
	{
		txt = document.selection.createRange().text;
		foundIn = 'document.selection.createRange()';
	}
	else return false;
	//fixtxt = txt.replace(/<br>/ig, "");
	var fixtxt = new String(txt);

	fixtxt = fixtxt.replace(/\W/ig, "");
	if (fixtxt.match(/^[A-Z]+$/)) {
		return fixtxt;
	}
	else return false;
}

function selectedblastp(selection){
      HTML = "<a class='external' href='http://www.ncbi.nlm.nih.gov/blast/Blast.cgi?CMD=Put&QUERY=" + selection + "&DATABASE=nr&PROGRAM=blastp&FILTER=L&HITLIST_SZE=500'>Perform BLASTP on Selection (" + selection.length + " aa)</a>";
      document.getElementById('selectedblastp').innerHTML = HTML;

}

function selectedblastnfull(selection){
      HTML = "<a class='external' href='http://www.ncbi.nlm.nih.gov/blast/Blast.cgi?CMD=Put&QUERY=" + selection + "&DATABASE=nr&PROGRAM=blastn&FILTER=L&HITLIST_SZE=500'>Perform BLASTN on Selection (" + selection.length + " bp)</a>";
      document.getElementById('selectedblastnfull').innerHTML = HTML;
}

function selectedblastncds(selection){
      HTML = "<a class='external' href='http://www.ncbi.nlm.nih.gov/blast/Blast.cgi?CMD=Put&QUERY=" + selection + "&DATABASE=nr&PROGRAM=blastn&FILTER=L&HITLIST_SZE=500'>Perform BLASTN on Selection (" + selection.length + " bp)</a>";
      document.getElementById('selectedblastncds').innerHTML = HTML;
}


function closebox(boxID) {
	document.getElementById(boxID).style.display="none";
	return false;
}

/** Only works on <span> tags for a given class name, currently alters the following properties:
***** color, backgroundColor, border, fontWeight  **/
function classAlter(className, styleProperty, styleValue) {
	for (i=0;i<document.getElementsByTagName("span").length; i++) {
		if (document.getElementsByTagName("span").item(i).className == className){
			document.getElementsByTagName("span").item(i).style[styleProperty] = styleValue;
		}
		if(1 == 0){  //change back if thing above doesn't work
			if(styleProperty == "color"){
				document.getElementsByTagName("span").item(i).style.color = styleValue;
			}
			else if(styleProperty == "backgroundColor"){
				document.getElementsByTagName("span").item(i).style.backgroundColor = styleValue;
			}
			else if(styleProperty == "border"){
				document.getElementsByTagName("span").item(i).style.border = styleValue;
			}
			else if(styleProperty == "fontWeight"){
				document.getElementsByTagName("span").item(i).style.fontWeight = styleValue;
			}
		}	
	}
}

/* Must match value in class highlightColor of the css file
*/
var searchHighlightColor = "#c9c9ff";
var searchHighlight = 0;

//Ensures that cookie object is instantiated, as well as Highlight Toggle-dependent functions
function prepareSearchHighlight(){
	if(Cookie){
		if(UserPrefs.get('searchHighlight')){
			searchHighlight = UserPrefs.get('searchHighlight');
		}
	}
	//Ok, this may look weird.  What we are doing is priming browser cache by calling the toggle function, which calls the classAlter function
	// and iterates through all of the <span> tags.  Therefore, the switches occur more quickly when the user first clicks the button.
	if (searchHighlight == 1){ 
		searchHighlight = 0; 
		toggleSearchHighlight();  //this will set searchHighlight back to 1, don't worry ;) 
	}
	else{
		searchHighlight = 1;
		toggleSearchHighlight();
	}
}

function toggleSearchHighlight(nocookieset){
	if(searchHighlight){
		classAlter("searchHighlight", "backgroundColor", "white");
		document.getElementById("highlightSelector").style.display = "inline";
		document.getElementById("unhighlightSelector").style.display = "none";
		searchHighlight = 0;
		UserPrefs.set('searchHighlight', 0);
		if(!nocookieset) UserPrefs.setCookie();
	}
	else {
		classAlter("searchHighlight", "backgroundColor", searchHighlightColor);
		document.getElementById("highlightSelector").style.display = "none";
		document.getElementById("unhighlightSelector").style.display = "inline";
		searchHighlight = 1;
		UserPrefs.set('searchHighlight', 1);
		if(!nocookieset) UserPrefs.setCookie();
	}
}

/**
************** Secretary Database Query Functions *********************HEADER*****************************
**/


var selectTextColorBg = "#771111"; //background color of active text
var selectTextColor = "#332277";  //color of unselected checkbox text

var joiners = new Array();

for(var i=0; i<10; i++) joiners.push("AND");

function selectModify(num, type){

	if(type=='rem'){
		document.getElementById("condcontainer" + num).style.display = "none";
		document.getElementById("selrem" + num).style.display = "none";
		if(num<10) document.getElementById("seladd" + num).style.display = "none";
		document.getElementById("seladd" + (num-1)).style.display = "inline";
		if (num > 1) document.getElementById("selrem" + (num-1)).style.display = "inline";
		document.getElementById("condvar"+num).value="";
		document.getElementById("condop"+num).value="=";
		document.getElementById("condoperand"+num).value="";
	}
	if(type=='add'){
		if(num<10) document.getElementById("condcontainer" + (num+1)).style.display="inline";
		if(num<10) document.getElementById("selrem" + (num+1)).style.display="inline";
		if(num<9) document.getElementById("seladd" + (num+1)).style.display="inline";
		document.getElementById("seladd" + num).style.display="none";
		if(num>0) document.getElementById("selrem" + num).style.display="none"
	}
}

function selectSwitch(value, item){
	box = document.getElementById("cb." + value);
	text = document.getElementById("text." + value);
	
	if(item){
		box = document.getElementById("cb." + value + "." + item);
		text = document.getElementById("text." + value + "." + item);
	}
	if(box.checked) {
		box.checked = false;
		text.style.backgroundColor = "white";
		text.style.color = selectTextColor;
		text.style.fontWeight = "normal";
	}
	else {
		box.checked = true;
		text.style.backgroundColor = selectTextColorBg; 
		text.style.color = "white";
		text.style.fontWeight = "bold";

		if(value != "COUNT"){
				document.getElementById("cb.COUNT").checked = false;
				text = document.getElementById("text.COUNT");
				text.style.color = "#332277"
				text.style.backgroundColor = "white";
				text.style.fontWeight = "normal";
		}
	}
}



function cbColorSwitch(value, item){
	
	box = document.getElementById("cb." + value);
	text = document.getElementById("text." + value);
	
	if(item){
		box = document.getElementById("cb." + value + "." + item);
		text = document.getElementById("text." + value + "." + item);
	}


	if(!box.checked) {
		text.style.backgroundColor = "white";
		text.style.color = selectTextColor;
		text.style.fontWeight = "normal";
	}
	else {
		text.style.backgroundColor = selectTextColorBg;
		text.style.color = "white";
		text.style.fontWeight = "bold";
	}
}


function switchJoin(id){
	joinercontent = document.getElementById("joinercontent"+id);
	formjoiner = document.getElementById("formjoiner" + id);
	if (joinercontent.innerHTML=="AND"){
		joinercontent.innerHTML="OR";
		joiners[id-1] = "OR";
		formjoiner.value = "OR";
	}
	else{
		joinercontent.innerHTML="AND";
		joiners[id-1] = "AND";
		formjoiner.value = "AND";
	}
}

function switchParen(id){
	formparen = document.getElementById("formparen"+id);
	parencontent = document.getElementById("parencontent"+id);
	jointop = document.getElementById("jointop"+id);
	joinbottom = document.getElementById("joinbottom"+id);

	if(formparen.value=='0'){
		formparen.value=1;
		parencontent.innerHTML = "<span style='color:#442277'>(Unjoin)</span>";
		jointop.innerHTML="";
		joinbottom.innerHTML="";
	}
	else{
		formparen.value=0;
		parencontent.innerHTML = "(Join)";
		jointop.innerHTML="<br>";
		joinbottom.innerHTML="<br>";
	}

}

function variableChange(id){
	variable = document.getElementById("condvar" + id);
	operator = document.getElementById("condop" + id);
	type = variable.value.charAt(0);
	if(type=="f" || type=="i") operator.value = ">";
	else if(type=="r") operator.value = "REGEXP";
	else if(type=="t") operator.value = "FULLTEXT";
}

function chartTypeChange(){
	ctype = document.getElementById("charttype");
	pie_opt = document.getElementById("pie_options");
	bar_opt = document.getElementById("bar_options");
	if(ctype.value==''){
		pie_opt.style.display = "none";
		bar_opt.style.display = "none";
	}
	else if(ctype.value=="pie"){
		pie_opt.style.display = "block";
		bar_opt.style.display = "none";
	}
	else{
		pie_opt.style.display = "none";
		bar_opt.style.display = "block";
	}
}

var num=0;
var live=1;
var last=3;

function killAnimateDots(){
	live = 0;
}

function animateDots(){
	num = num+1;
	if(num>3) num = 0;
	last = num - 1;
	if(last<0) last = 3;
	
	document.getElementById("dots"+last).style.display="none";
	document.getElementById("dots"+num).style.display="inline";
	
	if(live) setTimeout("animateDots()", 500); 
}


function closeBox(name){
	document.getElementById(name+"_hide").style.display="none";	
	document.getElementById(name+"_show").style.display="inline";
	document.getElementById(name+"_table").style.display="none";
	document.getElementById(name+"_box").style.borderColor="#555555";
	document.getElementById(name+"_header").style.backgroundColor="#555555";
}

function openBox(name){
	document.getElementById(name+"_hide").style.display="inline";	
	document.getElementById(name+"_show").style.display="none";
	document.getElementById(name+"_table").style.display="inline";

	var activeColor = "";
	if(name=="chart") activeColor = "#444499";
	else if(name=="select") activeColor = "#770000";
	else if(name=="cond") activeColor = "#551155";

	document.getElementById(name+"_box").style.borderColor = activeColor;
	document.getElementById(name+"_header").style.backgroundColor = activeColor;
}


/**
*************** Hotlist Functions ***************************HEADER****************************************
**/

function RequestWaitIndicator(waitElementId) {
		
	RequestWaitIndicator.numWaits += 1;
	this.id = "RWI:" + RequestWaitIndicator.numWaits;
	RequestWaitIndicator.waitHash[this.id] = 1;	
	this.waitElementId = waitElementId;	
	setTimeout("RequestWaitIndicator.displayElement('" + this.id + "', '" + this.waitElementId + "')", 1000);
	
	this.stopWait = function () {
		RequestWaitIndicator.waitHash[this.id] = 0;
		Effects.hideElement(waitElementId);
	}
}
RequestWaitIndicator.numWaits = 0;
RequestWaitIndicator.waitHash = {};
RequestWaitIndicator.displayElement = function (waitId, elementId) {
	if (RequestWaitIndicator.waitHash[waitId]){
		Effects.showElement(elementId);
	}
}


/**
********* User account related functions ****************HEADER************************************************
**/



var http_request = false;

function makeRequest(url, parameters, type) {

      http_request = false;

      if (window.XMLHttpRequest) { // Mozilla, Safari,...
         http_request = new XMLHttpRequest();
         if (http_request.overrideMimeType) {
            http_request.overrideMimeType('text/xml');
         }
      } else if (window.ActiveXObject) { // IE
         try {
            http_request = new ActiveXObject("Msxml2.XMLHTTP");
         } catch (e) {
            try {
               http_request = new ActiveXObject("Microsoft.XMLHTTP");
            } catch (e) {}
         }
      }
	if (!http_request) {
	     //print("<!--Async XML Request Failed-->");
         return false;
      }
      if (type=='username') http_request.onreadystatechange = alertContentsName;
      http_request.open('GET', url + parameters, true);
      http_request.send(null);
	  return true;
 }

function alertContentsName() {
      if (http_request.readyState == 4) {
         if (http_request.status == 200) {
            check_name_response(http_request.responseText);
	    	return true;
         }
	  else return true;
      }
      else return false;
   }


function check_password(password){
	if(password==""){
		document.getElementById('quickwarning').innerHTML = "&nbsp;";
		document.getElementById('choosepw').style.color= "black"; 
    }
	else if(password.length < 7){
		document.getElementById('quickwarning').innerHTML = "Password must be at least 7 characters long";
		document.getElementById('choosepw').style.color= "#dd4444"; 
	}
	else {
		document.getElementById('quickwarning').innerHTML = "&nbsp;";
		document.getElementById('choosepw').style.color = "black";
	}
}

function check_password_match(passwordrep){
	password = document.cf.password.value;
	if(passwordrep=="" || password.length==0){
		document.getElementById('quickwarning').innerHTML = "&nbsp;"
		document.getElementById('confirmpw').style.color = "black";
	}
	else if(passwordrep != password){
		document.getElementById('quickwarning').innerHTML = "Repeated password doesn't match";
		document.getElementById('confirmpw').style.color = "#dd4444";
	}
	else{
		document.getElementById('quickwarning').innerHTML = "&nbsp;";
		document.getElementById('confirmpw').style.color = "black";
	}
}



function check_name(username){
  if(username==""){
	document.getElementById('quickwarning').innerHTML = "&nbsp;";	      
	document.getElementById('chooseuname').style.color = "black";
	document.getElementById('uname_available').style.display = "none";
	document.getElementById('uname_taken').style.display = "none";
  }
  else if(username.length < 7){
  	document.getElementById('quickwarning').firstChild.nodeValue = "Username must be at least 7 characters long";
	document.getElementById('chooseuname').style.color = "#dd4444";
	document.getElementById('uname_available').style.display = "none";
	document.getElementById('uname_taken').style.display = "none";
  }
  else  {
	document.getElementById('quickwarning').innerHTML = "&nbsp;";
	document.getElementById('chooseuname').style.color = "black";
	makeRequest('scraps/check_name_avail.pl', '?username=' + username, 'username');
  }
}

function check_email(email){

  var ereg = /^[^@]+@[^@]+$/; 
  if(email==""){
	document.getElementById('quickwarning').innerHTML = "&nbsp;";	      
	document.getElementById('chooseemail').style.color = "black";
  }
  else if(!email.match(ereg)){
  	document.getElementById('quickwarning').innerHTML = "E-mail not of the form: name@address";
	document.getElementById('chooseemail').style.color = "#dd4444";
  
  }
  else  {
	document.getElementById('quickwarning').innerHTML = "&nbsp;";
	document.getElementById('chooseemail').style.color = "black";
  }
}

function check_name_response(response){
	if (response=='1') {
  		document.getElementById('uname_available').style.display = "inline";
		document.getElementById('uname_taken').style.display = "none";
	}
	else if(response=='0') {
		document.getElementById('uname_available').style.display = "none";
		document.getElementById('uname_taken').style.display = "inline";
	}
  	else {
		document.getElementById('uname_available').style.display = "none";
		document.getElementById('uname_taken').style.display = "none";
	}
}


function hide_warning(){
	document.getElementById('login_warning').style.display="none";
}

function new_user(){
	document.getElementById('login_box').style.display="none";
	document.getElementById('createaccount_box').style.display="block";
	document.getElementById('newuname').focus();
	return false;
}

function hide_create(){
	document.getElementById("createaccount_box").style.display="none";
	document.getElementById("userbar_container").style.display="block"; 
	document.getElementById("login_warning").style.display="none";
	return false;
}

function hide_login(){
	document.getElementById("login_box").style.display="none"; 
	document.getElementById("userbar_container").style.display="block"; 
	document.getElementById("login_warning").style.display="none";
	return false;
}

function show_login(){
	document.getElementById("login_box").style.display="block"; 
	document.getElementById("userbar_container").style.display="none"; 
	document.getElementById("uname").focus(); 
	document.getElementById("login_warning").style.display="none";
	return false;
}



/** 
**** List Functions ****************************HEADER**********************************************************
**/
var http_request_mylistpage = false;
var workinglist = "";

var lastAction = "";
var lastList = "";
var lastNewList = "";


function makeRequestMylist(url, parameters, type, list) {

	  workinglist = list;
      http_request_mylistpage = false;

      if (window.XMLHttpRequest) { // Mozilla, Safari,...
         http_request_mylistpage = new XMLHttpRequest();
         if (http_request_mylistpage.overrideMimeType) {
            http_request_mylistpage.overrideMimeType('text/xml');
         }
      } else if (window.ActiveXObject) { // IE
         try {
            http_request_mylistpage = new ActiveXObject("Msxml2.XMLHTTP");
         } catch (e) {
            try {
               http_request_mylistpage = new ActiveXObject("Microsoft.XMLHTTP");
            } catch (e) {}
         }
      }
      if (!http_request_mylistpage) {
		 return false;
      }
      if (type=='alterlist') http_request_mylistpage.onreadystatechange = alertContentsList;
      if (type=='FASTA') http_request_mylistpage.onreadystatechange = alertContentsFASTA;
      http_request_mylistpage.open('GET', url + parameters, true);
      http_request_mylistpage.send(null);
	  return true;
 }


function alertContentsList() {
      if (http_request_mylistpage.readyState == 4) {
         if (http_request_mylistpage.status == 200) {
            mylist_response(http_request_mylistpage.responseText);
	    return true;
         }
	 else return true;
      }
      else return false;
   }

function alertContentsFASTA(list){
      if (http_request_mylistpage.readyState == 4) {
         if (http_request_mylistpage.status == 200) {
            fasta_response(http_request_mylistpage.responseText);
	    return true;
         }
	 else return true;
      }
      else return false;
   }


function createFASTA(type, list) {
	document.getElementById(list+'_fetch').style.display='inline';
	document.getElementById(list+'_cleartool').style.display="none";
	document.getElementById(list+'_createfastalinks').style.display="none";
	if(type!="full" && type!="cds" && type!="prot" && type!="cdna") type="full";

	var RequestURL = "fastacreate.php?user=<?php echo $username?>&type=" + type + "&list="+list; 
	makeRequestMylist(RequestURL, "", "FASTA", list);		

}

function fasta_response(output) {
	var list = workinglist;
	document.getElementById(list+"_FASTAbox").value = output;		
	document.getElementById(list+"_FASTAholder").style.display="block";
	document.getElementById(list+"_fetch").style.display='none';
	document.getElementById(list+"_cleartool").style.display="inline";
	document.getElementById(list+"_createfastalinks").style.display = "inline";
}

function undoLast(){
	var action;
	if(lastAction=="add") action = "remove";
	else if(lastAction=="remove") action = "add";

	alterList()

}


function alterList(newlist, action, list){	
	
	lastAction = action;
	lastList = list;
	lastNewList = newlist;

	var RequestURL = "alterlist.php?user=<?php echo $username?>&md5pass=<?php echo $password?>";
	RequestURL += "&list="+list+"&newlist=" + newlist + "&action=" + action;
	makeRequestMylist(RequestURL, "", "alterlist", list);	
}

var clear_reload = 0;
function clearList(list){
	
	RequestURL = "alterlist.php?user=<?php echo $username?>&md5pass=<?php echo $password?>";
	RequestURL += "&list="+list+"&clear=1";
	makeRequestMylist(RequestURL, "", "alterlist", list);
	clear_reload = 1;
}

function alterLink(id, action, list){
	
	if(action=="add") HTML = "<a href='#' onclick='alterList(\"" + id + "\", \"add\", \""+list+"\"); alterLink(\"" + id + "\", \"remove\", \""+list+"\"); return false;' style='text-decoration:none'>[ <img src='/img/hotlist_add.png' border=0 align='absmiddle'> Re-Add ]</a>";
	else if (action=="remove") HTML = "<a href='#' onclick='alterList(\"" + id + "\", \"remove\", \""+list+"\"); alterLink(\"" + id + "\", \"add\", \""+list+"\"); return false;' style='text-decoration:none'>[ <img src='/img/hotlist_remove.png' border=0 align='absmiddle'> Remove ]</a>";
	document.getElementById(list + "_" + id).innerHTML = HTML;
}


function mylist_response(output){

	var list = workinglist;
	output = output.toString();
	
	if (output.charAt(0) == 'q'){

	output = output.substring(1);
	listsize = output * 1;
	if(list=="hotlist") document.getElementById('hlsize').firstChild.nodeValue = listsize;
    document.getElementById(list+"_headercount").innerHTML = listsize + " Genes";	
	if(listsize==0 && clear_reload==1) window.location.reload();
	clear_reload = 0;
	}
	
	
}


