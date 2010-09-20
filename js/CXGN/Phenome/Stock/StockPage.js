
/** 
* @class StockPage
* Functions used by the stock page
* @author Naama Menda <nm249@cornell.edu>
*
*This javascript object deals with dynamic printing and updating 
*of sections in the stock page /phenome/stock/view
*/



JSAN.use('CXGN.Phenome.Tools');
JSAN.use('jquery');
JSAN.use('Prototype');

if (!CXGN) CXGN = function() {};
if (!CXGN.Phenome) CXGN.Phenome = function() {};
if (!CXGN.Phenome.Stock) CXGN.Phenome.Stock = function() {};

CXGN.Phenome.Stock.StockPage = function() { 
    ///alert('In constructor');
   
};


CXGN.Phenome.Stock.StockPage.prototype = { 

   
    render: function() { 
	//this.printLocusNetwork(this.getLocusId());
    },


    //////////////////////////////////////////////
    /////////////////////////////////////////////////
    /////////////////////////////////////////////////////
    
    
    
    
    setStockId: function(stock_id) { 
	this.stock_id = stock_id;
    },
    
    getStockId: function() { 
	return this.stock_id;
    },
    
};


