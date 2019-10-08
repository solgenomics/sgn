
export function init(main_div){
  if (!(main_div instanceof HTMLElement)){
    main_div = document.getElementById(main_div.startsWith("#") ? main_div.slice(1) : main_div);
  }  

    main_div.innerHTML = `

	<style>
	.factor {
	    z-index:4;
	    border-style:solid;
	    border-radius:8px;
	    width:200px;
	    height:100;
	    border-color:#337ab7;
	    background-color:#337ab7;
	    color:white;
	    margin:4px
	}
        .factor_panel {
	    min-height:100px;
	    height:auto;
	    margin-top:0px;
	    border-style:dotted;
	    border-width:5px;
	    color:grey;
	    background-color:lightyellow;
	}
        .factor_interaction_panel {
	    border-style:dotted;
	    border-width:0px;
	    margin-top:20px;
	    height:auto;
	    z-index:1;
	}
        .model_bg {
	    margin-left:30px;
	    margin-right:30px;
	    background-color:#DDEEEE;
	    min-height:80px;
	    padding-top:10px;
	    padding-left:10px;
	    padding-bottom:10px;
	    border-radius:8px;
	}
	</style>
    
	<div class="container">
	<div class="row">
	<div class="col-md-6">

        1. Choose a dataset

	<span style="width:240px" id="mixed_model_dataset_select">
	</span>
	<button class="btn btn-main" id="mixed_model_analysis_prepare_button">Go!</button>
	<br />
	<br />

    `;

}
