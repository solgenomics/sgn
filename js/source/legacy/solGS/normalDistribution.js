/** 

* given an array of arrays dataset ([[A, 1], [B, 2], [C, 4], [D, 1]]), 
it standardizes dependent variable values (calculates z-scores), calculates probabilties 
and returns an array of js objects of the form 
[{x: xvalue, y: yvalue, z: z-score , p: probability}, ....]

* uses methods from statistics/simple_statistics js library

* Isaak Y Tecle <iyt2@cornell.edu>

**/

var solGS = solGS || function solGS () {};

solGS.normalDistribution =  function () {};


solGS.normalDistribution.prototype.getNormalDistData = function (xy) {
	
	var yValues = this.getYValues(xy);
	
	var mean = ss.mean(yValues);
	var std  = ss.standard_deviation(yValues);
	
	var normalDistData = [];
	
	for (var i=0; i < xy.length; i++) {
	    
	    var x = xy[i][0];	    
	    var y = xy[i][1];
	    y     = d3.format('.2f')(y);	    
	    var z = ss.z_score(y, mean, std);
	    z     = d3.format('.2f')(z);	  
	    var p = ss.cumulative_std_normal_probability(z);

	    if (y > mean) {
		p = 1 - p;
	    }

	    normalDistData.push({'x': x, 'y': y, 'z': z, 'p': p});
	}
	
    return normalDistData;
}


solGS.normalDistribution.prototype.getPValues = function (normalData) {

	var p = [];
	
	for (var i=0; i < normalData.length; i++) {
            var pV  = normalData[i].p;
	    p.push(pV);
	}
	
	return p;

}


solGS.normalDistribution.prototype.getXValues = function (xy) {
	
	var xv = [];
	
	for (var i=0; i < xy.length; i++) {      
            var x = xy[i][0];
            x     = x.replace(/^\s+|\s+$/g, '');
	    x     = Number(x);
	    xv.push(x);
	}
	
	return xv;
	
}

solGS.normalDistribution.prototype.getYValues = function (xy) {
	
	var yv = [];
	
	for (var i=0; i < xy.length; i++) {      
            var y = xy[i][1];	 
            y     = Number(y);
	    
	    yv.push(y);
	}
	
	return yv;
	
}


solGS.normalDistribution.prototype.getYValuesZScores = function (normalData) {

	var yz = [];
	
	for (var i=0; i < normalData.length; i++) {
            var y = normalData[i].y;
	    var z  = normalData[i].z;
	    yz.push([y, z]);

	}
	
	return yz;
}


solGS.normalDistribution.prototype.getZScoresP = function (normalData) {

	var zp = [];

	for (var i=0; i < normalData.length; i++) {
            var zV  = normalData[i].z;
	    var pV  = normalData[i].p;
	    zp.push([zV, pV]);

	}
	
	return zp;
} 


solGS.normalDistribution.prototype.getYValuesP = function (normalData) {

	var yp = [];

	for (var i=0; i < normalData.length; i++) {
            var x  = normalData[i].y;
	    var y  = normalData[i].p;
	    yp.push([x, y]);

	}
	
	return yp;
}


solGS.normalDistribution.prototype.getObsValueZScore = function (obsValuesZScores, zScore) {

	var obsValue;
	for (var i=0; i < obsValuesZScores.length; i++) {
	 
	    var j =  obsValuesZScores[i];

	    if (obsValuesZScores[i][1] == zScore) {
		obsValue = obsValuesZScores[i][0];
	    }
	}
  
    return [obsValue, zScore];
}


     

 
