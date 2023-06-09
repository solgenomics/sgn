/**

A list object template with methods for getting details about the list.
Isaak Y Tecle 
iyt2@cornell.edu
*/

class solGSList {
  constructor(listId) {
    this.listId = listId;
    this.listObj = new CXGN.List();
  }

  getListDetail() {
    return {
      name: this.listObj.listNameById(this.listId),
      type: this.listObj.getListType(this.listId),
      list_id: this.listId,
    };
  }

  getListElementsIds() {
    var listData = this.listObj.getListData(this.listId);
    var listElems = listData.elements;
    var ids = [];
    for (var i = 0; i < listElems.length; i++) {
      ids.push(listElems[i][0]);
    }

    return ids;
  }

  getListElementsNames() {
    var listData = this.listObj.getListData(this.listId);
    var listElems = listData.elements;
    var names = [];
    for (var i = 0; i < listElems.length; i++) {
      names.push(listElems[i][1]);
    }

    return names;
  }
}
