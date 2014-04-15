/* source: http://www.javascriptstats.com/
*  author : Dave Romero
*  accessed: 01 April 2014
*/

var jsStats={mean:function(arr){if(!jsStatsHelpers.isArray(arr)){return false;}
var i=arr.length;var sum=0;while(i--){sum+=arr[i];}
var mean=sum/arr.length;return mean;},median:function(arr){if(!jsStatsHelpers.isArray(arr)){return false;}
arr.sort(function(a,b){return a- b;});var half=Math.floor(arr.length/2);if(arr.length%2)
return arr[half];else
return(arr[half-1]+ arr[half])/2},mode:function(arr){if(!jsStatsHelpers.isArray(arr)){return false;}
var modes=[];var count=[];var i;var number;var maxIndex=0;for(i=0;i<arr.length;i+=1){number=arr[i];count[number]=(count[number]||0)+ 1;if(count[number]>maxIndex){maxIndex=count[number];}}
for(i in count)if(count.hasOwnProperty(i)){if(count[i]===maxIndex){modes.push(Number(i));}}
return modes;},min:function(arr){if(!jsStatsHelpers.isArray(arr)){return false;}
arr.sort(function(a,b){return a- b;});return arr[0];},max:function(arr){if(!jsStatsHelpers.isArray(arr)){return false;}
arr.sort(function(a,b){return a- b;});return arr[arr.length- 1];},range:function(arr){if(!jsStatsHelpers.isArray(arr)){return false;}
arr.sort(function(a,b){return a- b;});return[arr[0],arr[arr.length- 1]];},sum:function(arr){for(var i=0,length=arr.length,sum=0;i<length;sum+=arr[i++]);return sum;},sort:function(arr){return arr.sort(function(a,b){return a- b});},sortReverse:function(arr){return arr.sort(function(a,b){return a- b}).reverse();},sumOfSquares:function(arr){var mean=jsStats.mean(arr);for(var i=0,sumOfSquares=0;i<arr.length;i++){sumOfSquares+=Math.pow(arr[i]- mean,2);}
return sumOfSquares;},variance:function(arr){if(!jsStatsHelpers.isArray(arr)){return false;}
var sumOfSquares=jsStats.sumOfSquares(arr);return sumOfSquares/arr.length;},standardDeviation:function(arr){if(!jsStatsHelpers.isArray(arr)){return false;}
return Math.sqrt(jsStats.variance(arr));},equalIntervalBreaks:function(arr,numBreaks){var min=jsStats.min(arr);var max=jsStats.max(arr);var median=jsStats.median(arr);var span=max- min;var interval=span/numBreaks;var breaks=new Array();for(var i=0;i<numBreaks;i++){breaks[i]=new Array();breaks[i].lower=min+(i*interval);if(i+ 1!=numBreaks){breaks[i].upper=min+((i+ 1)*interval)-.00000000000001;}else{breaks[i].upper=min+((i+ 1)*interval);}
breaks[i].numbers=new Array();}
for(n in arr){for(i in breaks){if(arr[n]>=breaks[i].lower&&arr[n]<=breaks[i].upper){breaks[i].numbers.push(arr[n]);}}}
for(i in breaks){breaks[i].numbers=jsStats.sort(breaks[i].numbers);}
return breaks;},goodnessOfFit:function(arrPopulation,arrSample){if(!jsStatsHelpers.isArray(arr)){return false;}
var ssp=jsStats.sumOfSquares(arrPopulation);var sss=jsStats.sumOfSquares(arrSample);return(ssp- sss)/ssp;},};jsStatsHelpers={isArray:function(arr){return Object.prototype.toString.call(arr)==="[object Array]";}};
