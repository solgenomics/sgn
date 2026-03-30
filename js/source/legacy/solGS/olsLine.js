/**
 * Ordinary least squares line helpers
 * Shared between plots that need regression line + stats.
 */

var solGS = solGS || function solGS(){};

solGS.olsLine = {

    compute: function (args) {
        var xyValues = args.xy_values || [];
        var r2Label = args.r2_label || "R\u00B2";
        var xDataType = args.x_data_type || "numeric";

        var allDates = [];
        var uniqueDates = [];
        var xyDateValues = [];

        if (xDataType.match(/date/i)) {
            xyDateValues = xyValues;
            console.log("Processing date data for OLS regression...");
            allDates = xyValues.map(d => d.date);
            console.log("All dates:", allDates);
            uniqueDates = [...new Map(allDates.map(d => [d.toDateString(), d])).values()];
            console.log("Unique dates:", uniqueDates);

            xyValues = xyValues.map(function(d, i) {
                const idx = uniqueDates.findIndex(ud =>
                ud.getFullYear() === d.date.getFullYear() &&
                ud.getMonth() === d.date.getMonth() &&
                ud.getDate() === d.date.getDate()
                );
                return [idx, d.value];
            });
        }

        var regEquation = ss.linear_regression()
            .data(xyValues)
            .line(); 
   
        var regParams = ss.linear_regression()
            .data(xyValues);
     
        var intercept = regParams.b();
        intercept     =  Math.round(intercept*100) / 100;
    
        var slope = regParams.m();
        slope     = Math.round(slope*100) / 100;
    
        var sign; 
        if (slope > 0) {
            sign = ' + ';
        } else {
            sign = ' - ';
        }

        var equationLabel = `y = ${intercept} ${sign} ${slope}x`;
        var rSquared = ss.r_squared(xyValues, regEquation);
        rSquared     = Math.round(rSquared*100) / 100;
        rSquared     = r2Label + " = " + rSquared;

        var fittedData = [];
        xValues = xyValues.map(d => d[0]);   
        if (xDataType.match(/date/i)) {
            fittedData= xyDateValues.map(d => {
                const idx = uniqueDates.findIndex(ud => ud.toDateString() === d.date.toDateString());
                const predictedValue = regEquation(Number(idx));
                return [d.date, predictedValue];
            });
        } else {
            xValues.forEach(function (xVal) {
                var predictedValue = regEquation(parseFloat(xVal));
                fittedData.push([parseFloat(xVal), predictedValue]);
            });
        }
        
        return {
            equation_label: equationLabel,
            r_squared: rSquared,
            reg_equation: regEquation,
            fitted_data: fittedData
        };
    }

};
